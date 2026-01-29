variable "vpc_id" {
  type = string
}

variable "igw_id" {
  type = string
}

variable "nat_gw_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}
