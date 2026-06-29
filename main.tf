terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm" # Specifies the source for the Azure provider plugin.
      version = "~>2.0"            # Ensures the Azure provider plugin version is 2.x.x (compatible with this configuration).
    }
  }
}

provider "azurerm" {
  features {}                        # Required for newer versions of the Azure provider, initializes provider features.

  subscription_id   = "294fc8e5-3491-4a9e-8db3-78b02fd829e3" # Your Azure subscription ID.
  tenant_id         = "91ea826a-20e0-408f-995f-122365df91f9" # Your Azure Active Directory (AAD) tenant ID.
  client_id         = "fe7658fa-b040-43a5-b379-61ceb90ca8cf" # The client ID of the service principal for authentication.
  client_secret     = "NhC8Q~rqlvxAsfymC6royDxKeyMZn4TaNNivIcDd" # The client secret of the service principal.
}

resource "azurerm_resource_group" "rg" {
  name     = "ONDC_RG"   # Resource group name
  location = "West US 2"           # Azure region
}

resource "azurerm_network_security_group" "nsg" {
  name                = "ondc-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow HTTP (Port 80)
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow RDP (Port 3389)
  security_rule {
    name                       = "Allow-RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Project = "ONDC"
    }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "my-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method   = "Dynamic"
  
  tags = {
    Project = "ONDC"
  }
}
resource "azurerm_virtual_network" "vnet" {
  name                = "ONDCvnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "public" {
  name                 = "PublicSubnet_ondc"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

//resource "azurerm_subnet" "backend" {
 // name                 = "backendsubnet_ondc"
  //resource_group_name  = azurerm_resource_group.rg.name
 // virtual_network_name = azurerm_virtual_network.vnet.name
  //address_prefixes     = ["10.1.1.0/24"]
//}

resource "azurerm_network_interface" "nic" {
  name                = "ondcnic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ondcpublicip"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id    
    primary                       = true
  }
}

resource "azurerm_network_interface_security_group_association" "ondcvm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm1" {
  name                            = "ondcvm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_DS1_v2"
  admin_username                  = "vmadmin"
  admin_password                  = "Password@123"
    network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = {
    Project = "ONDC"
  }
}

resource "azurerm_virtual_machine_extension" "iis_install" {
  name                 = "install-iis"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  settings = <<SETTINGS
  {
    "commandToExecute": "powershell Install-WindowsFeature Web-Server"
  }
  SETTINGS
}