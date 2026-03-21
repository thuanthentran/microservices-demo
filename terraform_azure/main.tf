module "rg" {
  source              = "./modules/resource_group"
  resource_group_name = var.resource_group_name
  location            = var.location
}

module "networks" {
  source               = "./modules/networks"
  resource_group_name  = module.rg.resource_group_name
  location             = var.location
  virtual_network_name = "aks-vnet"
}

module "acr" {
  source   = "./modules/acr"
  name     = var.acr_name
  rg_name  = module.rg.resource_group_name
  location = var.location
}

module "aks" {
  source           = "./modules/aks"
  aks_cluster_name = var.aks_name
  rg_name          = module.rg.resource_group_name
  location         = var.location
  dns_prefix       = "microservices"
  subnet_id        = module.networks.subnet_id
  node_count       = 2
  vm_size          = "Standard_DS2_v2"
}