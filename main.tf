terraform {
  required_providers {
    databricks = {
      source  = "databrickslabs/databricks"
      version = ">= 0.2.7"
    }
  }
}


provider "azurerm" {
  version                    = "=2.31.1"
  skip_provider_registration = true
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

provider "local" {}

locals {
  name                                 = format("%s%s%03d", var.prefix, var.suffix, var.instance)
  hub_name                             = format("%shub%03d", var.prefix, var.instance)
  hub_resource_group_name              = format("%s_rg", local.hub_name)
  hub_vnet_name                        = format("vnet%s", local.hub_name)
  azurerm_log_analytics_workspace_name = format("%s-oms", local.hub_name)
}

data "azurerm_client_config" "current" {}


data "azurerm_resource_group" "azurerm_log_analytics_resource_group" {
  name = local.hub_resource_group_name
}

data "azurerm_log_analytics_workspace" "oms" {
  name                = local.azurerm_log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.azurerm_log_analytics_resource_group.name
}