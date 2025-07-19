output "registry_namespace" {
  description = "namespace of Docker Registry"
  value       = var.registry_namespace
}

output "registry_domain" {
  description = "Domain for Docker Registry"
  value       = local.registry_domain
}

output "registry_url" {
  description = "URL for Docker Registry"
  value       = "https://${local.registry_domain}"
}

output "registry_username" {
  description = "Username for Docker Registry"
  value       = var.registry_username
}

output "registry_password" {
  description = "Password for Docker Registry"
  value       = random_password.registry_password.result
  sensitive   = true
}

output "ingress_ip" {
  description = "IP address of nginx-ingress"
  value       = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip
}

output "email" {
  value = var.email
}
