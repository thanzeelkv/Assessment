variable "name_prefix"         { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "sku" {
  type    = string
  default = "Standard"
}

variable "geo_replications" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
