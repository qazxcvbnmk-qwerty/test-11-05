variable "ami" {
  description = "AMI ID for OpenVPN EC2"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID"
  type        = string
}

variable "sg_id" {
  description = "Security Group ID for OpenVPN"
  type        = string
}
