
data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.name_prefix}-${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  soft_delete_retention_days  = 7
  purge_protection_enabled    = false  

  enable_rbac_authorization = true

  network_acls {
    default_action = "Allow" 
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "kv_aks_read" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.aks_identity_id
}

resource "azurerm_key_vault_secret" "app_db_password" {
  name         = "app-db-password"
  value        = "REPLACE_ME_BEFORE_APPLY"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  tags = var.tags

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "app_api_key" {
  name         = "app-api-key"
  value        = "REPLACE_ME_BEFORE_APPLY"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  tags = var.tags

  depends_on = [azurerm_role_assignment.kv_admin]
}
