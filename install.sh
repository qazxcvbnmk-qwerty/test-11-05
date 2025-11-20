#!/bin/bash
set -e

echo "=== EC2 Web Server Auto Installer Start ==="

# --- 1. 시스템 업데이트 ---
yum update -y

# --- 2. Amazon Linux Extras: PHP 8.1 활성화 ---
amazon-linux-extras enable php8.1
yum clean metadata
yum install -y php php-cli php-pdo php-fpm php-json php-mysqlnd php-gd php-mbstring php-xml

# --- 3. Apache / Git / unzip 설치 ---
yum install -y httpd git unzip

# --- 4. Apache 시작 + 부팅 자동 등록 ---
systemctl enable httpd
systemctl start httpd

# --- 5. 기존 /var/www/html 정리 ---
rm -rf /var/www/html/*
mkdir -p /var/www/html

# --- 6. Composer 설치 ---
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# --- 7. GitHub ZIP 다운로드 ---
cd /var/www/html
curl -L -o webtest.zip https://github.com/qazxcvbnmk-qwerty/test-11-05/raw/refs/heads/main/webtest.zip

# --- 8. ZIP 압축 해제 ---
unzip -o webtest.zip
rm -f webtest.zip

# --- 9. 권한 설정 ---
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

echo "=== INSTALL COMPLETE ==="
echo "Service URL = http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"


