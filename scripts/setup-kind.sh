#!/usr/bin/env sh
set -eu

CLUSTER_NAME=${KIND_CLUSTER_NAME:-mizuumi}
INSTALL_DIR=${KIND_INSTALL_DIR:-"$HOME/.local/bin"}
KIND_VERSION=${KIND_VERSION:-latest}
RECREATE=${KIND_RECREATE:-false}
NODE_IMAGE=${KIND_NODE_IMAGE:-}
KIND_BIN=${KIND_BIN:-}

die() {
  echo "error: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo darwin ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    arm64 | aarch64) echo arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
}

install_kind() {
  if [ -n "$KIND_BIN" ]; then
    [ -x "$KIND_BIN" ] || die "KIND_BIN is not executable: $KIND_BIN"
    echo "using kind: $KIND_BIN"
    return
  fi

  if command -v kind >/dev/null 2>&1; then
    KIND_BIN=$(command -v kind)
    echo "kind already installed: $KIND_BIN"
    return
  fi

  need_cmd curl
  need_cmd chmod
  need_cmd mkdir
  need_cmd mv

  os=$(detect_os)
  arch=$(detect_arch)
  mkdir -p "$INSTALL_DIR"

  if [ "$KIND_VERSION" = "latest" ]; then
    url="https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-$os-$arch"
  else
    url="https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-$os-$arch"
  fi

  tmp="${TMPDIR:-/tmp}/kind.$$"
  echo "Installing kind from $url"
  curl -fsSL "$url" -o "$tmp"
  chmod +x "$tmp"
  KIND_BIN="$INSTALL_DIR/kind"
  mv "$tmp" "$KIND_BIN"

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) echo "warning: $INSTALL_DIR is not in PATH; add it or run $INSTALL_DIR/kind directly" >&2 ;;
  esac
}

cluster_exists() {
  "$KIND_BIN" get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"
}

create_cluster() {
  if cluster_exists; then
    if [ "$RECREATE" = "true" ]; then
      echo "Deleting existing kind cluster: $CLUSTER_NAME"
      "$KIND_BIN" delete cluster --name "$CLUSTER_NAME"
    else
      echo "kind cluster already exists: $CLUSTER_NAME"
      echo "Set KIND_RECREATE=true to delete and recreate it."
      return
    fi
  fi

  config="${TMPDIR:-/tmp}/kind-two-node.$$"
  trap 'rm -f "$config"' EXIT INT TERM

  {
    echo "kind: Cluster"
    echo "apiVersion: kind.x-k8s.io/v1alpha4"
    echo "nodes:"
    echo "- role: control-plane"
    echo "- role: worker"
  } >"$config"

  echo "Creating kind cluster '$CLUSTER_NAME' with 2 nodes"
  if [ -n "$NODE_IMAGE" ]; then
    "$KIND_BIN" create cluster --name "$CLUSTER_NAME" --config "$config" --image "$NODE_IMAGE"
  else
    "$KIND_BIN" create cluster --name "$CLUSTER_NAME" --config "$config"
  fi
}

main() {
  install_kind
  need_cmd docker

  if ! docker info >/dev/null 2>&1; then
    die "Docker is not running or is not accessible"
  fi

  create_cluster
  "$KIND_BIN" get nodes --name "$CLUSTER_NAME"
}

main "$@"
