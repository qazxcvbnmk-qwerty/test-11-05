variable "ami" {}
variable "subnets" {}
variable "key_name" {}
variable "sg_id" {}

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

# --- RDS 및 LLM 관련 변수 (중복 없이 한 번만 선언) ---

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

variable "s3_bucket_name" {
  description = "생성된 S3 버킷의 이름"
  type        = string
}