module "jenkins" {
  source = "./modules/jenkins"

  location       = var.location
  vm_size        = var.vm_size
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key

  # Harbor Configuration
  harbor_hostname             = var.harbor_hostname
  harbor_admin_password       = var.harbor_admin_password
  harbor_admin_email          = var.harbor_admin_email
  harbor_https_port           = var.harbor_https_port
  harbor_http_port            = var.harbor_http_port
  harbor_ssl_cert_country     = var.harbor_ssl_cert_country
  harbor_ssl_cert_state       = var.harbor_ssl_cert_state
  harbor_ssl_cert_city        = var.harbor_ssl_cert_city
  harbor_ssl_cert_organization = var.harbor_ssl_cert_organization
}