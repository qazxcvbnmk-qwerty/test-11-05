#!/bin/bash
set -e

echo "=== EC2 Web Server Auto Installer Start ==="

# -----------------------------
# 1. 패키지 업데이트
# -----------------------------
yum update -y

# -----------------------------
# 2. PHP 8.1 설치
# -----------------------------
amazon-linux-extras enable php8.1
yum clean metadata
yum install -y php php-cli php-pdo php-mysqlnd php-json php-mbstring php-xml php-gd php-intl

# -----------------------------
# 3. Apache 설치
# -----------------------------
yum install -y httpd git unzip

systemctl enable httpd
systemctl start httpd

# -----------------------------
# 4. 웹 루트 초기화
# -----------------------------
rm -rf /var/www/html/*
cd /var/www/html

# -----------------------------
# 5. Composer 설치
# -----------------------------
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# -----------------------------
# 6. 프로젝트 다운로드
# (너의 실제 웹 프로젝트 ZIP 경로로 교체)
# -----------------------------
wget https://github.com/qazxcvbnmk-qwerty/test-11-05/raw/refs/heads/main/webtest.zip -O webtest.zip
unzip webtest.zip
rm -f webtest.zip

# 폴더 정리
if [ -d "webtest" ]; then
    mv webtest/* .
    rm -rf webtest
fi

# -----------------------------
# 7. PHP 패키지 설치 (AWS SDK 포함)
# -----------------------------
composer install || composer require aws/aws-sdk-php -W

# -----------------------------
# 8. 권한 설정
# -----------------------------
chown -R apache:apache /var/www/html
chmod -R 775 /var/www/html

# -----------------------------
# 9. 재시작
# -----------------------------
systemctl restart httpd

# -----------------------------
# 10. 헬스 체크 파일 생성
# -----------------------------
echo "EC2 PHP Web Server Ready" > /var/www/html/health.txt

echo "=== Auto Installer Complete ==="
