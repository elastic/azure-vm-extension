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
    condition     = length(var.prefix) > 10
    error_message = "The prefix value size must shorter than 10 chars."
  }
}
