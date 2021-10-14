resource "random_id" "random" {
  byte_length = 4
}

resource "azurerm_resource_group" "jmeter_rg" {
  name     = var.RESOURCE_GROUP_NAME
  location = var.LOCATION
}

resource "azurerm_virtual_network" "jmeter_vnet" {
  name                = "${var.PREFIX}vnet"
  location            = azurerm_resource_group.jmeter_rg.location
  resource_group_name = azurerm_resource_group.jmeter_rg.name
  address_space       = ["${var.VNET_ADDRESS_SPACE}"]
}

resource "azurerm_subnet" "jmeter_subnet" {
  name                 = "${var.PREFIX}subnet"
  resource_group_name  = azurerm_resource_group.jmeter_rg.name
  virtual_network_name = azurerm_virtual_network.jmeter_vnet.name
  address_prefix       = var.SUBNET_ADDRESS_PREFIX

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "jmeter_vm_subnet" {
  name                 = "${var.PREFIX}vmsubnet"
  resource_group_name  = azurerm_resource_group.jmeter_rg.name
  virtual_network_name = azurerm_virtual_network.jmeter_vnet.name
  address_prefix       = var.VM_SUBNET_ADDRESS_PREFIX
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_network_profile" "jmeter_net_profile" {
  name                = "${var.PREFIX}netprofile"
  location            = azurerm_resource_group.jmeter_rg.location
  resource_group_name = azurerm_resource_group.jmeter_rg.name

  container_network_interface {
    name = "${var.PREFIX}cnic"

    ip_configuration {
      name      = "${var.PREFIX}ipconfig"
      subnet_id = azurerm_subnet.jmeter_subnet.id
    }
  }
}

resource "azurerm_storage_account" "jmeter_storage" {
  name                = "${var.PREFIX}storage${random_id.random.hex}"
  resource_group_name = azurerm_resource_group.jmeter_rg.name
  location            = azurerm_resource_group.jmeter_rg.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Allow"
    virtual_network_subnet_ids = ["${azurerm_subnet.jmeter_subnet.id}"]
  }
}

resource "azurerm_storage_share" "jmeter_share" {
  name                 = "jmeter"
  storage_account_name = azurerm_storage_account.jmeter_storage.name
  quota                = var.JMETER_STORAGE_QUOTA_GIGABYTES
}

resource "azurerm_network_interface" "jmeter_slave_nic" {
  name                = "${var.PREFIX}-slave-nic${count.index}"
  count               = var.JMETER_SLAVES_COUNT
  location            = azurerm_resource_group.jmeter_rg.location
  resource_group_name = azurerm_resource_group.jmeter_rg.name
  ip_configuration {
    name                          = "${var.PREFIX}ipconfig"
    subnet_id                     = azurerm_subnet.jmeter_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "jmeter_slaves" {
  count                 = var.JMETER_SLAVES_COUNT
  name                  = "${var.PREFIX}-slave-vm${count.index}"
  location              = azurerm_resource_group.jmeter_rg.location
  resource_group_name   = azurerm_resource_group.jmeter_rg.name
  network_interface_ids = ["${element(azurerm_network_interface.jmeter_slave_nic.*.id, count.index)}"]
  vm_size               = var.JMETER_SLAVE_VM_SKU

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  storage_os_disk {
    name              = "myosdisk1${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.PREFIX}-slave${count.index}"
    admin_username = "slaveadmin"
    admin_password = var.JMETER_SLAVE_VM_PASS
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_subscription" "current" {
}

data "azurerm_client_config" "clientconfig" {
}

resource "azurerm_role_assignment" "jmeter_msi_role_assignment" {
  count              = var.JMETER_SLAVES_COUNT
  name               = "${var.JMETER_SLAVE_VM_ROLE_ASSIGNMENT_NAME_PREFIX}${random_id.random.hex}${count.index}"
  scope              = data.azurerm_subscription.current.id
  role_definition_id = "${data.azurerm_subscription.current.id}${data.azurerm_role_definition.contributor.id}"
  principal_id       = azurerm_virtual_machine.jmeter_slaves.*.identity.0.principal_id[count.index]
}

resource "azurerm_virtual_machine_extension" "jmeter_vm_extension" {
  count                = var.JMETER_SLAVES_COUNT
  name                 = "${var.PREFIX}-docker-slave${count.index}"
  virtual_machine_id   = element(azurerm_virtual_machine.jmeter_slaves.*.id, count.index)
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "${base64encode(templatefile("scripts/slaveinit.sh", {
  FILE_RG = "${azurerm_resource_group.jmeter_rg.name}", STOACC_NAME = "${azurerm_storage_account.jmeter_storage.name}", FILESHARE_NAME = "${azurerm_storage_share.jmeter_share.name}"
}))}"
    }
SETTINGS

}

resource "azurerm_container_group" "jmeter_master" {
  name                = "${var.PREFIX}-master"
  location            = azurerm_resource_group.jmeter_rg.location
  resource_group_name = azurerm_resource_group.jmeter_rg.name

  ip_address_type = "private"
  os_type         = "Linux"

  depends_on = [azurerm_virtual_machine_extension.jmeter_vm_extension, azurerm_network_interface.jmeter_slave_nic]

  network_profile_id = azurerm_network_profile.jmeter_net_profile.id

  restart_policy = "Never"

  image_registry_credential {
    server   = var.JMETER_IMAGE_REGISTRY_SERVER
    username = var.JMETER_IMAGE_REGISTRY_USERNAME
    password = var.JMETER_IMAGE_REGISTRY_PASSWORD
  }

  container {
    name   = "jmeter"
    image  = var.JMETER_DOCKER_IMAGE
    cpu    = var.JMETER_MASTER_CPU
    memory = var.JMETER_MASTER_MEMORY

    ports {
      port     = var.JMETER_DOCKER_PORT
      protocol = "TCP"
    }

    volume {
      name                 = "jmeter"
      mount_path           = "/jmeter"
      read_only            = false
      storage_account_name = azurerm_storage_account.jmeter_storage.name
      storage_account_key  = azurerm_storage_account.jmeter_storage.primary_access_key
      share_name           = azurerm_storage_share.jmeter_share.name
    }

    commands = [
      "/bin/sh",
      "-c",
      "cd /jmeter; /entrypoint.sh -n -J server.rmi.ssl.disable=true -t ${var.JMETER_JMX_FILE} -J target_hostname=${var.TARGET_HOSTNAME} -l ${var.JMETER_RESULTS_FILE} -e -o ${join(",", "${azurerm_network_interface.jmeter_slave_nic.*.private_ip_address}")}",
    ]
  }
}
