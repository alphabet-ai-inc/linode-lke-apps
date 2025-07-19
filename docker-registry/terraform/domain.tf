# DNS-record for registry
resource "linode_domain_record" "registry" {
  domain_id   = data.linode_domain.main.id
  name        = var.registry_subdomain
  record_type = "A"
  target      = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip
  ttl_sec     = 300
  depends_on  = [helm_release.nginx_ingress]
}

# Get existing domain
data "linode_domain" "main" {
  domain = var.main_domain
}
