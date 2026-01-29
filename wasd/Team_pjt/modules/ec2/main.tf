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
              
              # [1] 시스템 안정화 (기존 코드 유지: 잠금 해제 등 안전 장치)
              sleep 30
              systemctl stop unattended-upgrades
              killall apt apt-get 2>/dev/null
              rm -f /var/lib/dpkg/lock*
              dpkg --configure -a

              # [2] 패키지 설치 (통합: PHP 8.1로 버전 고정 + 기존 확장 모듈 모두 포함)
              apt-get update -y
              apt-get install -y nginx git unzip wget mysql-client
              # 🚨 502 에러 방지를 위해 버전을 8.1로 명시하고, 기존에 있던 확장 모듈(curl, gd 등)도 8.1 버전으로 설치합니다.
              apt-get install -y php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml

              # [3] 깃허브 코드 배포 (경로 중첩 방지 적용)
              rm -rf /var/www/html/*
              git clone https://github.com/chuhyunsoo123-droid/chu1.git /tmp/repo
              # Team_pjt 폴더 내용물만 루트로 복사 (404 방지)
              cp -r /tmp/repo/Team_pjt/* /var/www/html/

              # [4] DB 설정 파일 생성 (통합: 자동 주입 + 이중화)
              cat <<PHP > /var/www/html/config_aws.php
              <?php
              \$servername = "${var.rds_endpoint}";
              \$username = "${var.db_user}";
              \$password = "password123!";
              \$dbname = "${var.db_name}";
              ?>
              PHP
              # 🚨 500 에러 방지: 코드가 config.php를 찾을 경우를 대비해 복사
              cp /var/www/html/config_aws.php /var/www/html/config.php

              # [5] 권한 설정 (403 해결의 핵심 - 새 코드 적용)
              # 폴더는 755, 파일은 644로 주어야 보안상 안전하고 Nginx가 읽을 수 있습니다.
              chown -R www-data:www-data /var/www/html
              find /var/www/html -type d -exec chmod 755 {} \;
              find /var/www/html -type f -exec chmod 644 {} \;

              # [6] Nginx 설정 (새 코드 적용: PHP 8.1 소켓 강제 지정)
              rm -f /etc/nginx/sites-enabled/default
              cat <<NGINX > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  root /var/www/html;
                  # index.php를 최우선으로 찾도록 설정
                  index index.php index.html index.htm;
                  server_name _;

                  location / {
                      try_files \$uri \$uri/ /index.php?\$query_string;
                  }

                  location ~ \.php$ {
                      include snippets/fastcgi-php.conf;
                      # 🚨 설치한 php8.1-fpm과 정확히 일치하는 소켓 경로 사용
                      fastcgi_pass unix:/run/php/php8.1-fpm.sock;
                      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                  }
              }
              NGINX
              ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

              # [7] DB 테이블 자동 생성 (기존 코드 유지)
              sleep 10
              mysql -h ${var.rds_endpoint} -u ${var.db_user} -ppassword123! ${var.db_name} <<SQL
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE,
                    password VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS notices (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    content TEXT
                );
                CREATE TABLE IF NOT EXISTS posts (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(100),
                    content TEXT,
                    author VARCHAR(50)
                );
                -- (선택 사항) 공지사항 중복 삽입 방지 로직
                INSERT INTO notices (content) 
                SELECT '추현수님, 인프라부터 DB까지 모든 배포에 성공하셨습니다!' 
                WHERE NOT EXISTS (SELECT 1 FROM notices LIMIT 1);
              SQL

              # [8] CloudWatch 에이전트 설치 및 설정 (기존 코드 유지)
              cat <<JSON > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "agent": { "metrics_collection_interval": 60, "run_as_user": "root" },
                "metrics": { "metrics_collected": { "disk": { "measurement": ["used_percent"], "resources": ["/"] }, "mem": { "measurement": ["mem_used_percent"] } } }
              }
              JSON
              
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i -E ./amazon-cloudwatch-agent.deb
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

              # [9] 서비스 최종 재시작 (통합: 명시적 재시작)
              systemctl enable --now php8.1-fpm
              systemctl restart php8.1-fpm
              systemctl restart nginx
              echo "OK" > /var/www/html/status.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.pjt_name}-asg-web" }
  }
}

# 2. Auto Scaling Group (기존 유지)
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