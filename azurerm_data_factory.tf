# Generate random text for a unique storage account name
resource "random_id" "adf_random" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.spoke.name
    index          = var.instance
  }
  byte_length = 8
}

locals {
  azurerm_data_factory_name = format("%sadf%s", local.name, random_id.adf_random.hex)
}


resource "azurerm_data_factory" "adf" {
  name                = local.azurerm_data_factory_name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
}

## Diagnostis
data "azurerm_monitor_diagnostic_categories" "adf" {
  resource_id = azurerm_data_factory.adf.id
}

resource "azurerm_monitor_diagnostic_setting" "adf" {
  name                       = local.azurerm_data_factory_name
  target_resource_id         = azurerm_data_factory.adf.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.oms.id


  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.adf.logs

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
    for_each = data.azurerm_monitor_diagnostic_categories.adf.metrics

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