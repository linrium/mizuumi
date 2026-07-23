# Auth

This package installs Keycloak into Kubernetes with the Keycloak Operator and a
local PostgreSQL database for Auth identity development.

The checked-in manifests use a single Keycloak instance named `keycloak` in the
`keycloak` namespace. The setup is suitable for local development. It is not a
production identity topology.

Keycloak data is stored in PostgreSQL on a `1Gi` persistent volume claim.
Without persistent storage, Keycloak state resets on pod restart.

## Install

From `packages/auth`:

```sh
scripts/install.sh
```

The script installs:

```text
operator:           Keycloak Operator
operator version:   26.7.0
operator namespace: keycloak
keycloak namespace: keycloak
keycloak instance:  keycloak
hostname:           keycloak-service.keycloak.svc.cluster.local
database:           PostgreSQL 15
storage:            1Gi PostgreSQL data PVC
admin username:     admin
admin password:     admin
```

The operator version is pinned in `manifests/kustomization.yaml`.

```yaml
resources:
  - github.com/keycloak/keycloak-k8s-resources/kubernetes?ref=26.7.0
```

The operator install follows the upstream Kubernetes kustomization documented by
Keycloak:

```sh
kubectl apply -k manifests
```

## Access

Forward the Keycloak UI:

```sh
kubectl -n keycloak port-forward svc/keycloak-service 8443:8443
```

Then open `https://keycloak-service.keycloak.svc.cluster.local:8443`.

For browser access through port-forwarding, add the Kubernetes service hostname
to `/etc/hosts`:

```text
127.0.0.1 keycloak-service.keycloak.svc.cluster.local
```

The local certificate is self-signed, so local browser and CLI clients may
require accepting the certificate warning.

## Admin Credentials

The local development install bootstraps Keycloak with fixed initial admin
credentials:

```text
username: admin
password: admin
```

These credentials come from `manifests/admin.yaml` and are only honored before
the Keycloak master realm exists. For an existing database, change the password
from the admin console or reset the development database.

## Uninstall

Remove the Auth identity resources:

```sh
scripts/uninstall.sh
```

The script removes the Keycloak instance, local PostgreSQL resources, bootstrap
secrets, TLS secret, and operator. PVCs are preserved by default so local
identity data is not deleted accidentally. Delete the development database PVC
too with:

```sh
DELETE_DATA=true scripts/uninstall.sh
```

Delete the namespace too with:

```sh
DELETE_NAMESPACE=true scripts/uninstall.sh
```
