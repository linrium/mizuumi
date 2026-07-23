# Mizukura

Mizukura installs RustFS into Kubernetes with the upstream Helm chart.

This package uses a one-node RustFS deployment. The RustFS chart documents that
distributed mode requires at least two nodes, so the checked-in values enable
standalone mode: one pod and one PVC.

## Install

From `packages/mizukura`:

```sh
scripts/install.sh
```

The script installs:

```text
release:   rustfs
namespace: mizukura
chart:     rustfs/rustfs
version:   0.10.0
mode:      standalone
replicas:  1
storage:   10Gi data PVC, 1Gi logs PVC
```

The script creates `secret/rustfs-auth` with default credentials if it does not
already exist:

```text
RUSTFS_ACCESS_KEY=admin
RUSTFS_SECRET_KEY=adminadmin
```

The secret key is at least eight characters so common S3 clients such as
`mc` accept it.

To provide credentials explicitly:

```sh
RUSTFS_ACCESS_KEY=... RUSTFS_SECRET_KEY=... scripts/install.sh
```

The install script does not overwrite an existing `secret/rustfs-auth`. If you
installed an older default, update both RustFS and any client namespace secrets
to the same value.

## Server-Side Encryption with Vault

After Vault is installed, initialized, and unsealed, configure RustFS SSE with
Vault transit:

```sh
VAULT_TOKEN=... scripts/configure-sse-vault.sh
```

The script creates or reuses the Vault transit mount, master key, policy, and a
RustFS Vault token. It stores the RustFS token in `secret/rustfs-kms-vault` and
upgrades the RustFS Helm release with KMS environment variables.
Rerunning the script updates the Vault policy used by existing RustFS tokens.
The RustFS deployment is restarted so it reloads token changes from the
Kubernetes Secret.
RustFS also reads KMS metadata from Vault KV-v2 at
`secret/data/rustfs/kms/transit-metadata/<key>`, so the script enables the
`secret/` KV-v2 mount when needed and grants access to that prefix.

The checked-in Vault package runs without TLS, so the default
`VAULT_RUSTFS_ADDR` uses `http://`. For that local development setup, the script
sets `RUSTFS_KMS_ALLOW_INSECURE_DEV_DEFAULTS=true`. Use an `https://` Vault
address for production.

Useful overrides:

```sh
VAULT_NAMESPACE=vault
VAULT_RELEASE=vault
VAULT_MOUNT_PATH=transit
VAULT_KV_MOUNT_PATH=secret
VAULT_KEY=rustfs-master-key
VAULT_RUSTFS_ADDR=http://vault.vault.svc:8200
RUSTFS_KMS_ALLOW_INSECURE_DEV_DEFAULTS=true
```

To skip Vault setup and reuse an existing client token:

```sh
RUSTFS_KMS_VAULT_TOKEN=... scripts/configure-sse-vault.sh
```

If the RustFS UI says it cannot load the KMS key list, refresh the policy by
rerunning the script. The RustFS token must be able to list `transit/keys` and
read `transit/keys/rustfs-master-key`.

If the UI key picker still fails, configure bucket SSE-KMS through the S3 API:

```sh
scripts/enable-bucket-sse-kms.sh <bucket>
```

The script reads RustFS credentials from `secret/rustfs-auth`, starts a temporary
port-forward to the RustFS API if `http://127.0.0.1:9000` is not already
reachable, calls `PutBucketEncryption`, and verifies with
`GetBucketEncryption`.

## Access

Forward the S3 API:

```sh
kubectl -n mizukura port-forward svc/rustfs-svc 9000:9000
```

Forward the console:

```sh
kubectl -n mizukura port-forward svc/rustfs-svc 9001:9001
```

Read the credentials:

```sh
kubectl -n mizukura get secret rustfs-auth \
  -o jsonpath='{.data.RUSTFS_ACCESS_KEY}' | base64 -d
kubectl -n mizukura get secret rustfs-auth \
  -o jsonpath='{.data.RUSTFS_SECRET_KEY}' | base64 -d
```

## Uninstall

```sh
helm uninstall rustfs -n mizukura
```

PVCs are left for Kubernetes storage policy handling. Check them before deleting
if the stored objects matter:

```sh
kubectl -n mizukura get pvc
```
