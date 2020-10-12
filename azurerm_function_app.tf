resource "random_id" "fn_suffix" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.spoke.name
    index          = var.instance
  }
  byte_length = 4
}


locals {
  fn = format("%sfn", local.name)
  fn_name = format("%sfn%s", local.name,random_id.fn_suffix.hex)
}


module "function_app_storage" {
  source              = "../module_storage"
  name                = local.fn
  hub_name            = local.hub_name
  resource_group_name = local.resource_group_name
  location            = var.location
  is_hns_enabled      = true
  log_retention_days  = var.log_retention_days
}


resource "azurerm_app_service_plan" "spoke" {
  name                = local.fn_name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name

  sku {
    tier = "Premium"
    size = "S1"
  }
}


resource "azurerm_subnet" "funtion" {
  name                 = local.fn_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_vnet_cidr, 8, 6)]
}

resource "azurerm_function_app" "example" {
  name                       = local.fn_name
  location                   = azurerm_resource_group.spoke.location
  resource_group_name        = azurerm_resource_group.spoke.name
  app_service_plan_id        = azurerm_app_service_plan.spoke.id
  storage_account_name       = module.function_app_storage.name
  storage_account_access_key = module.function_app_storage.primary_access_key
}