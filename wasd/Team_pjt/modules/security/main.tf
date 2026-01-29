variable "vpc_id" {}

# 1. EC2 보안 그룹 정의 (규칙 블록을 비웁니다)
resource "aws_security_group" "ec2" {
  name   = "ec2-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "ec2-sg" }

  # 👈 이 블록을 추가하세요
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = var.vpc_id
  tags   = { Name = "alb-sg" }

  # 👈 이 블록을 추가하세요
  lifecycle {
    create_before_destroy = true
  }
}
# --- 규칙(Rule) 정의 시작 ---

# EC2: SSH 허용 (기존 인라인에서 밖으로 추출)
resource "aws_security_group_rule" "ec2_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

# EC2: ALB로부터의 HTTP 허용 (기존 그대로 유지)
# ALB가 EC2로 헬스체크를 보낼 때, EC2 입장에서 ALB의 보안그룹을 신뢰하는지 재확인
resource "aws_security_group_rule" "ec2_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id # ALB SG로부터 오는 80포트 허용
  security_group_id        = aws_security_group.ec2.id
}

# ALB: 외부 HTTP 허용
resource "aws_security_group_rule" "alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# 공통: Outbound(Egress) 규칙
resource "aws_security_group_rule" "ec2_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}