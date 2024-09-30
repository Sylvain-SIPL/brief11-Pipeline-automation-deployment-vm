data "azurerm_resource_group" "rg" {
  name = "VM-automate-Syl"
}

###### describe Vnet ###########

resource "azurerm_virtual_network" "vnetsrv" {
  name                = "vnet-server"
  address_space       = ["192.168.28.0/22"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

###### describe Subnet #############

resource "azurerm_subnet" "subnetsrv" {
  name                 = "subnet-server"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnetsrv.name
  address_prefixes     = ["192.168.30.0/24"]
}


######## NSG #################

resource "azurerm_network_security_group" "nsg" {
  name                = "my_NSG"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "80"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

###### Associate subnet with networksecurity group ####### 

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnetsrv.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


####### describe serveurs NIC jenkins ##########

resource "azurerm_public_ip" "pub-jenkins-ip" {
  name                = "publicip-jenkins-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface" "nics-jenkins-srv" {
  name                = "nics-jenkins-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetsrv.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.pub-jenkins-ip.id
    private_ip_address            = "192.168.30.10"
  }
}

####### describe serveurs NIC gitlab ##########

resource "azurerm_public_ip" "pub-gitlab-ip" {
  name                = "publicip-gitlab-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface" "nics-gitlab-srv" {
  name                = "nics-gitlab-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetsrv.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.pub-gitlab-ip.id
    private_ip_address            = "192.168.30.20"
  }
}

####### describe serveurs NIC ansible ##########

resource "azurerm_public_ip" "pub-ansible-ip" {
  name                = "publicip-ansible-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_network_interface" "nics-ansible-srv" {
  name                = "nics-ansible-srv"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnetsrv.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.pub-ansible-ip.id
    private_ip_address            = "192.168.30.30"
  }
}

####### Connect security group to the network interface

resource "azurerm_network_interface_security_group_association" "nic_nsg_jenkins" {
  network_interface_id      = azurerm_network_interface.nics-jenkins-srv.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_gitlab" {
  network_interface_id      = azurerm_network_interface.nics-gitlab-srv.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_ansible" {
  network_interface_id      = azurerm_network_interface.nics-ansible-srv.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}



############ VMS ################################################


# create vm jenkins 

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                  = "vm-jenkins"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nics-jenkins-srv.id]
  size                  = "Standard_DS2_v2"




  os_disk {
    name                 = "vm-jenkins-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = "/subscriptions/ec907711-acd7-4191-9983-9577afbe3ce1/resourceGroups/VM-automate-Syl/providers/Microsoft.Compute/images/jenkin-srv"



  computer_name                   = "vm-jenkins"
  admin_username                  = "adminuser"
  disable_password_authentication = true



  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Sylvain/.ssh/id_rsa.pub")
  }


}




# create vm gitlab

resource "azurerm_linux_virtual_machine" "gitlab" {
  name                  = "vm-gitlab"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nics-gitlab-srv.id]
  size                  = "Standard_DS2_v2"


  os_disk {
    name                 = "vm-gitlab-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = "/subscriptions/ec907711-acd7-4191-9983-9577afbe3ce1/resourceGroups/VM-automate-Syl/providers/Microsoft.Compute/images/gitlab-srv"



  computer_name                   = "vm-gitlab"
  admin_username                  = "adminuser"
  disable_password_authentication = true



  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Sylvain/.ssh/id_rsa.pub")
  }


}

# create vm ansible 

resource "azurerm_linux_virtual_machine" "ansible" {
  name                  = "vm-ansible"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nics-ansible-srv.id]
  size                  = "Standard_DS2_v2"


  os_disk {
    name                 = "vm-ansible-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = "/subscriptions/ec907711-acd7-4191-9983-9577afbe3ce1/resourceGroups/VM-automate-Syl/providers/Microsoft.Compute/images/ansible-srv"


  computer_name                   = "vm-ansible"
  admin_username                  = "adminuser"
  disable_password_authentication = true



  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/Sylvain/.ssh/id_rsa.pub")
  }


}


