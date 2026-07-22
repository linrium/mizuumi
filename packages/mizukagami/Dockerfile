ARG GO_VERSION=1.26.4

FROM golang:${GO_VERSION}-alpine AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/mizukagami .

FROM alpine:3.22

RUN addgroup -S -g 65532 mizukagami && adduser -S -D -H -u 65532 -G mizukagami mizukagami

WORKDIR /app
COPY --from=build /out/mizukagami /app/mizukagami

RUN mkdir -p /var/lib/mizukagami/tessera && chown -R mizukagami:mizukagami /var/lib/mizukagami

USER mizukagami

ENV MIZUKAGAMI_ADDR=:3000
ENV MIZUKAGAMI_LOG_DIR=/var/lib/mizukagami/tessera

EXPOSE 3000

ENTRYPOINT ["/app/mizukagami"]
