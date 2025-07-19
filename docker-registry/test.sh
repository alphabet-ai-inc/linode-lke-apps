#!/bin/bash
set -e

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Aborting."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required but not installed. Aborting."; exit 1; }
command -v nslookup >/dev/null 2>&1 || { echo "nslookup is required but not installed. Aborting."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting."; exit 1; }

# Set directories
TERRAFORM_DIR="terraform"
OUTPUTS_FILE="$TERRAFORM_DIR/outputs.json"
KUBECONFIG_FILE="$TERRAFORM_DIR/kubeconfig.yaml"

# Check required files
if [ ! -f "$OUTPUTS_FILE" ]; then
  echo "Error: $OUTPUTS_FILE not found. Run 'terraform output -json > $OUTPUTS_FILE' in $TERRAFORM_DIR first."
  exit 1
fi
if [ ! -f "$KUBECONFIG_FILE" ]; then
  echo "Error: $KUBECONFIG_FILE not found."
  exit 1
fi

# Read variables from terraform output
REGISTRY_DOMAIN=$(jq -r '.registry_domain.value' "$OUTPUTS_FILE")
REGISTRY_USERNAME=$(jq -r '.registry_username.value' "$OUTPUTS_FILE")
REGISTRY_PASSWORD=$(jq -r '.registry_password.value' "$OUTPUTS_FILE")
INGRESS_IP=$(jq -r '.ingress_ip.value' "$OUTPUTS_FILE")
REGISTRY_NAMESPACE=$(jq -r '.registry_namespace.value' "$OUTPUTS_FILE")

if [ -z "$REGISTRY_DOMAIN" ] || [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_PASSWORD" ] || [ -z "$INGRESS_IP" ] || [ -z "$REGISTRY_NAMESPACE" ]; then
  echo "Error: Could not parse registry_domain, registry_username, registry_password, ingress_ip, or registry_namespace from $OUTPUTS_FILE"
  exit 1
fi

# Set KUBECONFIG
export KUBECONFIG="$KUBECONFIG_FILE"

# Check Docker Registry service
if ! kubectl get svc -n "$REGISTRY_NAMESPACE" docker-registry >/dev/null 2>&1; then
  echo "Error: Docker Registry service not found in namespace $REGISTRY_NAMESPACE"
  exit 1
fi

# Clear Docker auth cache
rm -f ~/.docker/config.json

# Check DNS with retries
MAX_DNS_ATTEMPTS=5
DNS_ATTEMPT=1
until nslookup "$REGISTRY_DOMAIN" | grep -q "$INGRESS_IP"; do
  echo "Waiting for DNS to propagate (attempt $DNS_ATTEMPT/$MAX_DNS_ATTEMPTS)..."
  sleep 5
  ((DNS_ATTEMPT++))
  if [ $DNS_ATTEMPT -gt $MAX_DNS_ATTEMPTS ]; then
    echo "Error: DNS for $REGISTRY_DOMAIN does not resolve to $INGRESS_IP"
    exit 1
  fi
done

# Check certificate
echo "Checking certificate for $REGISTRY_DOMAIN..."
CERT_OUTPUT=$(echo | openssl s_client -connect "$REGISTRY_DOMAIN:443" -servername "$REGISTRY_DOMAIN" -showcerts 2>/dev/null | openssl x509 -noout -issuer -subject -dates)
if [ -z "$CERT_OUTPUT" ]; then
  echo "Error: Failed to retrieve certificate from $REGISTRY_DOMAIN:443"
  exit 1
fi
echo "$CERT_OUTPUT"
if ! echo "$CERT_OUTPUT" | grep -q "issuer=.*Let's Encrypt"; then
  echo "Error: Certificate for $REGISTRY_DOMAIN is not from Let's Encrypt production"
  exit 1
fi

# Use domain for registry
REGISTRY_URL="https://$REGISTRY_DOMAIN"

# Check login (single attempt)
echo "Attempting docker login to $REGISTRY_URL..."
if ! docker login --username "$REGISTRY_USERNAME" --password-stdin <<< "$REGISTRY_PASSWORD" "$REGISTRY_URL" 2>&1; then
  echo "Failed to login to registry on first attempt"
  exit 1
fi

# Test push/pull
docker pull alpine:latest
docker tag alpine:latest "$REGISTRY_URL/test-image:latest"
docker push "$REGISTRY_URL/test-image:latest"
docker pull "$REGISTRY_URL/test-image:latest"
docker rmi "$REGISTRY_URL/test-image:latest"

echo "Registry test passed!"