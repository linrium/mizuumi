#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)

CLUSTER_NAME=${1:-${KIND_CLUSTER_NAME:-mizuumi}}
KIND_CONFIG=${KIND_CONFIG:-"$REPO_ROOT/infra/k8s/kind.yaml"}

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

need_cmd docker
need_cmd kind

[ -f "$KIND_CONFIG" ] || die "kind config not found: $KIND_CONFIG"

if ! docker info >/dev/null 2>&1; then
  die "Docker is not running or is not accessible"
fi

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster already exists: $CLUSTER_NAME"
  exit 0
fi

echo "Creating kind cluster: $CLUSTER_NAME"
kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG"
