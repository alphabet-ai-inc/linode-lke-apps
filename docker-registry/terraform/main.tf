# Get remote state of linode-lke
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket                      = "infra-config"
    key                         = "states/linode-lke/dev/tfstate"
    region                      = var.object_storage_cluster_region
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    profile                     = "linode"
    shared_credentials_files    = ["~/.linode_credentials"]
    shared_config_files         = ["~/.linode_config"]
    endpoints = {
      s3 = "https://us-ord-1.linodeobjects.com"
    }
  }
}

data "vault_kv_secret_v2" "kubeconfig" {
  mount = "secret"
  name  = "${var.server_group_name}/kubeconfig"
}

locals {
  kubeconfig      = jsondecode(data.vault_kv_secret_v2.kubeconfig.data_json).kubeconfig
  kubeconfig_yaml = yamldecode(local.kubeconfig)
  registry_domain = "${var.registry_subdomain}.${var.main_domain}"
}

# Generate random password for registry
resource "random_password" "registry_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
}

# Generate htpasswd for registry
resource "htpasswd_password" "registry" {
  password = random_password.registry_password.result
  # salt     = substr(sha256(random_password.registry_password.result), 0, 8)
}




# Secret for Object Storage key
resource "kubernetes_secret" "registry_storage" {
  metadata {
    name      = "registry-storage"
    namespace = var.registry_namespace
  }

  data = {
    accesskey = data.terraform_remote_state.infrastructure.outputs.docker_registry_object_storage_key
    secretkey = data.terraform_remote_state.infrastructure.outputs.docker_registry_object_storage_secret_key
  }
  depends_on = [kubernetes_namespace.docker_registry]
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.7.1"
  namespace        = var.ingress_namespace
  create_namespace = true
  depends_on       = [data.vault_kv_secret_v2.kubeconfig]
}

# Docker Registry
resource "helm_release" "docker_registry" {
  name             = "docker-registry"
  repository       = "https://helm.twun.io"
  chart            = "docker-registry"
  version          = "2.2.2"
  namespace        = var.registry_namespace
  create_namespace = true

  values = [
    yamlencode({
      ingress = {
        enabled = true
        hosts   = [local.registry_domain]
        annotations = {
          "cert-manager.io/issuer"                         = "selfsigned"
          "nginx.ingress.kubernetes.io/proxy-body-size"    = "0"
          "nginx.ingress.kubernetes.io/proxy-read-timeout" = "600"
          "nginx.ingress.kubernetes.io/proxy-send-timeout" = "600"
        }
        tls = [{
          secretName = "registry-tls"
          hosts      = [local.registry_domain]
        }]
      }

      storage = "s3"

      secrets = {
        htpasswd = "${var.registry_username}:${htpasswd_password.registry.bcrypt}"
        s3 = {
          accessKey = data.terraform_remote_state.infrastructure.outputs.docker_registry_object_storage_key
          secretKey = data.terraform_remote_state.infrastructure.outputs.docker_registry_object_storage_secret_key
        }
      }

      s3 = {
        region         = var.object_storage_cluster_region
        regionEndpoint = "${var.object_storage_cluster_region}-1.linodeobjects.com"
        bucket         = data.terraform_remote_state.infrastructure.outputs.docker_registry_bucket
        secure         = true
      }
    })
  ]

  depends_on = [
    helm_release.nginx_ingress,
    kubernetes_namespace.docker_registry,
  ]
}

