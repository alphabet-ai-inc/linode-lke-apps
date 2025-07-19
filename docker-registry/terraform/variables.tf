variable "env" {
  type    = string
  default = "dev"
}

variable "server_group_name" {
  type    = string
  default = "lke"
}

variable "vault_url" {
  type    = string
  default = "https://vault.sushkovs.ru"
}

variable "main_domain" {
  description = "Main domain for DNS records"
  type        = string
  default     = "aztech-ai.com"
}

variable "registry_subdomain" {
  description = "Domain for Docker Registry"
  type        = string
  default     = "registry2"
}

variable "registry_namespace" {
  description = "Kubernetes namespace for Docker Registry"
  type        = string
  default     = "docker-registry"
}

variable "ingress_namespace" {
  description = "Kubernetes namespace for nginx-ingress"
  type        = string
  default     = "ingress-nginx"
}

variable "registry_username" {
  description = "Username for Docker Registry"
  type        = string
  default     = "admin"
}

variable "email" {
  description = "Email for Let's Encrypt"
  type        = string
  default     = "admin@aztech-ai.com"
}

variable "object_storage_cluster_region" {
  description = "Region for Object Storage"
  type        = string
  default     = "us-ord"
}
