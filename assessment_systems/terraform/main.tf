
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/8"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.241.0.0/24"]
}

module "acr" {
  source = "./modules/acr"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  tags                = local.common_tags
  geo_replications = [ abs() ]
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

module "keyvault" {
  source = "./modules/keyvault"

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = var.key_vault_sku
  aks_identity_id     = module.aks.kubelet_identity_object_id
  tags                = local.common_tags

  depends_on = [module.aks]
}

module "aks" {
  source = "./modules/aks"

  name_prefix              = local.name_prefix
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  kubernetes_version       = var.kubernetes_version
  aks_subnet_id            = azurerm_subnet.aks.id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  acr_id                   = module.acr.acr_id
  system_node_count        = var.system_node_count
  system_node_vm_size      = var.system_node_vm_size
  user_node_min_count      = var.user_node_min_count
  user_node_max_count      = var.user_node_max_count
  user_node_vm_size        = var.user_node_vm_size
  tags                     = local.common_tags

  depends_on = [module.monitoring]
}
