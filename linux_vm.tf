variable "vmindex" {
  type    = number
  default = 1
}

variable "vmname" {
  type    = number
  default = 1
}


locals {
  iaas_subnet_name   = format("%siaas", local.name)
  vm_name            = format("%svm%03d%03d", var.prefix, var.vmname, var.vmindex)
  vm_os_disk_name    = format("%s-os", local.vm_name)
  nic_name           = format("%s-nic", local.vm_name)
  nic_ip_config_name = format("%s-ip-configuration", local.vm_name)
  diagnostics_name   = format("diag%s", local.name)
}


module "boot_diags_storage" {
  source              = "../module_storage"
  name                = local.diagnostics_name
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  is_hns_enabled      = false
  log_retention_days  = var.log_retention_days
  hub_name            = local.hub_name

}


resource "azurerm_subnet" "iaas" {
  name                 = local.iaas_subnet_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_vnet_cidr, 8, 3)]
}

# Generate random text for a unique storage account name
resource "random_id" "vm_random" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.spoke.name
    index          = var.instance
  }
  byte_length = 8
}

resource "random_password" "password" {
  length      = 24
  min_upper   = 5
  min_special = 5
  min_numeric = 5
}



resource "azurerm_network_interface" "nic" {
  name                = local.nic_name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name

  ip_configuration {
    name                          = local.nic_ip_config_name
    subnet_id                     = azurerm_subnet.iaas.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_monitor_diagnostic_categories" "nic" {
  resource_id = azurerm_network_interface.nic.id
}

resource "azurerm_monitor_diagnostic_setting" "nic" {
  name                       = local.vm_name
  target_resource_id         = azurerm_network_interface.nic.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.oms.id

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.nic.metrics

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



# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
  name = local.vm_name

  location              = azurerm_resource_group.spoke.location
  resource_group_name   = azurerm_resource_group.spoke.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1ls"

  storage_os_disk {
    name              = local.vm_os_disk_name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_profile {
    computer_name  = local.vm_name
    admin_username = "bastionadmin"
    admin_password = random_password.password.result
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = module.boot_diags_storage.primary_blob_endpoint
  }

}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  virtual_machine_id = azurerm_virtual_machine.vm.id
  location           = azurerm_resource_group.spoke.location
  enabled            = true

  daily_recurrence_time = "1800"
  timezone              = "UTC"

  notification_settings {
    enabled         = true
    time_in_minutes = "30"
    webhook_url     = "https://sample-webhook-url.example.com"
  }
}

output "password" {
  value = [random_password.password.result]
}
