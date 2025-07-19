# Local file kubeconfig
resource "local_file" "kubeconfig" {
  content  = data.terraform_remote_state.infrastructure.outputs.kubeconfig_raw
  filename = "${path.module}/kubeconfig.yaml"
}

# Namespace for Docker Registry
resource "kubernetes_namespace" "docker_registry" {
  metadata {
    name = var.registry_namespace
  }
}

# Secret for authentication Docker Registry
resource "kubernetes_secret" "registry_auth" {
  metadata {
    name      = "regcred"
    namespace = var.registry_namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      "${local.registry_domain}" = {
        username = var.registry_username
        password = random_password.registry_password.result
        email    = var.email
        auth     = base64encode("${var.registry_username}:${random_password.registry_password.result}")
      }
    })
  }
  depends_on = [kubernetes_namespace.docker_registry]
}

# Get nginx-ingress service
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.ingress_namespace
  }
  depends_on = [helm_release.nginx_ingress]
}
