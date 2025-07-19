#!/bin/bash
set -e

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting."; exit 1; }
command -v nslookup >/dev/null 2>&1 || { echo "nslookup is required but not installed. Aborting."; exit 1; }

# Set directories
TERRAFORM_DIR="terraform"
MANIFESTS_DIR="manifests"
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
INGRESS_IP=$(jq -r '.ingress_ip.value' "$OUTPUTS_FILE")
REGISTRY_NAMESPACE=$(jq -r '.registry_namespace.value' "$OUTPUTS_FILE")
EMAIL=$(jq -r '.email.value // "admin@aztech-ai.com"' "$OUTPUTS_FILE")

if [ -z "$REGISTRY_DOMAIN" ] || [ -z "$INGRESS_IP" ] || [ -z "$REGISTRY_NAMESPACE" ] || [ -z "$EMAIL" ]; then
  echo "Error: Could not parse registry_domain, ingress_ip, registry_namespace, or email from $OUTPUTS_FILE"
  exit 1
fi

# Set KUBECONFIG
export KUBECONFIG="$KUBECONFIG_FILE"

# Check if namespace exists
if ! kubectl get namespace "$REGISTRY_NAMESPACE" >/dev/null 2>&1; then
  echo "Error: Namespace $REGISTRY_NAMESPACE does not exist. Creating it..."
  kubectl create namespace "$REGISTRY_NAMESPACE"
fi

# Check DNS with retries
MAX_DNS_ATTEMPTS=30
DNS_ATTEMPT=1
until nslookup "$REGISTRY_DOMAIN" | grep -q "$INGRESS_IP"; do
  echo "Waiting for DNS to propagate (attempt $DNS_ATTEMPT/$MAX_DNS_ATTEMPTS)..."
  sleep 10
  ((DNS_ATTEMPT++))
  if [ $DNS_ATTEMPT -gt $MAX_DNS_ATTEMPTS ]; then
    echo "DNS propagation failed after $MAX_DNS_ATTEMPTS attempts"
    exit 1
  fi
done

# Apply letsencrypt-issuer.yaml
cat "$MANIFESTS_DIR/letsencrypt-issuer.yaml" | \
  sed "s|\${EMAIL}|$EMAIL|g" | \
  kubectl apply -f -

# Apply letsencrypt-certificate.yaml
cat "$MANIFESTS_DIR/letsencrypt-certificate.yaml" | \
  sed "s|\${REGISTRY_NAMESPACE}|$REGISTRY_NAMESPACE|g" | \
  sed "s|\${REGISTRY_DOMAIN}|$REGISTRY_DOMAIN|g" | \
  kubectl apply -f -

echo "Manifests applied successfully!"