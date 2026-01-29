variable "vpc_id" {}
variable "sg_id" {}
variable "subnets" { type = list(string) }

# ❌ 삭제: 이제 ASG가 관리하므로 개별 타겟 리스트는 필요 없습니다.
# variable "targets" { type = list(string) } 

resource "aws_lb" "this" {
  name               = "tf-alb"
  load_balancer_type = "application"
  security_groups    = [var.sg_id]
  subnets            = var.subnets
}

resource "aws_lb_target_group" "this" {
  name     = "tf-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/status.html"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "tf-alb-tg"
  }
}

# ❌ 블록 전체 삭제: 이 수동 연결 작업은 이제 ASG가 대신 수행합니다.
# resource "aws_lb_target_group_attachment" "this" {
#   count            = length(var.targets)
#   target_group_arn = aws_lb_target_group.this.arn
#   target_id        = var.targets[count.index]
# }

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}