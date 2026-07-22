# OpenAPI and Scalar

Mizukagami serves an embedded OpenAPI 3.1 specification through Scalar.

## Start the Server

```sh
go run .
```

## Open the API Reference

Open the Scalar UI:

```text
http://localhost:3000/docs
```

Fetch the raw OpenAPI JSON:

```sh
curl http://localhost:3000/docs/doc.json
```

## Implementation

The OpenAPI document is embedded in `openapi.go` as `openAPISpec`.

Scalar is mounted in `main.go`:

```go
app.Get("/docs/*", scalar.New(scalar.Config{
	FileContentString: openAPISpec,
	Path:              "/docs",
	Title:             "Mizukagami API",
	Theme:             scalar.ThemeDefault,
}))
```

Update `openapi.go` whenever routes, request bodies, or response bodies change.
