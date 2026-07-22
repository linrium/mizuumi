# Mizukagami

Mizukagami is a small Go Fiber server backed by a local Tessera POSIX transparency log.

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
MIZUKAGAMI_ADDR             listen address, default :3000
MIZUKAGAMI_LOG_DIR          Tessera POSIX log directory, default .data/tessera
MIZUKAGAMI_SIGNER_KEY_FILE  checkpoint signer key file, default .data/tessera/.state/signer.key
```

See [docs/tessera.md](docs/tessera.md) for usage examples.

See [docs/openapi.md](docs/openapi.md) for the OpenAPI and Scalar integration.
