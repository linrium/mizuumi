#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

KEYCLOAK_NAMESPACE=auth
DELETE_DATA=${DELETE_DATA:-true}
DELETE_NAMESPACE=${DELETE_NAMESPACE:-true}

if kubectl get crd keycloaks.k8s.keycloak.org >/dev/null 2>&1; then
  kubectl -n "$KEYCLOAK_NAMESPACE" delete -f "$APP_DIR/manifests/keycloak.yaml" --ignore-not-found=true
fi

kubectl -n "$KEYCLOAK_NAMESPACE" delete -f "$APP_DIR/manifests/admin.yaml" --ignore-not-found=true
kubectl -n "$KEYCLOAK_NAMESPACE" delete -f "$APP_DIR/manifests/postgres.yaml" --ignore-not-found=true
kubectl -n "$KEYCLOAK_NAMESPACE" delete secret keycloak-tls --ignore-not-found=true

if [ "$DELETE_DATA" = "true" ]; then
  kubectl -n "$KEYCLOAK_NAMESPACE" delete pvc data-keycloak-postgres-0 --ignore-not-found=true
fi

kubectl delete -k "$APP_DIR/manifests" --ignore-not-found=true

if [ "$DELETE_NAMESPACE" = "true" ]; then
  kubectl delete namespace "$KEYCLOAK_NAMESPACE" --ignore-not-found=true
fi

cat <<EOF
Auth identity resources are removed.

Data PVC deletion:
  DELETE_DATA=$DELETE_DATA

Namespace deletion:
  DELETE_NAMESPACE=$DELETE_NAMESPACE
EOF
