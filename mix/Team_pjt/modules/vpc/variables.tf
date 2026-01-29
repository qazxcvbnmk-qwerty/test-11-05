variable "pjt_name" {}
variable "vpc_cidr" {}

variable "public_subnets" {
  type = map(string)
}

variable "private_subnets" {
  type = map(string)
}
