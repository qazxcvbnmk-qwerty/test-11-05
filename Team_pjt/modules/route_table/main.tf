resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  # 기존 for_each 대신 count 사용
  count = length(var.public_subnets)

  subnet_id      = var.public_subnets[count.index]
  route_table_id = aws_route_table.public.id
}
# 1. 라우팅 테이블은 이름과 VPC만 정의
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags   = { Name = "tf-private-rt" }
}

# 2. 경로는 별도 리소스로 관리 (에러가 나지 않도록 테라폼이 새로 생성)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gw_id
}

# 3. 서브넷 연결 (기존 count 방식 유지)
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = var.private_subnets[count.index]
  route_table_id = aws_route_table.private.id
}