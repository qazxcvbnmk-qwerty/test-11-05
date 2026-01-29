# modules/rds/outputs.tf

output "rds_endpoint" {
  description = "RDS 접속 주소 (DNS)"
  value       = aws_db_instance.mysql.address
}

output "db_name" {
  description = "생성된 DB 이름"
  value       = aws_db_instance.mysql.db_name
}

output "db_user" {
  description = "DB 마스터 사용자명"
  value       = aws_db_instance.mysql.username
}