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
              # 1. 환경 안정화 및 필수 패키지 설치
              sleep 30
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              # 기본 웹 서버 구동에 필요한 최소 패키지 + AWS CLI + Git 설치
              apt-get install -y nginx php-fpm php-mysql php-gd awscli git unzip

              # 2. 웹 루트 디렉토리 권한 설정 (나중에 업로드하기 편하도록 미리 개방)
              mkdir -p /var/www/html
              chown -R ubuntu:www-data /var/www/html
              chmod -R 775 /var/www/html

              # 3. 임시 헬스체크 및 기본 인덱스 페이지 생성
              # 나중에 깃허브 소스를 받기 전까지 서버가 살아있는지 확인할 용도입니다.
              echo "<h1>Web Server is Ready!</h1><p>Wait for GitHub Deployment...</p>" > /var/www/html/index.html
              echo "OK" > /var/www/html/status.html

              # 4. Nginx 설정 (기본 웹 루트 /var/www/html 유지)
              cat <<NGINX > /etc/nginx/sites-available/default
              server {
                  listen 80;
                  root /var/www/html;
                  index index.php index.html index.htm;
                  server_name _;

                  location / {
                      try_files \$uri \$uri/ =404;
                  }

                  location ~ \.php$ {
                      include snippets/fastcgi-php.conf;
                      fastcgi_pass unix:/run/php/php-fpm.sock;
                  }
              }
              NGINX

              # 5. CloudWatch 에이전트 설치 및 실행
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i -E ./amazon-cloudwatch-agent.deb

              mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
              cat <<JSON > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/nginx/access.log",
                          "log_group_name": "/aws/ec2/${var.pjt_name}-web-log",
                          "log_stream_name": "{instance_id}",
                          "retention_in_days": 7
                        }
                      ]
                    }
                  }
                }
              }
              JSON

              # 6. 서비스 시작
              systemctl restart nginx
              systemctl restart php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm
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

# 2. Auto Scaling Group (기본 설정 유지)
resource "aws_autoscaling_group" "web_asg" {
  name                      = "${var.pjt_name}-asg"
  desired_capacity          = 2 
  max_size                  = 4 
  min_size                  = 2 
  vpc_zone_identifier       = var.subnets

  launch_template {
    id      = aws_launch_template.web_config.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]
  health_check_type = "ELB" 
  health_check_grace_period = 600 

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}