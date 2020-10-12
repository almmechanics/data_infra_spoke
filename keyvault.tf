locals {
  keyvault_name = format("%skv", local.name)
}

resource "azurerm_key_vault" "keyvault" {
  name                        = local.keyvault_name
  location                    = azurerm_resource_group.spoke.location
  resource_group_name         = azurerm_resource_group.spoke.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "get", "list"
    ]

  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}


data "azurerm_monitor_diagnostic_categories" "kv" {
  resource_id = azurerm_key_vault.keyvault.id
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = local.keyvault_name
  target_resource_id         = azurerm_key_vault.keyvault.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.oms.id


  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.kv.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = var.log_retention_days
      }
    }
  }

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.kv.metrics

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = var.log_retention_days
      }
    }
  }
}
