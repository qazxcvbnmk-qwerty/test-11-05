module "vpc" {
  source = "../../modules/vpc"

  pjt_name = var.pjt_name

  vpc_cidr = var.vpc_cidr

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

module "route_table" {
  source = "../../modules/route_table"

  vpc_id          = module.vpc.vpc_id
  igw_id          = module.vpc.igw_id
  nat_gw_id       = module.vpc.nat_gw_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
}

module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
}

module "ec2" {
  source = "../../modules/ec2"

  # [1] 기존 설정 (서버 스펙, 네트워크)
  ami                   = var.ami
  key_name              = var.key_name
  sg_id                 = module.security.ec2_sg_id
  subnets               = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  instance_profile_name = module.iam.instance_profile_name 
  target_group_arn      = module.alb.target_group_arn
  pjt_name              = var.pjt_name

  # [2] 새로 추가하는 설정 (RDS 연결 & LLM)
  rds_endpoint   = module.rds.rds_endpoint  # 중복 없이 한 번만!
  db_name        = module.rds.db_name       
  db_user        = module.rds.db_user       
  
  # [3] 의존성 설정 (RDS가 다 만들어진 뒤에 EC2를 만들기 위해)
  depends_on = [module.vpc, module.rds]
}

module "alb" {
  source = "../../modules/alb"

  vpc_id   = module.vpc.vpc_id
  sg_id    = module.security.alb_sg_id
  subnets = module.vpc.public_subnets
  #targets = module.ec2.instance_ids
}

module "openvpn" {
  source = "../../modules/openvpn"

  ami              = var.ami
  public_subnet_id = module.vpc.public_subnets[0]
  sg_id            = module.security.openvpn_sg_id
}


module "rds" {
  source = "../../modules/rds"

  vpc_id         = module.vpc.vpc_id
  rds_subnet_ids = slice(module.vpc.private_subnets, 2, 4)
  
  # 👈 참조 이름을 'ec2_web'에서 'ec2'로 변경
  ec2_sg_id      = module.security.ec2_sg_id 
}

module "iam" {
  source = "../../modules/iam"
}

# Public 라우팅 테이블에 S3 엔드포인트 연결
resource "aws_vpc_endpoint_route_table_association" "public_s3" {
  route_table_id  = module.route_table.public_route_table_id # route_table 모듈의 output 참조
  vpc_endpoint_id = module.vpc.s3_endpoint_id
}

# Private 라우팅 테이블에 S3 엔드포인트 연결
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  route_table_id  = module.route_table.private_route_table_id # route_table 모듈의 output 참조
  vpc_endpoint_id = module.vpc.s3_endpoint_id
}
module "alarm" {
  source             = "../../modules/alarm"
  notification_email = "soldesk503@protonmail.com" 
}

# [1] 백업 전용 IAM 역할 (권한 부여)
resource "aws_iam_role" "backup_role" {
  name = "${var.pjt_name}-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

# [2] 백업 보관소 및 1시간 주기 플랜 설정
resource "aws_backup_vault" "hourly_vault" {
  name = "${var.pjt_name}-hourly-vault"
}

resource "aws_backup_plan" "hourly_plan" {
  name = "${var.pjt_name}-hourly-plan"
  rule {
    rule_name         = "1-hour-backup-rule"
    target_vault_name = aws_backup_vault.hourly_vault.name
    schedule          = "cron(0 * * * ? *)" # 매시간 정각 실행
    lifecycle { delete_after = 7 }          # 7일 후 자동 삭제 (비용 관리)
  }
}

# [3] 백업 대상 자동 선택 (태그 기반)
resource "aws_backup_selection" "asg_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "asg-web-backup-selection"
  plan_id      = aws_backup_plan.hourly_plan.id

  # ASG가 생성하는 'Name: ${var.pjt_name}-asg-web' 태그를 가진 모든 인스턴스를 백업합니다.
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Name"
    value = "${var.pjt_name}-asg-web" 
  }
}