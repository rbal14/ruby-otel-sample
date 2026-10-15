#!/bin/bash
# Runs once, on first boot of an empty MySQL data directory.
#
# The official image's MYSQL_DATABASE/MYSQL_USER variables only ever grant the
# app user access to a single schema. This POC runs two Rails apps against two
# schemas on one server, so the second schema, the extra grants, and the
# read-only monitoring user are created here. Everything is driven by
# environment variables that come from the phr-mysql-secrets Secret -- no
# passwords are baked into this file.
set -euo pipefail

WEB_DB="${WEB_DB_NAME:-phr_web}"
API_DB="${API_DB_NAME:-phr_api}"
APP_USER="${MYSQL_USER:-phr_app}"
MONITOR_USER="${DT_MONITOR_USER:-dtmonitor}"

# The entrypoint runs init scripts against a temporary server started with
# --skip-networking, so TCP to 127.0.0.1 is not an option -- it has to be the
# unix socket. The path differs between the Debian- and Oracle Linux-based
# builds of this image, so find it rather than assume it.
SOCKET=""
for candidate in \
  /var/lib/mysql/mysql.sock \
  /var/run/mysqld/mysqld.sock \
  /tmp/mysql.sock
do
  if [ -S "$candidate" ]; then
    SOCKET="$candidate"
    break
  fi
done

if [ -z "$SOCKET" ]; then
  echo "[init] no mysql socket found; falling back to client defaults" >&2
  set -- --protocol=socket
else
  echo "[init] using socket ${SOCKET}"
  set -- --protocol=socket --socket="$SOCKET"
fi

echo "[init] creating schemas ${WEB_DB} and ${API_DB}"

mysql "$@" -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${WEB_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`${API_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Rails owns DDL in both schemas, because migrations create and alter tables.
GRANT ALL PRIVILEGES ON \`${WEB_DB}\`.* TO '${APP_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${API_DB}\`.* TO '${APP_USER}'@'%';

-- Rails' schema tooling and connection-pool introspection want these.
GRANT PROCESS, REFERENCES ON *.* TO '${APP_USER}'@'%';

-- Read-only user for database monitoring. These are the grants a monitoring
-- extension typically needs: metrics out of performance_schema/sys, the
-- process list, and replication status.
CREATE USER IF NOT EXISTS '${MONITOR_USER}'@'%' IDENTIFIED BY '${DT_MONITOR_PASSWORD}';
ALTER USER '${MONITOR_USER}'@'%' WITH MAX_USER_CONNECTIONS 10;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MONITOR_USER}'@'%';

FLUSH PRIVILEGES;
SQL

echo "[init] schemas and users ready"
