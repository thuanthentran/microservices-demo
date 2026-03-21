resource "azurerm_container_registry" "nt114_acr" {
  name                = var.name
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}