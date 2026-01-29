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

variable "s3_bucket_name" {
  description = "생성된 S3 버킷의 이름"
  type        = string
}


variable "rds_endpoint" {
  description = "RDS 접속 주소 (main.tf에서 넘겨받음)"
  type        = string
}

variable "db_name" {
  description = "DB 이름"
  type        = string
}

variable "db_user" {
  description = "DB 사용자명"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API Key"
  type        = string
  default     = "" 
}