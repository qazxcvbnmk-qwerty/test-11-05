# 기존 변수들 (기존에 있던 ami, subnets, key_name 등은 유지하세요)
variable "ami" {}
variable "subnets" {}
variable "key_name" {}
variable "sg_id" {}

# ✅ 중복을 제거하고 딱 한 번씩만 선언합니다.
variable "instance_profile_name" {
  description = "IAM Instance Profile name for SSM and CloudWatch"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB Target Group for ASG integration"
  type        = string
}

variable "pjt_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "rds_endpoint" {
  type = string
}