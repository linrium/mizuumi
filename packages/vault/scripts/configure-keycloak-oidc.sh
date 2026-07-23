#!/usr/bin/env sh
set -eu

VAULT_NAMESPACE=${VAULT_NAMESPACE:-vault}
VAULT_POD=${VAULT_POD:-vault-0}
VAULT_EXEC_ADDR=${VAULT_EXEC_ADDR:-http://127.0.0.1:8200}
VAULT_PUBLIC_ADDR=${VAULT_PUBLIC_ADDR:-http://127.0.0.1:8200}
VAULT_OIDC_ROLE=${VAULT_OIDC_ROLE:-keycloak}
VAULT_OIDC_POLICY=${VAULT_OIDC_POLICY:-keycloak-admin}

KEYCLOAK_NAMESPACE=${KEYCLOAK_NAMESPACE:-keycloak}
KEYCLOAK_POD=${KEYCLOAK_POD:-keycloak-0}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-master}
KEYCLOAK_HOSTNAME=${KEYCLOAK_HOSTNAME:-keycloak-service.keycloak.svc.cluster.local}
KEYCLOAK_SERVICE=${KEYCLOAK_SERVICE:-keycloak-service}
KEYCLOAK_OIDC_CLIENT_ID=${KEYCLOAK_OIDC_CLIENT_ID:-vault}
KEYCLOAK_OIDC_CLIENT_SECRET=${KEYCLOAK_OIDC_CLIENT_SECRET:-vault-dev-secret}
KEYCLOAK_ADMIN_USERNAME=${KEYCLOAK_ADMIN_USERNAME:-admin}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-admin}

if [ -z "${VAULT_TOKEN:-}" ]; then
  cat >&2 <<EOF
Set VAULT_TOKEN to a Vault admin/root token before running this script.

Example:
  VAULT_TOKEN=... $0
EOF
  exit 1
fi

keycloak_url="https://$KEYCLOAK_HOSTNAME:8443"
issuer_url="$keycloak_url/realms/$KEYCLOAK_REALM"
vault_ui_redirect_127="$VAULT_PUBLIC_ADDR/ui/vault/auth/oidc/oidc/callback"
vault_ui_redirect_localhost="http://localhost:8200/ui/vault/auth/oidc/oidc/callback"
vault_cli_redirect="http://localhost:8250/oidc/callback"

keycloak_service_ip=$(kubectl -n "$KEYCLOAK_NAMESPACE" get svc "$KEYCLOAK_SERVICE" -o jsonpath='{.spec.clusterIP}')

kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- \
  keytool -importcert -noprompt \
    -alias keycloak-local \
    -file /mnt/certificates/tls.crt \
    -keystore /tmp/keycloak-local-truststore.p12 \
    -storetype PKCS12 \
    -storepass changeit >/dev/null 2>&1 || true

kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- \
  /opt/keycloak/bin/kcadm.sh config credentials \
    --server https://127.0.0.1:8443 \
    --realm master \
    --user "$KEYCLOAK_ADMIN_USERNAME" \
    --password "$KEYCLOAK_ADMIN_PASSWORD" \
    --truststore /tmp/keycloak-local-truststore.p12 \
    --trustpass changeit >/dev/null

client_uuid=$(kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- sh -c "
  export KC_OPTS='-Djavax.net.ssl.trustStore=/tmp/keycloak-local-truststore.p12 -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12'
  /opt/keycloak/bin/kcadm.sh get clients -r '$KEYCLOAK_REALM' -q clientId='$KEYCLOAK_OIDC_CLIENT_ID' --fields id | sed -n 's/.*\"id\" : \"\\([^\"]*\\)\".*/\\1/p'
")

if [ -z "$client_uuid" ]; then
  kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- sh -c "
    export KC_OPTS='-Djavax.net.ssl.trustStore=/tmp/keycloak-local-truststore.p12 -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12'
    /opt/keycloak/bin/kcadm.sh create clients -r '$KEYCLOAK_REALM' \
      -s clientId='$KEYCLOAK_OIDC_CLIENT_ID' \
      -s name='Vault' \
      -s enabled=true \
      -s protocol=openid-connect \
      -s publicClient=false \
      -s clientAuthenticatorType=client-secret \
      -s standardFlowEnabled=true \
      -s directAccessGrantsEnabled=false \
      -s serviceAccountsEnabled=false
  " >/dev/null
  client_uuid=$(kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- sh -c "
    export KC_OPTS='-Djavax.net.ssl.trustStore=/tmp/keycloak-local-truststore.p12 -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12'
    /opt/keycloak/bin/kcadm.sh get clients -r '$KEYCLOAK_REALM' -q clientId='$KEYCLOAK_OIDC_CLIENT_ID' --fields id | sed -n 's/.*\"id\" : \"\\([^\"]*\\)\".*/\\1/p'
  ")
fi

kubectl -n "$KEYCLOAK_NAMESPACE" exec "$KEYCLOAK_POD" -- sh -c "
  export KC_OPTS='-Djavax.net.ssl.trustStore=/tmp/keycloak-local-truststore.p12 -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStoreType=PKCS12'
  cat >/tmp/vault-client.json <<EOF
{
  \"clientId\": \"$KEYCLOAK_OIDC_CLIENT_ID\",
  \"name\": \"Vault\",
  \"enabled\": true,
  \"protocol\": \"openid-connect\",
  \"publicClient\": false,
  \"clientAuthenticatorType\": \"client-secret\",
  \"secret\": \"$KEYCLOAK_OIDC_CLIENT_SECRET\",
  \"standardFlowEnabled\": true,
  \"directAccessGrantsEnabled\": false,
  \"serviceAccountsEnabled\": false,
  \"redirectUris\": [
    \"$vault_ui_redirect_127\",
    \"$vault_ui_redirect_localhost\",
    \"$vault_cli_redirect\"
  ],
  \"webOrigins\": [
    \"$VAULT_PUBLIC_ADDR\",
    \"http://localhost:8200\"
  ]
}
EOF
  /opt/keycloak/bin/kcadm.sh update clients/$client_uuid -r '$KEYCLOAK_REALM' -f /tmp/vault-client.json
" >/dev/null

if ! kubectl -n "$VAULT_NAMESPACE" exec "$VAULT_POD" -- nslookup "$KEYCLOAK_HOSTNAME" | grep -q "$keycloak_service_ip"; then
  cat >&2 <<EOF
$KEYCLOAK_HOSTNAME does not resolve to $keycloak_service_ip from the Vault pod.
Add a cluster DNS override or restart Vault with a hostAlias before OIDC login.
EOF
  exit 1
fi

kubectl -n "$KEYCLOAK_NAMESPACE" get secret keycloak-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d \
  | kubectl -n "$VAULT_NAMESPACE" exec -i "$VAULT_POD" -- sh -c 'cat >/tmp/keycloak-tls.crt'

vault_exec() {
  kubectl -n "$VAULT_NAMESPACE" exec "$VAULT_POD" -- \
    env VAULT_ADDR="$VAULT_EXEC_ADDR" VAULT_TOKEN="$VAULT_TOKEN" vault "$@"
}

if ! vault_exec auth list | grep -q '^oidc/'; then
  vault_exec auth enable oidc
fi

kubectl -n "$VAULT_NAMESPACE" exec -i "$VAULT_POD" -- \
  env VAULT_ADDR="$VAULT_EXEC_ADDR" VAULT_TOKEN="$VAULT_TOKEN" \
  vault policy write "$VAULT_OIDC_POLICY" - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

vault_exec write auth/oidc/config \
  oidc_discovery_url="$issuer_url" \
  oidc_discovery_ca_pem=@/tmp/keycloak-tls.crt \
  oidc_client_id="$KEYCLOAK_OIDC_CLIENT_ID" \
  oidc_client_secret="$KEYCLOAK_OIDC_CLIENT_SECRET" \
  default_role="$VAULT_OIDC_ROLE"

vault_exec write "auth/oidc/role/$VAULT_OIDC_ROLE" \
  role_type=oidc \
  user_claim=preferred_username \
  bound_audiences="$KEYCLOAK_OIDC_CLIENT_ID" \
  allowed_redirect_uris="$vault_ui_redirect_127" \
  allowed_redirect_uris="$vault_ui_redirect_localhost" \
  allowed_redirect_uris="$vault_cli_redirect" \
  oidc_scopes=openid,profile,email \
  token_policies="$VAULT_OIDC_POLICY"

cat <<EOF
Vault OIDC auth is configured.

Vault UI:
  $VAULT_PUBLIC_ADDR/ui/vault/auth?with=oidc

CLI:
  VAULT_ADDR=$VAULT_PUBLIC_ADDR vault login -method=oidc role=$VAULT_OIDC_ROLE
EOF
