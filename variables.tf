variable "location" {
  description = "Common resource group to target"
  type        = string
  default     = "centralus"
}

variable "instance" {
  type    = number
  default = 0
}

variable "prefix" {
  type    = string
  default = "datainfra"
}

variable "suffix" {
  type    = string
  default = "spoke"
}

variable "client_secret" {
  type    = string
  default = "Invalid"
}

variable "client_id" {
  type    = string
  default = "Invalid"

}

variable "subscription_id" {
  type    = string
  default = "Invalid"

}

variable "tenant_id" {
  type    = string
  default = "Invalid"

}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "spoke_vnet_cidr" {
  type        = string
  description = "VPC cidr block. Example: 10.10.0.0/20"
  default     = "10.5.0.0/16"
}