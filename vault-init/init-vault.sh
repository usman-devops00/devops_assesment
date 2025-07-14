#!/bin/bash

set -e

echo "Waiting for Vault to be ready..."
until vault status; do
  echo "Vault is unavailable - sleeping"
  sleep 2
done

echo "Vault is ready! Initializing..."

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
vault secrets enable -path=secret kv-v2 || echo "KV v2 already enabled"

# Store database credentials in Vault
echo "Storing database credentials..."
vault kv put secret/database \
  username="postgres" \
  password="changeme"

# Enable AppRole auth method
echo "Enabling AppRole authentication..."
vault auth enable approle || echo "AppRole already enabled"

# Create policy for backend service
echo "Creating backend service policy..."
vault policy write backend-policy - <<EOF
path "secret/data/database" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

# Create AppRole for backend service
echo "Creating AppRole for backend service..."
vault write auth/approle/role/backend \
  token_policies="backend-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  bind_secret_id=true

# Get role-id and secret-id
echo "Getting AppRole credentials..."
ROLE_ID=$(vault read -field=role_id auth/approle/role/backend/role-id)
SECRET_ID=$(vault write -field=secret_id -f auth/approle/role/backend/secret-id)

echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"

# Test authentication
echo "Testing AppRole authentication..."
APPROLE_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$ROLE_ID" \
  secret_id="$SECRET_ID")

echo "AppRole token: $APPROLE_TOKEN"

# Test secret retrieval
echo "Testing secret retrieval..."
VAULT_TOKEN="$APPROLE_TOKEN" vault kv get secret/database

echo "Vault initialization completed successfully!"

# Store credentials for later use
mkdir -p /vault/init/output
echo "$ROLE_ID" > /vault/init/output/role-id
echo "$SECRET_ID" > /vault/init/output/secret-id

echo "AppRole credentials saved to /vault/init/output/"