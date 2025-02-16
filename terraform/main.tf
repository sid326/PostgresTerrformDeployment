provider "azurerm" {
  features {}
}

variable "prefix" {
  default = "pg-cluster"
}

variable "location" {
  default = "East US"
}

variable "vm_size" {
  default = "Standard_D2s_v3"
}

variable "admin_user" {
  default = "azureuser"
}

variable "admin_password" {
  default = "YourStrongPassword123!"
}

resource "azurerm_resource_group" "pg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "pg_vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "pg_subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.pg.name
  virtual_network_name = azurerm_virtual_network.pg_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "pg_nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location

  security_rule {
    name                       = "AllowPostgreSQL"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowEtcd"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2379-2380"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "pg_nic" {
  count               = 3
  name                = "${var.prefix}-nic-${count.index}"
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "pg_vm" {
  count               = 3
  name                = "${var.prefix}-vm-${count.index}"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location
  size                = var.vm_size
  admin_username      = var.admin_user
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.pg_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(file("cloud-init.sh"))
}

resource "azurerm_public_ip" "haproxy_ip" {
  name                = "${var.prefix}-haproxy-ip"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location
  allocation_method   = "Static"
}

resource "azurerm_lb" "haproxy" {
  name                = "${var.prefix}-lb"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIP"
    public_ip_address_id = azurerm_public_ip.haproxy_ip.id
  }
}
