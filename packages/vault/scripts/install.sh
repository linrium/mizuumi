#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

RELEASE=${RELEASE:-vault}
NAMESPACE=${NAMESPACE:-vault}
CHART=${CHART:-hashicorp/vault}
CHART_VERSION=${CHART_VERSION:-0.34.0}

helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
helm repo update hashicorp

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --version "$CHART_VERSION" \
  -f "$APP_DIR/values.yaml"

kubectl -n "$NAMESPACE" wait --for=create pod/"$RELEASE-0" --timeout=120s
kubectl -n "$NAMESPACE" wait --for=condition=Initialized pod/"$RELEASE-0" --timeout=120s

if kubectl -n "$NAMESPACE" get deployment "$RELEASE-agent-injector" >/dev/null 2>&1; then
  kubectl -n "$NAMESPACE" rollout status deployment/"$RELEASE-agent-injector"
fi

cat <<EOF
Vault is installed.

API/UI:
  kubectl -n $NAMESPACE port-forward svc/$RELEASE 8200:8200

First-time initialization:
  kubectl -n $NAMESPACE exec -it $RELEASE-0 -- vault operator init
  kubectl -n $NAMESPACE exec -it $RELEASE-0 -- vault operator unseal

Until Vault is initialized and unsealed, the server pod can be Running but not
Ready and may log "security barrier not initialized". That is expected.

Vault is configured in standalone mode with file storage. Store the init output
securely; unseal keys and the root token are not recoverable from Kubernetes.
EOF
