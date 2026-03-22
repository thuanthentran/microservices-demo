variable "location" {}
variable "vm_size" {}
variable "admin_username" {}
variable "ssh_public_key" {}

# Harbor Configuration Variables
variable "harbor_hostname" {
  type = string
}

variable "harbor_admin_password" {
  type      = string
  sensitive = true
}

variable "harbor_admin_email" {
  type = string
}

variable "harbor_https_port" {
  type = number
}

variable "harbor_http_port" {
  type = number
}

variable "harbor_ssl_cert_country" {
  type = string
}

variable "harbor_ssl_cert_state" {
  type = string
}

variable "harbor_ssl_cert_city" {
  type = string
}

variable "harbor_ssl_cert_organization" {
  type = string
}