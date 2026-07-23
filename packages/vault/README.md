# Vault

This package installs HashiCorp Vault into Kubernetes with the upstream Helm
chart.

The checked-in values use a one-node standalone Vault server with a persistent
data PVC and the Vault Agent Injector enabled. This is useful for local or small
cluster development. It is not a production Vault topology.

## Install

From `packages/vault`:

```sh
scripts/install.sh
```

The script installs:

```text
release:   vault
namespace: vault
chart:     hashicorp/vault
version:   0.34.0
mode:      standalone
storage:   10Gi data PVC
ui:        enabled
injector:  enabled
```

Override defaults with environment variables:

```sh
RELEASE=vault NAMESPACE=vault CHART_VERSION=0.34.0 scripts/install.sh
```

## Access

Forward the API and UI:

```sh
kubectl -n vault port-forward svc/vault 8200:8200
```

Use:

```text
VAULT_ADDR=http://127.0.0.1:8200
```

Then open `http://127.0.0.1:8200` for the UI.

## Keycloak OIDC Login

Configure Vault to use the local Keycloak instance for OIDC login:

```sh
VAULT_TOKEN=... scripts/configure-keycloak-oidc.sh
```

The script creates or updates a confidential Keycloak client named `vault`,
enables Vault's `oidc` auth method, and maps OIDC logins to a local development
Vault admin policy.

Before using the browser login, forward Vault and Keycloak:

```sh
kubectl -n vault port-forward svc/vault 8200:8200
kubectl -n keycloak port-forward svc/keycloak-service 8443:8443
```

Add the Keycloak local hostname to `/etc/hosts` if needed:

```text
127.0.0.1 keycloak-service.keycloak.svc.cluster.local
```

Then open:

```text
http://127.0.0.1:8200/ui/vault/auth?with=oidc
```

Use the local Keycloak credentials:

```text
username: admin
password: admin
```

CLI login also works:

```sh
VAULT_ADDR=http://127.0.0.1:8200 vault login -method=oidc role=keycloak
```

## Initialize

Vault must be initialized once after the first install:

```sh
kubectl -n vault exec -it vault-0 -- vault operator init
```

Until this is done, Vault may repeatedly log:

```text
core: security barrier not initialized
core: seal configuration missing, not initialized
```

That is expected on a fresh data volume.

Store the unseal keys and root token securely. They are not recoverable from
Kubernetes if lost.

Unseal Vault with the required key threshold from the init output:

```sh
kubectl -n vault exec -it vault-0 -- vault operator unseal
```

Check status:

```sh
kubectl -n vault exec vault-0 -- vault status
```

## Uninstall

```sh
helm uninstall vault -n vault
```

PVCs may remain depending on the Kubernetes storage policy. Check them before
deleting if the stored secrets matter:

```sh
kubectl -n vault get pvc
```
