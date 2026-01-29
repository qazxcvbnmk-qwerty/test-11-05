pjt_name = "terraform"

vpc_cidr = "172.16.0.0/16"

public_subnets = {
  "172.16.1.0/24" = "ap-northeast-2a"
  "172.16.2.0/24" = "ap-northeast-2c"
}

private_subnets = {
  "172.16.3.0/24" = "ap-northeast-2a" # EC2용
  "172.16.4.0/24" = "ap-northeast-2c" # EC2용
  "172.16.5.0/24" = "ap-northeast-2a" # RDS용 (추가)
  "172.16.6.0/24" = "ap-northeast-2c" # RDS용 (추가)
}

ami = "ami-0c9c942bd7bf113a2" # Amazon Linux 2023 (서울)

key_name = "tf-key"  # 👈 AWS에 미리 만든 KeyPair 이름
