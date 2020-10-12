
locals {
  storage_name = format("%sraw", local.name)
  container    = "raw"
}

module "module_storage" {
  source              = "../module_storage"
  name                = local.storage_name
  hub_name            = local.hub_name
  resource_group_name = local.resource_group_name
  location            = var.location
  is_hns_enabled      = true
  log_retention_days  = var.log_retention_days
}

resource "azurerm_storage_container" "container" {
  name                  = local.container
  storage_account_name  = local.storage_name
  container_access_type = "private"
}