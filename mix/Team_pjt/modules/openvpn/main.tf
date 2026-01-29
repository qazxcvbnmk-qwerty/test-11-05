resource "aws_instance" "openvpn" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.sg_id]
  associate_public_ip_address = true
  key_name                    = "tf-key"

  tags = {
    Name = "openvpn-ec2"
  }

  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y ca-certificates curl gnupg lsb-release

    curl -fsSL https://as-repository.openvpn.net/as-repo-public.gpg \
      | gpg --dearmor > /etc/apt/trusted.gpg.d/openvpn.gpg

    echo "deb http://as-repository.openvpn.net/as/debian $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/openvpn.list

    apt update -y
    apt install -y openvpn-as

    systemctl enable openvpnas
    systemctl start openvpnas
  EOF
}
# ✅ Elastic IP 생성 및 OpenVPN 인스턴스에 연결
resource "aws_eip" "openvpn_eip" {
  instance = aws_instance.openvpn.id
  domain   = "vpc" # VPC 환경에서 사용함을 명시

  tags = {
    Name = "openvpn-eip"
  }
}

# (선택 사항) EIP 주소를 출력하여 확인하고 싶을 때
output "openvpn_public_ip" {
  value = aws_eip.openvpn_eip.public_ip
}
