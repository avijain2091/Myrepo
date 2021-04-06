# Configure the Microsoft Azure Provider
provider "azurerm" {
    version = "~>2.0"
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "myResourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create public subnet
resource "azurerm_subnet" "public_subnet" {
    name                 = "myPublicSubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

#Create private subnet
resource "azurerm_subnet" "private_subnet" {
    name                 = "myPrivateSubnet"
    resource_group_name  = azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule for public subnet
resource "azurerm_network_security_group" "mypublicterraformnsg" {
    name                = "mypublicNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule for private subnet
resource "azurerm_network_security_group" "myprivateterraformnsg" {
    name                = "myprivateNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myterraformgroup.name

	#Allow SSH traffic in from public subnet to private subnet 
    security_rule {
        name                       = "Allow-SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "10.0.1.0/24"
        destination_address_prefix = "*"
    }
	
	# Block all outbound traffic from private subnet to Internet
	security_rule {
        name                       = "Deny-All"
        priority                   = 2000
        direction                  = "Outbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface for public subnet
resource "azurerm_network_interface" "mypublicterraformnic" {
    name                      = "mypublicNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "mypublicNicConfiguration"
        subnet_id                     = azurerm_subnet.myPublicSubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface for private subnet
resource "azurerm_network_interface" "myprivateterraformnic" {
    name                      = "myprivateNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myprivateNicConfiguration"
        subnet_id                     = azurerm_subnet.myPrivateSubnet.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        environment = "Terraform Demo"
    }
}


# Connect security group to the public network interface
resource "azurerm_network_interface_security_group_association" "public assoc" {
    network_interface_id      = azurerm_network_interface.mypublicterraformnic.id
    network_security_group_id = azurerm_network_security_group.mypublicterraformnsg.id
}

# Connect security group to the private network interface
resource "azurerm_network_interface_security_group_association" "private assoc" {
    network_interface_id      = azurerm_network_interface.myprivateterraformnic.id
    network_security_group_id = azurerm_network_security_group.myprivateterraformnsg.id
}



# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.myterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create linux virtual machine
resource "azurerm_linux_virtual_machine" "myterraformlinuxvm" {
    name                  = "mylinuxVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myprivateterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "mylinuxvm"
    admin_username = "azureuser1"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser1"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create windows virtual machine
resource "azurerm_windows_virtual_machine" "myterraformwindowsvm" {
    name                  = "mywindowsVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.mypublicterraformnic.id]
    size                  = "Standard_F2"

    os_disk {
        name              = "myDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2016-Datacenter"
        version   = "latest"
    }

    computer_name  = "mywindowsvm"
    admin_username = "azureuser2"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser2"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}