variable "username" {
  description = "The username for the elastic cloud cluster"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "The password for the elastic cloud cluster user"
  type        = string
  sensitive   = true
}

variable "cloudId" {
  description = "The elastic cloud ID (deployment ID)"
  type        = string
  sensitive   = true
}

variable "prefix" {
  description = "The prefix for the name of the terraform resources"
  type        = string
  sensitive   = true
  default     = "def"
  validation {
    condition     = length(var.prefix) < 11
    error_message = "Maximum length of prefix is 10 characters."
  }
}

variable "name" {
  description = "The name of the terraform resources"
  type        = string
  sensitive   = true
  default     = "az-vm-ext"
  validation {
    condition     = length(var.name) < 16
    error_message = "Maximum length of name is 15 characters."
  }
}

variable "vmName" {
  description = "The virtual machine name"
  type        = string
  sensitive   = true
  default     = "az-vm-ext"
  validation {
    condition     = length(var.vmName) < 16
    error_message = "Maximum length of vmName is 15 characters."
  }
}

variable "isWindows" {
  description = "If true, resources will be a Windows"
  type        = bool
  default     = true
}

variable "isExtension" {
  description = "If true, VM extension is enabled"
  type        = bool
  default     = true
}

variable "publisher" {
  description = "The publisher for source_image_reference"
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "offer" {
  description = "The offer for source_image_reference"
  type        = string
  default     = "WindowsServer"
}

variable "sku" {
  description = "The sku for source_image_reference"
  type        = string
  default     = "2016-Datacenter"
}

variable "debugFile" {
  description = "The file with the debug traces"
  type        = string
  default     = "/tmp/file.log"
}
