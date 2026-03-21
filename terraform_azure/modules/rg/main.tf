resource "azurerm_resource_group" "nt114_rg" {
  name     = var.resource_group_name
  location = var.location
}