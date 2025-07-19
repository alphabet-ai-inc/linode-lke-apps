## Before apply or destroy

```bash
export AWS_REQUEST_CHECKSUM_CALCULATION=when_required
export AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

# Deploying Docker Registry

This project sets up Docker Registry in a Kubernetes cluster.

## Prerequisites

1. `terraform` installed (~> 1.12).
2. `kubectl` installed.
3. Linode API-токен in `~/.linode_token` file.
4. File `kubeconfig.yaml` from project `infrastructure/` (or access to remote state в S3).
5. Access to Linode DNS for dimain configured in `var.main_domain`.

## Installation

1. **Initializing and Applying Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
2. **Get outputs.json**

```bash
terraform output -json > outputs.json
```

3. **Copy kubeconfig.yaml to ~/.kube/config (optional)**

```bash
cp kubeconfig.yaml ~/.kube/config
```

4. **Check domain**

```bash
dig +short registry2.aztech-ai.com
```

5. **Create certificate**
   ./apply-manifests.sh

6. **Make sure the certificate is ready**

```bash
export KUBECONFIG=<path>/kubeconfig.yaml

kubectl get certificate -n docker-registry registry-tls-letsencrypt -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

kubectl describe certificate -n docker-registry registry-tls-letsencrypt
```

7. **Checking the certificate from the server**

```bash
echo | openssl s_client -connect registry2.aztech-ai.com:443 -servername registry2.aztech-ai.com 2>/dev/null | openssl x509 -noout -issuer -subject -dates

```

8. **Run test**

```bash
./test.sh
```

#### Useful commands

**Get password from terraform outputs**

```bash
terraform output -raw registry_password
```

#### Login to docker registry

```bash
docker login -u admin -p <password> <docker_registry_url>
```

#### Get kubeconfig.yaml from remote state

```bash
terraform output -raw kubeconfig_raw > test.yaml
```

#### Get kubeconfig.yaml from vault

```bash
export VAULT_ADDR=$(cat tmp/.vault_addr)
export VAULT_TOKEN=$(cat tmp/.vault_token)
vault kv get -field=kubeconfig secret/lke/kubeconfig > kubeconfig.yaml
```

- `lke` in vault path must coincide with `var.cluster_name` of `linode-lke` project.
