provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

variable "prefix" {
  default = "pg-cluster"
}

variable "pathVariable" {
  default = "/var/lib/jenkins/workspace/Postgres Deploy/terraform"
}

variable "location" {
  default = "East US"
}

variable "vm_size" {
  default = "Standard_DS1_v2"
}

variable "admin_user" {
  default = "azureuser"
}

variable "admin_password" {
  default = "YourStrongPassword123!"
}

# Create Resource Group
resource "azurerm_resource_group" "pg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Virtual Network & Subnet
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

# Network Security Group (NSG)
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
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Attach NSG to Subnet
resource "azurerm_subnet_network_security_group_association" "pg_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pg_subnet.id
  network_security_group_id = azurerm_network_security_group.pg_nsg.id
}

# Public IPs for VMs
resource "azurerm_public_ip" "pg_vm_ip" {
  count               = 3
  name                = "${var.prefix}-vm-ip-${count.index}"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interfaces for VMs
resource "azurerm_network_interface" "pg_nic" {
  count               = 3
  name                = "${var.prefix}-nic-${count.index}"
  location            = azurerm_resource_group.pg.location
  resource_group_name = azurerm_resource_group.pg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pg_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pg_vm_ip[count.index].id
  }
}

# PostgreSQL Virtual Machines
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
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # Use cloud-init to install PostgreSQL
  custom_data = base64encode(file("cloud-init.sh"))
}

# Load Balancer - HAProxy for PostgreSQL
resource "azurerm_public_ip" "haproxy_ip" {
  name                = "${var.prefix}-haproxy-ip"
  resource_group_name = azurerm_resource_group.pg.name
  location            = azurerm_resource_group.pg.location
  allocation_method   = "Static"
  sku                 = "Standard"
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

# Backend Pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "pg_pool" {
  loadbalancer_id = azurerm_lb.haproxy.id
  name            = "BackendPool"
}

# Associate VMs with LB
resource "azurerm_network_interface_backend_address_pool_association" "pg_lb_assoc" {
  count                   = 3
  network_interface_id    = azurerm_network_interface.pg_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pg_pool.id
}

# Load Balancer Rule for PostgreSQL
resource "azurerm_lb_rule" "pg_lb_rule" {
  loadbalancer_id                = azurerm_lb.haproxy.id
  name                           = "PostgreSQLLoadBalancerRule"
  protocol                       = "Tcp"
  frontend_port                  = 5432
  backend_port                   = 5432
  frontend_ip_configuration_name = "PublicIP"
  backend_address_pool_ids      = [azurerm_lb_backend_address_pool.pg_pool.id]
}
resource "local_file" "private_ips" {
  content  = join("\n", azurerm_network_interface.pg_nic[*].private_ip_address)
  filename = "${var.pathVariable}/private_ips.txt"
}
