#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

KEYCLOAK_NAMESPACE=auth
KEYCLOAK_NAME=keycloak
KEYCLOAK_HOSTNAME=keycloak-service.keycloak.svc.cluster.local
TLS_DAYS=${TLS_DAYS:-3650}
TLS_CERT_FILE=""
TLS_KEY_FILE=""

cleanup() {
  [ -z "$TLS_CERT_FILE" ] || rm -f "$TLS_CERT_FILE"
  [ -z "$TLS_KEY_FILE" ] || rm -f "$TLS_KEY_FILE"
}

trap cleanup EXIT INT TERM

kubectl create namespace "$KEYCLOAK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k "$APP_DIR/manifests"

kubectl -n "$KEYCLOAK_NAMESPACE" wait \
  --for=condition=available deployment/keycloak-operator \
  --timeout=300s

TLS_CERT_FILE=$(mktemp)
TLS_KEY_FILE=$(mktemp)
openssl req -x509 -nodes -newkey rsa:2048 \
  -days "$TLS_DAYS" \
  -keyout "$TLS_KEY_FILE" \
  -out "$TLS_CERT_FILE" \
  -subj "/CN=$KEYCLOAK_HOSTNAME" \
  -addext "subjectAltName=DNS:$KEYCLOAK_HOSTNAME,IP:127.0.0.1,IP:::1"

kubectl -n "$KEYCLOAK_NAMESPACE" create secret tls keycloak-tls \
  --cert="$TLS_CERT_FILE" \
  --key="$TLS_KEY_FILE" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl -n "$KEYCLOAK_NAMESPACE" apply -f "$APP_DIR/manifests/admin.yaml"
kubectl -n "$KEYCLOAK_NAMESPACE" apply -f "$APP_DIR/manifests/postgres.yaml"

kubectl -n "$KEYCLOAK_NAMESPACE" wait \
  --for=condition=ready pod \
  -l app=keycloak-postgres \
  --timeout=300s

kubectl -n "$KEYCLOAK_NAMESPACE" apply -f "$APP_DIR/manifests/keycloak.yaml"

kubectl -n "$KEYCLOAK_NAMESPACE" wait \
  --for=condition=Ready "keycloaks.k8s.keycloak.org/$KEYCLOAK_NAME" \
  --timeout=600s

cat <<EOF
Auth identity is installed.

Keycloak UI:
  kubectl -n $KEYCLOAK_NAMESPACE port-forward svc/$KEYCLOAK_NAME-service 8443:8443

Initial admin credentials:
  username: admin
  password: admin
EOF
