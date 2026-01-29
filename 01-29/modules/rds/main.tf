# 1. RDS 전용 서브넷 그룹 생성 (5.0, 6.0 대역 사용)
resource "aws_db_subnet_group" "rds_group" {
  name       = "rds-private-group"
  subnet_ids = var.rds_subnet_ids # 172.16.5.0/24, 172.16.6.0/24 ID가 들어올 자리

  tags = { Name = "RDS Private Subnet Group" }
}

# 2. RDS 보안 그룹 설정
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow traffic from EC2 to RDS"
  vpc_id      = var.vpc_id

  # EC2 보안 그룹을 가진 리소스만 3306 포트 접근 허용
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id] # EC2의 보안 그룹 ID를 참조
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "RDS-SG" }
}

# 3. RDS 인스턴스 생성
resource "aws_db_instance" "mysql" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = "app_db"
  username               = "admin"
  password               = "password123!"
  
  db_subnet_group_name   = aws_db_subnet_group.rds_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # ✅ 백업 옵션 추가
  backup_retention_period = 7                # 7일 동안 백업 보관 (0이면 백업 비활성화)
  backup_window           = "18:00-19:00"    # UTC 기준 (한국 시간 오전 03:00~04:00)
  copy_tags_to_snapshot   = true             # 스냅샷에 태그 복사
  
  # ✅ 삭제 관련 설정
  skip_final_snapshot     = true            # 삭제할 때 스냅샷을 찍도록 설정 (보안 강화)
  final_snapshot_identifier = "app-db-final-snapshot-${formatdate("YYYYMMDD", timestamp())}"

  tags = { Name = "Main-RDS" }
}

# 변수 정의
variable "vpc_id" {}
variable "rds_subnet_ids" { type = list(string) }
variable "ec2_sg_id" {}