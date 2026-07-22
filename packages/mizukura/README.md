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
