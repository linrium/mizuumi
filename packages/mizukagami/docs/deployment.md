# Deployment

Mizukagami includes a Dockerfile and Kubernetes manifests for a single-replica deployment with persistent Tessera POSIX storage.

## Build the Image

From `packages/mizukagami`:

```sh
docker build -t mizukagami:latest .
```

Run it locally:

```sh
docker run --rm \
  -p 3000:3000 \
  -v mizukagami-data:/var/lib/mizukagami \
  mizukagami:latest
```

The image sets:

```text
MIZUKAGAMI_ADDR=:3000
MIZUKAGAMI_LOG_DIR=/var/lib/mizukagami/tessera
```

## Kubernetes

The manifests live in `k8s/` and include:

```text
namespace.yaml
persistent-volume-claim.yaml
deployment.yaml
service.yaml
kustomization.yaml
```

Apply them from `packages/mizukagami`:

```sh
kubectl apply -k k8s
```

For Docker Desktop Kubernetes, use the local deploy script:

```sh
scripts/deploy-local-docker-desktop.sh
```

The script expects the active Kubernetes context to be `docker-desktop`, builds `mizukagami:latest`, applies `k8s/`, and waits for the Deployment rollout.

Forward the service for local access:

```sh
kubectl -n mizukagami port-forward svc/mizukagami 3000:80
```

Then open:

```text
http://localhost:3000/docs
```

## Image Name

The default Deployment uses:

```text
mizukagami:latest
```

For a registry image, update `k8s/deployment.yaml`:

```yaml
image: ghcr.io/linrium/mizukagami:latest
```

## Storage

The Deployment mounts a `PersistentVolumeClaim` at:

```text
/var/lib/mizukagami
```

Tessera data and the checkpoint signer key are stored under:

```text
/var/lib/mizukagami/tessera
/var/lib/mizukagami/tessera/.state/signer.key
```

Keep this volume when restarting or upgrading the deployment. Deleting the signer key while keeping old log data changes the checkpoint signing identity.
