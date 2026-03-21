variable "location" {
  default = "Southeast Asia"
}

variable "vm_size" {
  default = "Standard_B2s"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "Your SSH public key"
}