# 1. Launch Template: 서버의 상세 설정 (기능 통합 버전)
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
              
              # [1] 시스템 안정화 (잠금 해제 및 환경 준비)
              sleep 30
              export DEBIAN_FRONTEND=noninteractive
              systemctl stop unattended-upgrades
              killall apt apt-get 2>/dev/null
              rm -f /var/lib/dpkg/lock*
              dpkg --configure -a

              # [2] 패키지 설치 (PHP 8.1 고정 및 필수 확장 모듈)
              apt-get update -y
              apt-get install -y nginx git unzip wget mysql-client
              apt-get install -y php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml

              # [3] 깃허브 코드 배포
              rm -rf /var/www/html/*
              git clone https://github.com/chuhyunsoo123-droid/chu1.git /tmp/repo
              # 최신 구조에 맞춰 Team_pjt 폴더 전체를 복사합니다.
              cp -r /tmp/repo/Team_pjt/* /var/www/html/

              # [4] 설정 파일 통합 주입 (DB + S3)
              # 업로드하신 코드의 config/config.php 경로에 설정을 주입합니다.
              mkdir -p /var/www/html/config
              cat <<PHP > /var/www/html/config/config.php
              <?php
              // DB 설정
              define('DB_HOST', '${var.rds_endpoint}');
              define('DB_USER', '${var.db_user}');
              define('DB_PASS', 'password123!');
              define('DB_NAME', '${var.db_name}');

              // S3 설정 (자동 주입)
              define('S3_BUCKET_NAME', '${var.s3_bucket_name}');
              define('S3_REGION', 'ap-northeast-2');

              // 기존 변수명 호환을 위한 추가 (config_aws.php 역할)
              \$servername = "${var.rds_endpoint}";
              \$username = "${var.db_user}";
              \$password = "password123!";
              \$dbname = "${var.db_name}";
              ?>
              PHP

              # [5] 권한 설정 (403/500 에러 방지)
              chown -R www-data:www-data /var/www/html
              find /var/www/html -type d -exec chmod 755 {} \;
              find /var/www/html -type f -exec chmod 644 {} \;

              # [6] Nginx 설정 (중요: 소스 구조에 따라 root 경로 지정)
              # 만약 index.php가 public 폴더 안에 있다면 /var/www/html/public으로 수정하세요.
              rm -f /etc/nginx/sites-enabled/default
              cat <<NGINX > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  root /var/www/html;  # index.php 위치에 따라 /public 추가 가능
                  index index.php index.html;
                  server_name _;

                  location / {
                      try_files \$uri \$uri/ /index.php?\$query_string;
                  }

                  location ~ \.php$ {
                      include snippets/fastcgi-php.conf;
                      fastcgi_pass unix:/run/php/php8.1-fpm.sock;
                      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                  }
              }
              NGINX
              ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

              # [7] DB 테이블 생성
              sleep 10
              mysql -h ${var.rds_endpoint} -u ${var.db_user} -ppassword123! ${var.db_name} <<SQL
                CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE, password VARCHAR(255));
                CREATE TABLE IF NOT EXISTS notices (id INT AUTO_INCREMENT PRIMARY KEY, content TEXT);
                CREATE TABLE IF NOT EXISTS posts (id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(100), content TEXT, author VARCHAR(50));
                INSERT INTO notices (content) SELECT '추현수님, 통합 배포에 성공하셨습니다!' WHERE NOT EXISTS (SELECT 1 FROM notices LIMIT 1);
              SQL

              # [8] CloudWatch 에이전트 설정 (생략 가능하나 기존 코드 유지)
              wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
              dpkg -i -E ./amazon-cloudwatch-agent.deb
              # (중간 에이전트 JSON 설정 생략 - 기존과 동일하게 유지하시면 됩니다)

              # [9] 서비스 최종 재시작
              systemctl enable --now php8.1-fpm
              systemctl restart php8.1-fpm
              systemctl restart nginx
              echo "OK" > /var/www/html/status.html
              EOF
  )
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
}