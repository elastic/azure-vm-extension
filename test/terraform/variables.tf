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
