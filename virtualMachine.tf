# Creating Ansible Infrastructure On Azure Cloud Using Terraform


# Creating Resource Group
resource "azurerm_resource_group" "resourceGroup" {
  name     = var.resourceGroup["Name"]
  location = var.location
  tags = {
    ENV = var.resourceGroup["ENV"]
    Auther = var.resourceGroup["Auther"]
  }
}

# Creating Virtual Network on Azure
resource "azurerm_virtual_network" "virtualNetwork" {
  name                = var.virtualNetwork["Name"]
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
  tags = {
    ENV = var.virtualNetwork["ENV"]
    Auther = var.virtualNetwork["Auther"]
  }
}

# Creating Subnet in above vNet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet["Name"]
  resource_group_name  = azurerm_resource_group.resourceGroup.name
  virtual_network_name = azurerm_virtual_network.virtualNetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Creating a Public IP
resource "azurerm_public_ip" "publicIP" {
  name                = var.publicIP["Name"]
  resource_group_name = azurerm_resource_group.resourceGroup.name
  location            = azurerm_resource_group.resourceGroup.location
  allocation_method   = "Static"
  tags = {
    ENV = var.publicIP["ENV"]
    Auther = var.publicIP["Auther"]
  }
}

# Create a security Group that allow all inbound trafic
resource "azurerm_network_security_group" "securityGroup" {
  name                = var.securityGroup["Name"]
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  security_rule {
    name                       = var.securityRule
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    ENV = var.securityGroup["ENV"]
    Auther = var.securityGroup["Auther"]
  }
}

# Create a Network Interface
resource "azurerm_network_interface" "networkInterface" {
  name                = var.networkInterface["Name"]
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name

  ip_configuration {
    name                          = var.ipConfiguration
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicIP.id
  }

  tags = {
    ENV = var.networkInterface["ENV"]
    Auther = var.networkInterface["Auther"]
  }
}

# Associate the neteeork interface with the security group
resource "azurerm_network_interface_security_group_association" "networkInterfaceSGAssociation" {
  network_interface_id      = azurerm_network_interface.networkInterface.id
  network_security_group_id = azurerm_network_security_group.securityGroup.id
}

# Generate a random number that will be the name of storage account
# as the name should be unique for storage account
resource "random_id" "randomID" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.resourceGroup.name
  }

  byte_length = 8
}

# creating storage account
resource "azurerm_storage_account" "storageAccount" {
  name                     = "${random_id.randomID.hex}"
  resource_group_name      = azurerm_resource_group.resourceGroup.name
  location                 = azurerm_resource_group.resourceGroup.location
  account_tier             = var.storageAccount["Account_Tier"]
  account_replication_type = var.storageAccount["Account_Replication_Type"]

  tags = {
    ENV = var.storageAccount["ENV"]
    Auther = var.storageAccount["Auther"]
  }
}

# Creating a Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "virtualMachine" {
  name                = var.virtualMachine["Name"]
  resource_group_name = azurerm_resource_group.resourceGroup.name
  location            = azurerm_resource_group.resourceGroup.location
  size                = "Standard_D2as_v4"
  network_interface_ids = [
    azurerm_network_interface.networkInterface.id,
  ]

  os_disk {
    name                 = var.virtualMachine["Name"]
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.virtualMachine["imagePublisher"]
    offer     = var.virtualMachine["imageOffer"]
    sku       = "8.2"
    version   = "latest"
  }

  admin_username                  = var.virtualMachine["adminUsername"]
  admin_password                  = var.virtualMachine["adminPassword"]
  computer_name                   = var.virtualMachine["Name"]
  disable_password_authentication = false

  tags = {
    ENV    = var.virtualMachine["ENV"]
    Auther = var.virtualMachine["Auther"]
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.virtualMachine["adminUsername"]
      password = var.virtualMachine["adminPassword"]
      host     = azurerm_linux_virtual_machine.virtualMachine.public_ip_address
    }

    inline = [
      "sudo yum install wget -y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key",
      "sudo yum upgrade -y",
      "sudo yum install java-11-openjdk-devel -y",
      "sudo yum install jenkins --nobest -y",
      "sudo systemctl daemon-reload",
      "sudo systemctl start jenkins",
      "sudo systemctl enable jenkins",
      # "sudo systemctl status jenkins",
      "sudo firewall-cmd --add-port=8080/tcp --permanent",
      "sudo systemctl restart firewalld"
    ]
  }
}

# Printing the server's IP on the console
output "jenkinsServerPublicIP" {
  value = azurerm_linux_virtual_machine.virtualMachine.public_ip_address
}
