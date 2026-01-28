output "rds_endpoint" {
  description = "RDS 접속 DNS 주소"
  # 주소 뒤에 붙는 포트번호(:3306)를 제거하고 순수 주소만 내보냅니다.
  value = split(":", aws_db_instance.mysql.endpoint)[0]
}