#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

RELEASE=${RELEASE:-kaniop}
NAMESPACE=${NAMESPACE:-kaniop}
CHART=${CHART:-oci://ghcr.io/pando85/helm-charts/kaniop}
KANIDM_NAMESPACE=${KANIDM_NAMESPACE:-default}
KANIDM_NAME=${KANIDM_NAME:-my-idm}
KANIDM_DOMAIN=${KANIDM_DOMAIN:-my-idm.localhost}
TLS_DAYS=${TLS_DAYS:-3650}
TLS_CERT_FILE=""
TLS_KEY_FILE=""

cleanup() {
  [ -z "$TLS_CERT_FILE" ] || rm -f "$TLS_CERT_FILE"
  [ -z "$TLS_KEY_FILE" ] || rm -f "$TLS_KEY_FILE"
}

trap cleanup EXIT INT TERM

helm upgrade --install "$RELEASE" "$CHART" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --wait \
  -f "$APP_DIR/values.yaml"

if [ "$KANIDM_NAMESPACE" != "default" ]; then
  kubectl create namespace "$KANIDM_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
fi

TLS_CERT_FILE=$(mktemp)
TLS_KEY_FILE=$(mktemp)
openssl req -x509 -nodes -newkey rsa:2048 \
  -days "$TLS_DAYS" \
  -keyout "$TLS_KEY_FILE" \
  -out "$TLS_CERT_FILE" \
  -subj "/CN=$KANIDM_DOMAIN" \
  -addext "subjectAltName=DNS:$KANIDM_DOMAIN,IP:127.0.0.1,IP:::1"

kubectl -n "$KANIDM_NAMESPACE" create secret tls "$KANIDM_NAME-tls" \
  --cert="$TLS_CERT_FILE" \
  --key="$TLS_KEY_FILE" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl -n "$KANIDM_NAMESPACE" apply -f "$APP_DIR/manifests/kanidm.yaml"

kubectl -n "$KANIDM_NAMESPACE" wait \
  --for=create pod \
  -l kanidm.kaniop.rs/cluster="$KANIDM_NAME" \
  --timeout=120s

kubectl -n "$KANIDM_NAMESPACE" wait \
  --for=condition=ready pod \
  -l kanidm.kaniop.rs/cluster="$KANIDM_NAME" \
  --timeout=300s

kubectl -n "$KANIDM_NAMESPACE" apply -f "$APP_DIR/manifests/accounts.yaml"

cat <<EOF
Seal identity is installed.

Kanidm UI:
  kubectl -n $KANIDM_NAMESPACE port-forward svc/$KANIDM_NAME 8443:8443

Person account:
  username: linh
  email:    linh@example.com

Credential reset link, if needed:
  kubectl -n $KANIDM_NAMESPACE describe kanidmpersonaccount linh

Seal service account secrets:
  kubectl -n $KANIDM_NAMESPACE get secret seal-kanidm-service-account-credentials -o jsonpath='{.data.password}' | base64 -d
  kubectl -n $KANIDM_NAMESPACE get secret seal-kanidm-api-token -o jsonpath='{.data.token}' | base64 -d
EOF
