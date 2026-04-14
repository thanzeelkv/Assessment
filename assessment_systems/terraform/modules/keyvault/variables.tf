variable "name_prefix"         { type = string }
variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "sku_name" { default = "standard" }
variable "aks_identity_id"     { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
