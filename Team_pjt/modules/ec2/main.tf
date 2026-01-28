# 1. Launch Template: 서버의 상세 설정
resource "aws_launch_template" "web_config" {
  name_prefix   = "${var.pjt_name}-web-template-"
  image_id      = var.ami
  instance_type = "t3.micro"
  key_name      = var.key_name
  vpc_security_group_ids = [var.sg_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # 1. 환경 안정화 및 업데이트 방해 금지
              sleep 30
              systemctl stop unattended-upgrades
              systemctl disable unattended-upgrades
              killall apt apt-get 2>/dev/null
              rm -f /var/lib/dpkg/lock*
              dpkg --configure -a

              # 2. WordPress를 위한 필수 패키지 설치 (PHP-FPM 포함)
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y nginx php-fpm php-mysql php-gd php-cli php-curl php-mbstring php-xml php-xmlrpc wget

              # 3. WordPress 다운로드 및 배치
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              cp -r wordpress/* /var/www/html/
              chown -R www-data:www-data /var/www/html/
              chmod -R 755 /var/www/html/

              # 4. WordPress DB 설정 (RDS 엔드포인트 자동 주입)
              cd /var/www/html
              cp wp-config-sample.php wp-config.php
              sed -i "s/database_name_here/app_db/g" wp-config.php
              sed -i "s/username_here/admin/g" wp-config.php
              sed -i "s/password_here/password123!/g" wp-config.php
              sed -i "s/localhost/${var.rds_endpoint}/g" wp-config.php

              # 5. Nginx를 WordPress용으로 설정
              cat <<NGINX > /etc/nginx/sites-available/default
              server {
                  listen 80;
                  root /var/www/html;
                  index index.php index.html index.htm;
                  server_name _;
                  location / {
                      try_files \$uri \$uri/ /index.php?\$args;
                  }
                  location ~ \.php$ {
                      include snippets/fastcgi-php.conf;
                      fastcgi_pass unix:/run/php/php-fpm.sock;
                  }
              }
              NGINX

              # 6. CloudWatch 에이전트 설치 및 실행
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i -E ./amazon-cloudwatch-agent.deb

              # 서비스 재시작 및 헬스체크용 파일 생성
              systemctl restart nginx
              systemctl restart php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm
              echo "WordPress is running" > /var/www/html/status.html

              # CloudWatch Agent 설정 (기존 설정 유지)
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { 
      Name = "${var.pjt_name}-asg-web" 
    }
  }
}

# 2. Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                = "${var.pjt_name}-asg"
  desired_capacity    = 2 
  max_size            = 4 
  min_size            = 2 
  
  vpc_zone_identifier = var.subnets

  launch_template {
    id      = aws_launch_template.web_config.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  health_check_type         = "ELB" 
  # ✅ 유예 기간을 600초(10분)로 넉넉히 주어 설치 완료 시간을 확보합니다.
  health_check_grace_period = 600 

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}