terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.30.0"
    }
  }
}

# Configure the Azure Provider
# This block specifies that Terraform will interact with Azure.
# It's recommended to authenticate via Azure CLI (az login) before running Terraform.
provider "azurerm" {
  features {} # This block is required for the AzureRM provider to enable certain features.
  subscription_id = "0c2f76ff-d26e-45e0-b867-308db5332dbc"
}

# Define variables for customization
# These variables allow you to easily change resource names, locations, and VM details
# without modifying the main resource blocks.
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-mkdemotesting"
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "Japan West" # You can change this to your preferred region
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "mkdemot-vnet"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "mkdemo-subnet"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "mktesting"
}

variable "admin_username" {
  description = "Username for the VM's administrator account"
  type        = string
  default     = "mikay"
}

variable "admin_password" {
  description = "Password for the VM's administrator account"
  type        = string
  sensitive   = true # Mark as sensitive to prevent it from being displayed in logs
}

# Create a Resource Group
# A resource group is a logical container for Azure resources.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Create a Virtual Network
# A virtual network (VNet) is the fundamental building block for your private network in Azure.
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"] # Define the IP address space for the VNet
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Create a Subnet
# Subnets enable you to segment the VNet into one or more non-overlapping subnets.
resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"] # Define the IP address range for the subnet
}

# Create a Public IP Address
# A public IP address allows inbound communication from the internet to Azure resources.
resource "azurerm_public_ip" "main" {
  name                = "${var.vm_name}-public-ip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Dynamic" # Or "Static" if you need a fixed IP
  sku                 = "Basic"   # Or "Standard" for more features
}

# Create a Network Security Group (NSG)
# An NSG contains security rules that allow or deny inbound network traffic to,
# or outbound network traffic from, several types of Azure resources.
resource "azurerm_network_security_group" "main" {
  name                = "${var.vm_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Create a Network Security Group Rule for SSH (Port 22)
# This rule allows inbound SSH traffic to the VM.
resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "SSH"
  priority                    = 100 # Lower numbers have higher priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22" # Port for SSH
  source_address_prefix       = "*"  # Allow SSH from any IP address (for demonstration)
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.main.name
}

# Create a Network Interface (NIC)
# A NIC enables a VM to connect to the internet, Azure, and on-premises resources.
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Associate the NSG with the Network Interface
# This ensures that the security rules defined in the NSG are applied to the NIC.
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Create a Linux Virtual Machine
# This defines the virtual machine itself, including its size, OS image, and authentication.
resource "azurerm_linux_virtual_machine" "main" {
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B2as_v2" # VM size (e.g., Standard_B1s, Standard_DS1_v2)
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false # Set to true if using SSH keys

  network_interface_ids = [
    azurerm_network_interface.main.id,

  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Or "Premium_LRS" for better performance
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Output the Public IP Address of the VM
# Outputs are useful for displaying important information after Terraform applies the configuration.
output "public_ip_address" {
  description = "The public IP address of the Linux Virtual Machine"
  value       = azurerm_public_ip.main.ip_address
}

# Output the SSH command
output "ssh_command" {
  description = "Command to SSH into the VM (replace with your admin username)"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}
