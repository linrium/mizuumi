# Mizukagami

Mizukagami is a small Go Fiber server backed by a Tessera transparency log.
Local runs use Tessera POSIX storage by default. The Kubernetes manifests use
Tessera's AWS/S3 backend with RustFS for object storage and MySQL for
sequencing.

## Module

```text
github.com/linrium/mizuumi/packages/mizukagami
```

## Run

```sh
go run .
```

The server listens on `:3000`.

The default Tessera log directory is `.data/tessera`.

## Routes

```text
GET  /             mizukagami
GET  /healthz      {"ok":true}
GET  /tessera      Tessera runtime status
POST /entries      Append the request body to the Tessera log
GET  /checkpoint   Latest Tessera checkpoint
GET  /tile/*       Tessera tile resources
GET  /entries/*    Convenience alias for Tessera entry bundles under /tile/entries/*
GET  /docs/*       Scalar API reference and OpenAPI spec
```

## Configuration

```text
MIZUKAGAMI_ADDR                         listen address, default :3000
MIZUKAGAMI_STORAGE_BACKEND              posix or aws-s3, default posix
MIZUKAGAMI_LOG_DIR                      Tessera POSIX log directory, default .data/tessera
MIZUKAGAMI_SIGNER_KEY_FILE              checkpoint signer key file, default .data/tessera/.state/signer.key
MIZUKAGAMI_AWS_S3_ENDPOINT              S3 endpoint for aws-s3 storage
MIZUKAGAMI_AWS_S3_BUCKET                S3 bucket for aws-s3 storage
MIZUKAGAMI_AWS_S3_BUCKET_PREFIX         optional S3 object prefix
MIZUKAGAMI_AWS_S3_ACCESS_KEY            S3 access key
MIZUKAGAMI_AWS_S3_SECRET_KEY            S3 secret key
MIZUKAGAMI_AWS_S3_REGION                S3 signing region, default us-east-1
MIZUKAGAMI_AWS_S3_USE_PATH_STYLE        path-style S3 addressing, default true
MIZUKAGAMI_AWS_MYSQL_DSN                optional full MySQL DSN
MIZUKAGAMI_AWS_MYSQL_HOST               MySQL host, default mysql
MIZUKAGAMI_AWS_MYSQL_PORT               MySQL port, default 3306
MIZUKAGAMI_AWS_MYSQL_DATABASE           MySQL database, default tessera
MIZUKAGAMI_AWS_MYSQL_USER               MySQL user
MIZUKAGAMI_AWS_MYSQL_PASSWORD           MySQL password
MIZUKAGAMI_AWS_MYSQL_MAX_OPEN_CONNS     MySQL max open connections, default 0
MIZUKAGAMI_AWS_MYSQL_MAX_IDLE_CONNS     MySQL max idle connections, default 2
```

## Container

```sh
docker build -t mizukagami:latest .
docker run --rm -p 3000:3000 -v mizukagami-data:/var/lib/mizukagami mizukagami:latest
```

## Kubernetes

```sh
cd ../mizukura && scripts/install.sh
cd ../mizukagami
kubectl apply -k k8s
kubectl -n mizukagami port-forward svc/mizukagami 3000:80
```

For Docker Desktop Kubernetes:

```sh
scripts/deploy-local-docker-desktop.sh
```

See [docs/tessera.md](docs/tessera.md) for usage examples.

See [docs/openapi.md](docs/openapi.md) for the OpenAPI and Scalar integration.
