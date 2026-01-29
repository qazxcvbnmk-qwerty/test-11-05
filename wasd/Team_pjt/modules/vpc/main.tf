resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.pjt_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.key
  availability_zone = each.value
}

resource "aws_eip" "nat" {}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.this]
}

# 1. S3 게이트웨이 엔드포인트 생성
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  
  # service_type 대신 vpc_endpoint_type 사용
  vpc_endpoint_type = "Gateway" 

  tags = { Name = "s3-gateway-endpoint" }
}

# 1. 엔드포인트용 보안 그룹 (추가 필요)
resource "aws_security_group" "endpoint_sg" {
  name        = "${var.pjt_name}-endpoint-sg"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # VPC 내부 통신만 허용
  }
}

# 2. CloudWatch Logs 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id # main -> this로 수정
  service_name        = "com.amazonaws.ap-northeast-2.logs"
  vpc_endpoint_type   = "Interface"
  
  # for_each 서브넷 참조 수정 (첫 번째 프라이빗 서브넷 선택)
  subnet_ids          = [values(aws_subnet.private)[0].id] 
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
}

# 3. SNS 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.this.id # main -> this로 수정
  service_name        = "com.amazonaws.ap-northeast-2.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [values(aws_subnet.private)[0].id]
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
}

