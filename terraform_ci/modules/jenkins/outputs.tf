output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "jenkins_url" {
  value = "http://${azurerm_public_ip.public_ip.ip_address}:8080"
}

output "harbor_url" {
  value = "http://${azurerm_public_ip.public_ip.ip_address}"
}

output "harbor_registry" {
  value = "${azurerm_public_ip.public_ip.ip_address}:5000"
}