output "virtual_network_name" {
  value = azurerm_virtual_network.nt114_vnet.name
}

output "virtual_network_id" {
  value = azurerm_virtual_network.nt114_vnet.id
}

output "subnet_id" {
  value = azurerm_subnet.aks.id
}