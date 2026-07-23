#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

KEYCLOAK_VERSION=${KEYCLOAK_VERSION:-26.7.0}
KEYCLOAK_NAMESPACE=${KEYCLOAK_NAMESPACE:-keycloak}
KEYCLOAK_NAME=keycloak
KEYCLOAK_HOSTNAME=keycloak.localhost
TLS_DAYS=${TLS_DAYS:-3650}
TLS_CERT_FILE=""
TLS_KEY_FILE=""
KUSTOMIZE_DIR=""

cleanup() {
  [ -z "$TLS_CERT_FILE" ] || rm -f "$TLS_CERT_FILE"
  [ -z "$TLS_KEY_FILE" ] || rm -f "$TLS_KEY_FILE"
  [ -z "$KUSTOMIZE_DIR" ] || rm -rf "$KUSTOMIZE_DIR"
}

trap cleanup EXIT INT TERM

kubectl create namespace "$KEYCLOAK_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

KUSTOMIZE_DIR=$(mktemp -d)
cat >"$KUSTOMIZE_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $KEYCLOAK_NAMESPACE
resources:
  - github.com/keycloak/keycloak-k8s-resources/kubernetes?ref=$KEYCLOAK_VERSION
EOF

kubectl apply -k "$KUSTOMIZE_DIR"

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
Seal identity is installed.

Keycloak UI:
  kubectl -n $KEYCLOAK_NAMESPACE port-forward svc/$KEYCLOAK_NAME-service 8443:8443

Initial admin credentials:
  kubectl -n $KEYCLOAK_NAMESPACE get secret $KEYCLOAK_NAME-initial-admin -o jsonpath='{.data.username}' | base64 -d
  kubectl -n $KEYCLOAK_NAMESPACE get secret $KEYCLOAK_NAME-initial-admin -o jsonpath='{.data.password}' | base64 -d
EOF
