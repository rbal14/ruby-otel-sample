#!/usr/bin/env bash
# Builds phr-api and phr-web and puts them in ACR.
#
#   ACR_NAME=myacr ./scripts/build-and-push.sh           # build in Azure (default)
#   ACR_NAME=myacr TAG=v2 ./scripts/build-and-push.sh
#   ACR_NAME=myacr ./scripts/build-and-push.sh local     # build with local Docker
#
# The default mode uses `az acr build`, which builds inside ACR. That needs no
# local Docker daemon and -- importantly on an Apple Silicon Mac -- produces
# linux/amd64 images that AKS nodes can actually run.
set -euo pipefail

ACR_NAME="${ACR_NAME:-}"
TAG="${TAG:-v1}"
MODE="${1:-acr}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$ACR_NAME" ]]; then
  echo "ACR_NAME is required, e.g. ACR_NAME=phrpocacr $0" >&2
  exit 1
fi

# Accept either "myacr" or "myacr.azurecr.io".
ACR_NAME="${ACR_NAME%.azurecr.io}"

build_in_azure() {
  local app="$1"
  echo "==> az acr build ${app}:${TAG} (built in ACR, linux/amd64)"
  # No --file: it is resolved relative to the uploaded build context, and each
  # app's Dockerfile already sits at the root of its own context.
  az acr build \
    --registry "$ACR_NAME" \
    --image "${app}:${TAG}" \
    --image "${app}:latest" \
    "${REPO_ROOT}/apps/${app}"
}

build_locally() {
  local app="$1"
  local ref="${ACR_NAME}.azurecr.io/${app}"
  echo "==> docker build ${ref}:${TAG} (forcing linux/amd64 for AKS nodes)"
  docker build \
    --platform linux/amd64 \
    -t "${ref}:${TAG}" \
    -t "${ref}:latest" \
    -f "${REPO_ROOT}/apps/${app}/Dockerfile" \
    "${REPO_ROOT}/apps/${app}"
  docker push "${ref}:${TAG}"
  docker push "${ref}:latest"
}

case "$MODE" in
  acr)
    command -v az >/dev/null || { echo "az CLI not found" >&2; exit 1; }
    build_in_azure phr-api
    build_in_azure phr-web
    ;;
  local)
    command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
    az acr login --name "$ACR_NAME"
    build_locally phr-api
    build_locally phr-web
    ;;
  *)
    echo "unknown mode '$MODE' (expected 'acr' or 'local')" >&2
    exit 1
    ;;
esac

echo
echo "Images pushed:"
echo "  ${ACR_NAME}.azurecr.io/phr-api:${TAG}"
echo "  ${ACR_NAME}.azurecr.io/phr-web:${TAG}"
echo
echo "Next: ACR_NAME=${ACR_NAME} TAG=${TAG} ./scripts/deploy.sh"
