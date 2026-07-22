package main

const openAPISpec = `{
  "openapi": "3.1.0",
  "info": {
    "title": "Mizukagami API",
    "summary": "Fiber API for appending to and reading from a local Tessera POSIX transparency log.",
    "version": "0.1.0"
  },
  "servers": [
    {
      "url": "http://localhost:3000",
      "description": "Local development server"
    }
  ],
  "paths": {
    "/": {
      "get": {
        "summary": "Root",
        "operationId": "getRoot",
        "responses": {
          "200": {
            "description": "Service name",
            "content": {
              "text/plain": {
                "schema": {
                  "type": "string",
                  "example": "mizukagami"
                }
              }
            }
          }
        }
      }
    },
    "/healthz": {
      "get": {
        "summary": "Health check",
        "operationId": "getHealthz",
        "responses": {
          "200": {
            "description": "Service health",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/HealthResponse"
                }
              }
            }
          }
        }
      }
    },
    "/tessera": {
      "get": {
        "summary": "Tessera status",
        "operationId": "getTesseraStatus",
        "responses": {
          "200": {
            "description": "Tessera runtime status",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/TesseraStatus"
                }
              }
            }
          },
          "500": {
            "$ref": "#/components/responses/Error"
          }
        }
      }
    },
    "/entries": {
      "post": {
        "summary": "Append an entry",
        "description": "Appends the raw request body to the Tessera transparency log.",
        "operationId": "appendEntry",
        "requestBody": {
          "required": true,
          "content": {
            "text/plain": {
              "schema": {
                "type": "string",
                "example": "hello tessera"
              }
            },
            "application/octet-stream": {
              "schema": {
                "type": "string",
                "format": "binary"
              }
            }
          }
        },
        "responses": {
          "201": {
            "description": "Entry appended and assigned a Tessera log index",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/AppendEntryResponse"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/Error"
          },
          "500": {
            "$ref": "#/components/responses/Error"
          }
        }
      }
    },
    "/checkpoint": {
      "get": {
        "summary": "Read checkpoint",
        "operationId": "getCheckpoint",
        "responses": {
          "200": {
            "description": "Latest Tessera checkpoint",
            "content": {
              "text/plain": {
                "schema": {
                  "type": "string"
                }
              }
            }
          },
          "404": {
            "$ref": "#/components/responses/Error"
          },
          "500": {
            "$ref": "#/components/responses/Error"
          }
        }
      }
    },
    "/tile/{tilePath}": {
      "get": {
        "summary": "Read a Tessera tile resource",
        "description": "Reads a file from MIZUKAGAMI_LOG_DIR/tile/{tilePath}. Use /checkpoint and the tlog-tiles layout to derive tile paths.",
        "operationId": "getTile",
        "parameters": [
          {
            "name": "tilePath",
            "in": "path",
            "required": true,
            "description": "Path below the Tessera tile directory, for example entries/000.p/1 or 0/000.p/1.",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Tile bytes",
            "content": {
              "application/octet-stream": {
                "schema": {
                  "type": "string",
                  "format": "binary"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/Error"
          },
          "404": {
            "$ref": "#/components/responses/Error"
          },
          "500": {
            "$ref": "#/components/responses/Error"
          }
        }
      }
    },
    "/entries/{bundlePath}": {
      "get": {
        "summary": "Read a Tessera entry bundle",
        "description": "Convenience alias for MIZUKAGAMI_LOG_DIR/tile/entries/{bundlePath}.",
        "operationId": "getEntryBundle",
        "parameters": [
          {
            "name": "bundlePath",
            "in": "path",
            "required": true,
            "description": "Path below tile/entries, for example 000.p/1.",
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Entry bundle bytes",
            "content": {
              "application/octet-stream": {
                "schema": {
                  "type": "string",
                  "format": "binary"
                }
              }
            }
          },
          "400": {
            "$ref": "#/components/responses/Error"
          },
          "404": {
            "$ref": "#/components/responses/Error"
          },
          "500": {
            "$ref": "#/components/responses/Error"
          }
        }
      }
    },
    "/docs": {
      "get": {
        "summary": "Scalar API reference",
        "operationId": "getScalarDocs",
        "responses": {
          "200": {
            "description": "Scalar API reference HTML",
            "content": {
              "text/html": {
                "schema": {
                  "type": "string"
                }
              }
            }
          }
        }
      }
    },
    "/docs/doc.json": {
      "get": {
        "summary": "OpenAPI specification",
        "operationId": "getOpenAPISpec",
        "responses": {
          "200": {
            "description": "OpenAPI 3.1 specification",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object"
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "responses": {
      "Error": {
        "description": "Error response",
        "content": {
          "text/plain": {
            "schema": {
              "type": "string"
            }
          }
        }
      }
    },
    "schemas": {
      "HealthResponse": {
        "type": "object",
        "required": ["ok"],
        "properties": {
          "ok": {
            "type": "boolean",
            "example": true
          }
        }
      },
      "TesseraStatus": {
        "type": "object",
        "required": ["log_dir", "signer", "verifier_key", "next_index", "integrated_size"],
        "properties": {
          "log_dir": {
            "type": "string",
            "example": ".data/tessera"
          },
          "signer": {
            "type": "string",
            "example": "mizukagami"
          },
          "verifier_key": {
            "type": "string"
          },
          "next_index": {
            "type": "integer",
            "format": "uint64",
            "minimum": 0
          },
          "integrated_size": {
            "type": "integer",
            "format": "uint64",
            "minimum": 0
          }
        }
      },
      "AppendEntryResponse": {
        "type": "object",
        "required": ["index", "duplicate", "published_by"],
        "properties": {
          "index": {
            "type": "integer",
            "format": "uint64",
            "minimum": 0,
            "example": 0
          },
          "duplicate": {
            "type": "boolean",
            "example": false
          },
          "published_by": {
            "type": "string",
            "example": "/checkpoint"
          }
        }
      }
    }
  }
}`
