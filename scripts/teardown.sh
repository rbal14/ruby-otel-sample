#!/usr/bin/env bash
# Removes the sandbox. The PersistentVolumeClaim (and the Azure disk behind it)
# goes with the namespace, so the MySQL data is gone for good.
set -euo pipefail

NAMESPACE="${NAMESPACE:-power-poc}"

echo "This deletes namespace '${NAMESPACE}' and the MySQL PVC in it."
read -r -p "Type the namespace name to confirm: " reply
[[ "$reply" == "$NAMESPACE" ]] || { echo "aborted"; exit 1; }

kubectl delete namespace "$NAMESPACE" --wait=true
echo "done"
