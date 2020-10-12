locals {
  private_databricks_name     = format("%sprivatedatabricks", local.name)
  public_databricks_name      = format("%spublicdatabricks", local.name)
  databricks_nsg_name         = format("%s-databricks-nsg", local.name)
  workspace_name              = format("%sworkspace", local.name)
  managed_resource_group_name = format("%s-managed-rg", azurerm_resource_group.spoke.name)
}

resource "azurerm_subnet" "private_databricks" {
  name                 = local.private_databricks_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_vnet_cidr, 8, 4)]

  delegation {
    name = "databricks-del-private"

    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_subnet" "public_databricks" {
  name                 = local.public_databricks_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_vnet_cidr, 8, 5)]

  delegation {
    name = "databricks-del-public"

    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
    }
  }
}

resource "azurerm_network_security_group" "databricks" {
  name                = local.databricks_nsg_name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
}

data "azurerm_monitor_diagnostic_categories" "databricks_nsg" {
  resource_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_monitor_diagnostic_setting" "databricks_nsg" {
  name                       = local.databricks_nsg_name
  target_resource_id         = azurerm_network_security_group.databricks.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.oms.id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.databricks_nsg.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = var.log_retention_days
      }
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "public_databricks" {
  subnet_id                 = azurerm_subnet.public_databricks.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_subnet_network_security_group_association" "private_databricks" {
  subnet_id                 = azurerm_subnet.private_databricks.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

resource "azurerm_databricks_workspace" "databricks" {
  name                        = local.workspace_name
  resource_group_name         = azurerm_resource_group.spoke.name
  location                    = azurerm_resource_group.spoke.location
  sku                         = "premium"
  managed_resource_group_name = local.managed_resource_group_name
  custom_parameters {
    virtual_network_id  = azurerm_virtual_network.spoke.id
    public_subnet_name  = azurerm_subnet.public_databricks.name
    private_subnet_name = azurerm_subnet.private_databricks.name
  }
}



data "azurerm_monitor_diagnostic_categories" "databricks" {
  resource_id = azurerm_databricks_workspace.databricks.id
}

resource "azurerm_monitor_diagnostic_setting" "databricks" {
  name                       = local.workspace_name
  target_resource_id         = azurerm_databricks_workspace.databricks.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.oms.id


  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.databricks.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = var.log_retention_days
      }
    }
  }
}

provider "databricks" {
  azure_workspace_name  = azurerm_databricks_workspace.databricks.name
  azure_resource_group  = azurerm_databricks_workspace.databricks.resource_group_name
  azure_client_id       = data.azurerm_client_config.current.client_id
  azure_client_secret   = var.client_secret
  azure_tenant_id       = data.azurerm_client_config.current.tenant_id
  azure_subscription_id = data.azurerm_client_config.current.subscription_id
}

resource "databricks_cluster" "my-cluster" {
  spark_version = "6.4.x-scala2.11"
  node_type_id  = "Standard_DS3_v2"
  num_workers   = 1
}

