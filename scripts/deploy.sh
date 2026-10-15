#!/usr/bin/env bash
# Deploys the sandbox to whatever cluster kubectl currently points at.
#
#   ACR_NAME=myacr ./scripts/deploy.sh
#   ACR_NAME=myacr TAG=v2 ./scripts/deploy.sh
#
# The repo's kustomization.yaml keeps a placeholder registry. This script
# renders a copy with the real one rather than editing the file in place, so the
# repo stays reusable across registries.
set -euo pipefail

ACR_NAME="${ACR_NAME:-}"
TAG="${TAG:-v1}"
NAMESPACE="${NAMESPACE:-power-poc}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$ACR_NAME" ]]; then
  echo "ACR_NAME is required, e.g. ACR_NAME=phrpocacr $0" >&2
  exit 1
fi
ACR_NAME="${ACR_NAME%.azurecr.io}"
command -v kubectl >/dev/null || { echo "kubectl not found" >&2; exit 1; }

echo "==> cluster: $(kubectl config current-context)"
echo "==> registry: ${ACR_NAME}.azurecr.io, tag: ${TAG}, namespace: ${NAMESPACE}"

RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT
cp -R "${REPO_ROOT}/k8s/." "$RENDER_DIR/"

# Point the image transformer at the real registry and tag.
python3 - "$RENDER_DIR/kustomization.yaml" "$ACR_NAME" "$TAG" <<'PY'
import re, sys
path, acr, tag = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as fh:
    text = fh.read()
text = text.replace("REPLACE_WITH_ACR.azurecr.io", f"{acr}.azurecr.io")
text = re.sub(r"(\n\s+newTag:\s*)\S+", rf"\g<1>{tag}", text)
with open(path, "w") as fh:
    fh.write(text)
PY

# Jobs are immutable, so a re-deploy needs them removed before they can run
# against the new image.
echo "==> clearing previous migration jobs"
kubectl -n "$NAMESPACE" delete job phr-api-migrate phr-web-migrate \
  --ignore-not-found --wait=true >/dev/null 2>&1 || true

echo "==> applying manifests"
kubectl apply -k "$RENDER_DIR"

echo "==> waiting for MySQL (first boot initialises the data directory)"
kubectl -n "$NAMESPACE" rollout status statefulset/mysql --timeout=600s

for job in phr-api-migrate phr-web-migrate; do
  echo "==> waiting for ${job}"
  if ! kubectl -n "$NAMESPACE" wait --for=condition=complete "job/${job}" --timeout=600s; then
    echo "!! ${job} did not complete. Logs:" >&2
    kubectl -n "$NAMESPACE" logs "job/${job}" --tail=80 >&2 || true
    exit 1
  fi
done

echo "==> waiting for application rollouts"
kubectl -n "$NAMESPACE" rollout status deploy/phr-api    --timeout=300s
kubectl -n "$NAMESPACE" rollout status deploy/phr-web    --timeout=300s
kubectl -n "$NAMESPACE" rollout status deploy/phr-worker --timeout=300s
kubectl -n "$NAMESPACE" rollout status deploy/redis      --timeout=300s

echo "==> waiting for the phr-web load balancer address"
EXTERNAL_IP=""
for _ in $(seq 1 60); do
  EXTERNAL_IP="$(kubectl -n "$NAMESPACE" get svc phr-web \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [[ -n "$EXTERNAL_IP" ]] && break
  sleep 5
done

echo
kubectl -n "$NAMESPACE" get pods -o wide
echo
if [[ -n "$EXTERNAL_IP" ]]; then
  echo "phr-web is at: http://${EXTERNAL_IP}/"
  echo "  dashboard   http://${EXTERNAL_IP}/"
  echo "  sidekiq     http://${EXTERNAL_IP}/sidekiq"
  echo "  health      http://${EXTERNAL_IP}/health"
else
  echo "No external IP yet. Check with:"
  echo "  kubectl -n ${NAMESPACE} get svc phr-web -w"
  echo "Or reach it locally with:"
  echo "  kubectl -n ${NAMESPACE} port-forward svc/phr-web 8080:80"
fi
