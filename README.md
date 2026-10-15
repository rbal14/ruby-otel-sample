# Power Home Remodeling POC Sandbox

A deliberately ordinary Ruby on Rails estate — two Rails apps, MySQL, Redis, and
a Sidekiq worker — packaged to run in a vanilla Kubernetes cluster. It mirrors
the shape of Power Home Remodeling's environment so that database monitoring,
OpenTelemetry instrumentation, and Dynatrace Operator deployment can each be
exercised against something realistic.

**This sandbox is not instrumented.** There is no OpenTelemetry SDK, no
exporter, no OneAgent, and no Dynatrace configuration anywhere in this repo.
That is deliberate: it is the "before" state. See
[Where this goes next](#where-this-goes-next).

---

## Architecture

```
                    ┌──────────────────────── Kubernetes namespace: power-poc ────────────────────────┐
                    │                                                                                │
  Internet ────────►│  Service phr-web (LoadBalancer :80)                                            │
                    │        │                                                                       │
                    │        ▼                                                                       │
                    │  ┌───────────────────┐   HTTP (Net::HTTP)   ┌───────────────────┐              │
                    │  │ phr-web           │─────────────────────►│ phr-api           │              │
                    │  │ Rails 7.1 + Puma  │                      │ Rails 7.1 API-only│              │
                    │  │ ERB front end     │                      │ + Puma            │              │
                    │  │ 2 replicas        │◄─────────────────────│ 2 replicas        │              │
                    │  └─────────┬─────────┘      JSON            └─────────┬─────────┘              │
                    │            │                                          │                        │
                    │       ActiveRecord                                ActiveRecord                 │
                    │            │            ┌───────────────┐             │                        │
                    │            └───────────►│ MySQL 8.0     │◄────────────┘                        │
                    │                         │ StatefulSet   │                                      │
                    │            ┌───────────►│ 20Gi Azure    │                                      │
                    │            │            │ Disk (PVC)    │                                      │
                    │            │            │               │                                      │
                    │            │            │ schema        │                                      │
                    │            │            │  phr_web ◄────┼── phr-web, phr-worker                │
                    │            │            │  phr_api ◄────┼── phr-api                            │
                    │            │            └───────────────┘                                      │
                    │            │                                                                   │
                    │  ┌─────────┴─────────┐   enqueue/dequeue  ┌───────────────┐                    │
                    │  │ phr-worker        │◄──────────────────►│ Redis 7       │                    │
                    │  │ Sidekiq 7         │                    │ (ephemeral)   │                    │
                    │  │ 1 replica         │                    └───────────────┘                    │
                    │  └─────────┬─────────┘                                                         │
                    │            │ HTTP back to phr-api                                              │
                    │            └──────────────────────────────────────────────►                    │
                    │                                                                                │
                    │  ┌───────────────────┐                                                         │
                    │  │ phr-loadgen       │ continuous shaped traffic against phr-web and phr-api   │
                    │  └───────────────────┘                                                         │
                    └────────────────────────────────────────────────────────────────────────────────┘
```

### Components

| Workload | Kind | Image | What it is |
|---|---|---|---|
| `phr-web` | Deployment (2) | built here | Rails 7.1 full-stack app. Internal ops portal — customers, projects, dashboards. Owns the `phr_web` schema. Renders leads/appointments by calling `phr-api` over HTTP. |
| `phr-api` | Deployment (2) | built here | Rails 7.1 API-only service. Owns the `phr_api` schema — leads and appointments. No views, no sessions. |
| `phr-worker` | Deployment (1) | same image as `phr-web` | Sidekiq 7. Scores new leads, then provisions customers and projects. Talks to Redis, MySQL, and `phr-api`. |
| `mysql` | StatefulSet (1) | `mysql:8.0` | Both schemas on one server, on a 20Gi Azure Disk. Includes a read-only monitoring user. |
| `redis` | Deployment (1) | `redis:7-alpine` | Sidekiq queue. Ephemeral by design. |
| `phr-loadgen` | Deployment (1) | `curlimages/curl` | Continuous traffic, including a steady trickle of slow requests, N+1 patterns, table scans, and 5xx. |

### Why it is shaped this way

Each piece exists to give the POC something specific to look at:

- **Two Rails services, not one.** A request that crosses `phr-web → phr-api`
  is the only way to tell whether distributed context actually propagates
  between Ruby processes.
- **`Net::HTTP` from stdlib**, not a gem wrapper — it is what a lot of
  long-lived Rails code actually uses, and it is what auto-instrumentation has
  to hook.
- **Two schemas on one MySQL server.** Database monitoring should attribute
  load to the right schema and the right service.
- **Sidekiq via Redis.** Background jobs break the request/response model, which
  is where trace context most often gets dropped.
- **Deliberate misbehaviour endpoints.** Slow queries, N+1 patterns, full table
  scans, CPU burn, and unhandled exceptions, all reproducible on demand rather
  than waited for.

---

## Prerequisites

On this machine, `az`, `kubectl`, and `docker` are all currently missing.
Docker is **optional** — the default build path builds inside ACR.

```bash
brew install azure-cli kubernetes-cli

# Optional: only needed for `./scripts/build-and-push.sh local`
brew install --cask docker
```

You also need:

- An AKS cluster you can reach, with at least ~2 vCPU / 3Gi of schedulable
  capacity free (total requests are roughly 1.4 vCPU and 2.6Gi).
- An Azure Container Registry, or permission to create one.
- A default storage class that can provision `ReadWriteOnce` volumes. The
  manifests ask for `managed-csi`; check with `kubectl get storageclass`.

---

## Repo layout

```
power-poc/
├── apps/
│   ├── phr-api/              Rails API-only service (leads, appointments)
│   │   ├── Dockerfile        multi-stage, ruby:3.3-slim, non-root
│   │   ├── app/              models, controllers (incl. simulations_controller)
│   │   ├── config/           all configuration via ENV
│   │   └── db/               migrations + idempotent seeds
│   └── phr-web/              Rails front end + Sidekiq worker
│       ├── app/services/     phr_api_client.rb  (Net::HTTP client)
│       ├── app/jobs/         lead_scoring_job.rb, project_provision_job.rb
│       └── app/views/        ERB, styles inlined (no asset pipeline / Node)
├── k8s/
│   ├── 00..60-*.yaml         manifests, applied in name order
│   ├── kustomization.yaml    registry + tag substitution lives here
│   ├── mysql-init/           schema/user bootstrap → ConfigMap
│   └── loadgen/traffic.sh    traffic script → ConfigMap
├── scripts/
│   ├── build-and-push.sh     az acr build (default) or local docker
│   ├── deploy.sh             apply, migrate, seed, wait, print the URL
│   └── teardown.sh           delete the namespace (and the MySQL disk)
├── docker-compose.yml        same stack, locally
└── .env.example              optional compose overrides
```

---

## Deploy to AKS

### 1. Target the cluster

```bash
az login
az account set --subscription "<SUBSCRIPTION>"

az aks get-credentials \
  --resource-group "<RESOURCE_GROUP>" \
  --name "<CLUSTER_NAME>" \
  --overwrite-existing

kubectl config current-context
kubectl get nodes
kubectl get storageclass          # confirm managed-csi exists
```

If your cluster's default storage class is not `managed-csi`, change
`storageClassName` in `k8s/20-mysql.yaml` before deploying.

### 2. Set up the registry

Create one if you need it, then attach it to the cluster so nodes can pull
without an image pull secret:

```bash
export RG="<RESOURCE_GROUP>"
export CLUSTER="<CLUSTER_NAME>"
export ACR_NAME="<globally-unique-name>"     # lowercase alphanumerics only

az acr create --resource-group "$RG" --name "$ACR_NAME" --sku Basic
az aks update --resource-group "$RG" --name "$CLUSTER" --attach-acr "$ACR_NAME"
```

`--attach-acr` grants the cluster's identity `AcrPull` and needs Owner or User
Access Administrator on the subscription. Without that permission, ask for the
role assignment to be made for you, or create an `imagePullSecret` and add it to
the pod specs instead.

### 3. Review the credentials

`k8s/10-secrets.yaml` ships placeholder passwords in plain text. They are fine
for a throwaway namespace, but change them now if this cluster is shared:

```bash
# Generate a real Rails secret
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Edit `SECRET_KEY_BASE`, `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, and
`DT_MONITOR_PASSWORD` in that file. The MySQL passwords are only read on the
**first** boot of an empty volume — changing them later means tearing down the
PVC or altering the users by hand.

### 4. Build and push the images

```bash
ACR_NAME="$ACR_NAME" ./scripts/build-and-push.sh
```

This runs `az acr build`, which uploads each app directory and builds it inside
ACR. Two reasons that is the default: no local Docker daemon is required, and
the result is `linux/amd64`, which is what AKS nodes run — a local `docker
build` on an Apple Silicon Mac would produce `arm64` images that fail to start
with `exec format error`.

Each build resolves gems fresh (there is no committed `Gemfile.lock` — see
[Notes](#notes-and-deliberate-choices)), so expect 3–6 minutes for the first
build of each image.

To build locally instead (needs Docker running; the script forces
`--platform linux/amd64`):

```bash
ACR_NAME="$ACR_NAME" ./scripts/build-and-push.sh local
```

### 5. Deploy

```bash
ACR_NAME="$ACR_NAME" ./scripts/deploy.sh
```

The script renders `k8s/kustomization.yaml` against your registry into a temp
directory (it does not modify the repo), then:

1. `kubectl apply -k` — namespace, secrets, MySQL, Redis, both apps, worker, loadgen
2. Waits for the MySQL StatefulSet to become ready
3. Runs `phr-api-migrate` and `phr-web-migrate` to migrate and seed both schemas
4. Waits for all rollouts
5. Prints the LoadBalancer address

First run takes 5–10 minutes, most of it MySQL initialising its data directory
and Azure provisioning the public IP.

To do it by hand instead of using the script:

```bash
# Point the image transformer at your registry
sed -i '' "s/REPLACE_WITH_ACR/${ACR_NAME}/" k8s/kustomization.yaml

kubectl apply -k k8s/
kubectl -n power-poc rollout status statefulset/mysql --timeout=600s
kubectl -n power-poc wait --for=condition=complete job/phr-api-migrate --timeout=600s
kubectl -n power-poc wait --for=condition=complete job/phr-web-migrate --timeout=600s
kubectl -n power-poc get svc phr-web -w
```

### 6. Verify

```bash
kubectl -n power-poc get pods

# Expected, once settled:
# mysql-0                       1/1  Running
# redis-xxxxxxxxx-xxxxx         1/1  Running
# phr-api-xxxxxxxxx-xxxxx       1/1  Running   (x2)
# phr-web-xxxxxxxxx-xxxxx       1/1  Running   (x2)
# phr-worker-xxxxxxxxx-xxxxx    1/1  Running
# phr-loadgen-xxxxxxxxx-xxxxx   1/1  Running
# phr-api-migrate-xxxxx         0/1  Completed
# phr-web-migrate-xxxxx         0/1  Completed
```

```bash
IP=$(kubectl -n power-poc get svc phr-web -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -s "http://${IP}/health" ; echo
curl -s "http://${IP}/ready"  ; echo      # {"status":"ready","database":"up","redis":"up"}
open "http://${IP}/"                      # dashboard
open "http://${IP}/sidekiq"               # Sidekiq queues and job history
```

No public IP? Reach it locally instead:

```bash
kubectl -n power-poc port-forward svc/phr-web 8080:80
# then http://localhost:8080/
```

Confirm the load generator is driving traffic, and that the worker is consuming
jobs:

```bash
kubectl -n power-poc logs -l app=phr-loadgen --tail=20 -f
kubectl -n power-poc logs -l app=phr-worker  --tail=20 -f
```

---

## Run locally with Docker Compose

Same images, same environment variables, same MySQL bootstrap script. Useful for
checking a change before pushing to ACR.

```bash
docker compose up --build              # phr-web :3000, phr-api :3001, mysql :3306
docker compose --profile loadgen up -d # add continuous traffic
docker compose logs -f worker
docker compose down -v                 # wipe everything, MySQL volume included
```

Migrations and seeds run as one-shot `api-migrate` / `web-migrate` services that
the app services wait on, so `up` gets you a populated database.

---

## What to exercise

### phr-web (through the LoadBalancer)

| Path | Notes |
|---|---|
| `/` | Dashboard. Aggregate queries against `phr_web` plus one HTTP call to `phr-api`. |
| `/customers`, `/customers/:id` | Paginated list and detail, local schema. |
| `/projects`, `/projects/:id` | Same, with a status filter. |
| `/leads`, `/leads/:id` | **Served entirely by `phr-api` over HTTP.** |
| `/appointments` | Same. |
| `/customers/new` | Form POST — a write path with CSRF, unlike everything else. |
| `/sidekiq` | Sidekiq dashboard: queue depth, retries, job history. |
| `/health`, `/ready` | Liveness (no MySQL) and readiness (MySQL + Redis). |

### Deliberate misbehaviour

`phr-web` — application-side:

| Path | Produces |
|---|---|
| `/debug/slow?seconds=3` | Slow response with the app sleeping, database idle. |
| `/debug/error` | Unhandled exception → 500. |
| `/debug/n_plus_one?limit=100` | ~100 sequential queries in one request. |
| `/debug/downstream?mode=slow` | Slowness that originates in `phr-api`. |
| `/debug/downstream?mode=error` | 502, caused by a 500 in `phr-api`. |
| `POST /internal/leads` | Creates a lead via `phr-api`, then enqueues Sidekiq. CSRF-exempt, no body needed. |

`phr-api` — database-side:

| Path | Produces |
|---|---|
| `/api/v1/simulate/slow_query?seconds=2` | `SELECT SLEEP(2)` — slow *in MySQL*. |
| `/api/v1/simulate/table_scan?term=roof` | Leading-wildcard `LIKE` on an unindexed `TEXT` column, with the `EXPLAIN` in the response. |
| `/api/v1/simulate/n_plus_one?limit=100` | N+1 at the API tier. |
| `/api/v1/simulate/cpu?ms=800` | CPU burn in Ruby, no I/O. |
| `/api/v1/simulate/error` | Unhandled exception → 500. |
| `/api/v1/leads/stats` | `GROUP BY` / `AVG` / `SUM` rollup — the heaviest legitimate query. |

The full cross-service write path, worth triggering by hand at least once:

```bash
IP=$(kubectl -n power-poc get svc phr-web -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -sS -X POST "http://${IP}/internal/leads" | python3 -m json.tool
```

That single request touches `phr-web` (HTTP in) → `phr-api` (HTTP out, MySQL
write) → Redis (enqueue) → `phr-worker` (dequeue) → `phr-api` (HTTP, MySQL
write) → and sometimes `phr_web` MySQL writes when the lead scores high enough
to provision a project. It is the best single test of whether context survives
every hop.

---

## Operations cookbook

```bash
# Logs
kubectl -n power-poc logs -l app=phr-web    --tail=100 -f
kubectl -n power-poc logs -l app=phr-api    --tail=100 -f
kubectl -n power-poc logs -l app=phr-worker --tail=100 -f
kubectl -n power-poc logs mysql-0           --tail=100

# A shell in a Rails pod
kubectl -n power-poc exec -it deploy/phr-web -- bash
kubectl -n power-poc exec -it deploy/phr-web -- bundle exec rails console

# A MySQL prompt (the client is in the app image too)
kubectl -n power-poc exec -it mysql-0 -- \
  mysql -uroot -p"$(kubectl -n power-poc get secret phr-mysql-secrets \
    -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)"

# Confirm both schemas and the monitoring user exist
kubectl -n power-poc exec -it mysql-0 -- sh -c \
  'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES; SELECT user,host,plugin FROM mysql.user;"'

# Traffic on/off
kubectl -n power-poc scale deploy/phr-loadgen --replicas=0
kubectl -n power-poc scale deploy/phr-loadgen --replicas=1

# Scale the app tier (each pod = WEB_CONCURRENCY x RAILS_MAX_THREADS DB connections)
kubectl -n power-poc scale deploy/phr-api --replicas=4

# Re-run migrations/seeds after a new image (Jobs are immutable, so delete first)
kubectl -n power-poc delete job phr-api-migrate phr-web-migrate --ignore-not-found
ACR_NAME="$ACR_NAME" ./scripts/deploy.sh

# Roll a new image tag
ACR_NAME="$ACR_NAME" TAG=v2 ./scripts/build-and-push.sh
ACR_NAME="$ACR_NAME" TAG=v2 ./scripts/deploy.sh

# Tear down (deletes the namespace and the MySQL disk)
./scripts/teardown.sh
```

---

## Where this goes next

The sandbox is the uninstrumented baseline. What each POC workstream has to work
with:

**Database monitoring.** MySQL 8.0 runs with `performance_schema` on, the
statement consumers enabled, and the slow query log capturing anything over one
second (`--long-query-time=1`, `--log-queries-not-using-indexes`). A read-only
`dtmonitor` user already exists with `PROCESS`, `REPLICATION CLIENT`, and
`SELECT` on `*.*` — the usual grant set for a monitoring extension — and its
password is in the `phr-mysql-secrets` Secret. Two schemas under load from
different services means attribution is actually testable, and
`/api/v1/simulate/table_scan` gives a query with a known-bad plan to find.

**OpenTelemetry instrumentation.** Nothing is instrumented yet. When it is, the
libraries that matter here are `rails`/`rack`, `mysql2` (both apps),
`net/http` (web → api, worker → api), and `sidekiq` (enqueue and dequeue).
The `POST /internal/leads` path crosses all four in one logical operation. Both
apps already read all configuration from the environment, so exporter endpoints
and resource attributes can be added to `k8s/30-app-config.yaml` without
touching the images.

**Dynatrace Operator.** The namespace carries a `monitoring: dynatrace-poc`
label to select on. Workloads run as non-root with `runAsUser: 1000` and all
capabilities dropped, which is the configuration most likely to expose an
injection problem. Every workload sets resource requests and limits, so
right-sizing and workload-level analysis have real numbers to work from. The
`mysql` StatefulSet, `phr-worker` Deployment, and the two migration Jobs cover
the non-Deployment workload kinds worth confirming.

---

## Troubleshooting

**Pods stuck `ImagePullBackOff`**
: The registry is not attached or the tag is wrong. Check
`kubectl -n power-poc describe pod <pod>`, then verify with
`az acr repository show-tags --name "$ACR_NAME" --repository phr-web`. Re-run
`az aks update --attach-acr "$ACR_NAME"` if the pull is unauthorized.

**`exec format error` in the app logs**
: An `arm64` image on `amd64` nodes. Rebuild with `./scripts/build-and-push.sh`
(the ACR path), or pass `--platform linux/amd64` if building locally.

**`mysql-0` never becomes ready**
: Usually storage. `kubectl -n power-poc get pvc` and
`kubectl -n power-poc describe pod mysql-0` — if the PVC is `Pending`, the
`storageClassName` in `k8s/20-mysql.yaml` does not match the cluster.

**Migration Job in `Error` / `BackoffLimitExceeded`**
: `kubectl -n power-poc logs job/phr-api-migrate`. If it is an access-denied
error, the MySQL passwords in `10-secrets.yaml` were changed after the volume
was already initialised — MySQL only reads them on first boot. Either revert
them or run `./scripts/teardown.sh` and redeploy.

**App pods ready, but the dashboard 500s**
: The migration Jobs have not completed. `kubectl -n power-poc get jobs`.

**Leads and Appointments pages show "Leads service unavailable"**
: `phr-web` is fine and `phr-api` is not. Check
`kubectl -n power-poc get pods -l app=phr-api` and confirm `PHR_API_URL` in
`k8s/30-app-config.yaml` matches the Service name.

**Sidekiq queue grows and nothing drains it**
: `kubectl -n power-poc logs -l app=phr-worker`. Confirm Redis is up
(`kubectl -n power-poc exec deploy/redis -- redis-cli ping`) and that
`/ready` on `phr-web` reports `"redis":"up"`.

---

## Notes and deliberate choices

- **No `Gemfile.lock` is committed.** Gems resolve at image build time, which
  keeps the repo buildable without a local Ruby toolchain. That means builds are
  not byte-for-byte reproducible. To pin them, lift the lockfile that the build
  already generated out of a running pod and commit it — the Dockerfiles pick up
  `Gemfile.lock` on the next build:

  ```bash
  kubectl -n power-poc exec deploy/phr-api -- cat /app/Gemfile.lock > apps/phr-api/Gemfile.lock
  kubectl -n power-poc exec deploy/phr-web -- cat /app/Gemfile.lock > apps/phr-web/Gemfile.lock
  ```
- **No asset pipeline and no Node.** Styles are inlined in
  `app/views/layouts/application.html.erb`, so the image build is a single
  `bundle install` with no JavaScript toolchain to go wrong.
- **MySQL runs with `mysql_native_password`.** The `mysql2` gem links against
  `libmariadb`, and MySQL 8's default `caching_sha2_password` handshake is the
  most common failure in that pairing. The flag is deprecated in 8.0.34+ and
  gone in 8.4, so revisit it on an upgrade.
- **The MySQL data directory is a `subPath` of the volume.** Azure Disks are
  formatted `ext4` and contain `lost+found`, which makes `mysqld --initialize`
  refuse to run on the mount root.
- **Migrations run as Jobs, not in the container entrypoint.** Two `phr-web`
  replicas starting at once would otherwise race each other.
- **Seeds are idempotent** (`find_or_initialize_by` keyed on email/SKU), so the
  migration Jobs are safe to re-run on every deploy.
- **`/health` never touches MySQL; `/ready` does.** A database blip should pull
  pods out of the Service, not restart every pod in the namespace.
- **Single MySQL replica, ephemeral Redis, plain-text Secrets.** This is a
  sandbox. None of it is a pattern to copy into anything real.
