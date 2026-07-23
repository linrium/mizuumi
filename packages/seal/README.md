# Seal

This package installs Kanidm into Kubernetes with the Kaniop operator and
creates the local identity resources used by Seal.

The checked-in manifests use the Kaniop quickstart topology: one Kanidm
write-replica named `my-idm` in the `default` namespace, using the quickstart
TLS secret. This is suitable for local development. It is not a production
identity topology.

Kanidm data is stored on a `1Gi` persistent volume claim. Without persistent
storage, Kanidm resets on pod restart and the generated Kaniop admin secret can
become stale.

## Install

From `packages/seal`:

```sh
scripts/install.sh
```

The script installs:

```text
operator release:  kaniop
operator namespace: kaniop
chart:             oci://ghcr.io/pando85/helm-charts/kaniop
kanidm namespace:  default
kanidm cluster:    my-idm
storage:           1Gi data PVC
person account:    linh / linh@example.com
service account:   seal / seal@example.com
service token:     seal-kanidm-api-token
service password:  seal-kanidm-service-account-credentials
```

Override defaults with environment variables:

```sh
RELEASE=kaniop NAMESPACE=kaniop KANIDM_NAMESPACE=default scripts/install.sh
```

## Access

Forward the Kanidm UI:

```sh
kubectl -n default port-forward svc/my-idm 8443:8443
```

Then open `https://127.0.0.1:8443` or `https://localhost:8443`.

For credential setup and passkeys, use `https://my-idm.localhost:8443`. The
Kanidm origin is configured to that URL because passkeys require the browser
origin to match Kanidm's configured WebAuthn origin.

If `my-idm.localhost` does not resolve on your machine, add it to `/etc/hosts`:

```text
127.0.0.1 my-idm.localhost
```

The quickstart certificate is self-signed, so local browser and CLI clients may
require accepting the certificate warning.

## Accounts

The person account is intentionally created without credentials:

```text
username: linh
email:    linh@example.com
```

Kaniop publishes a short-lived credential reset link as an event when the
account is created:

```sh
kubectl -n default describe kanidmpersonaccount linh
```

The reset event prints a URL without the local forwarded port. When using
port-forwarding, open the same token at:

```text
https://my-idm.localhost:8443/ui/reset?token=<token>
```

The Seal service account has generated credentials and a read-only API token.
Read them from Kubernetes secrets:

```sh
kubectl -n default get secret seal-kanidm-service-account-credentials -o jsonpath='{.data.password}' | base64 -d
kubectl -n default get secret seal-kanidm-api-token -o jsonpath='{.data.token}' | base64 -d
```

## Uninstall

Remove the Seal identity resources and Kanidm cluster:

```sh
kubectl -n default delete -f manifests/accounts.yaml
kubectl -n default delete -f manifests/kanidm.yaml
kubectl -n default delete secret my-idm-tls
```

Remove the operator:

```sh
helm uninstall kaniop -n kaniop
```

PVCs may remain depending on the Kubernetes storage policy. Check them before
deleting if the identity data matters:

```sh
kubectl -n default get pvc
```
