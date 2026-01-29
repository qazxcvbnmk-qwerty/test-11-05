# 1. 람다용 IAM 역할 (EC2 보안 그룹 변경 권한 필요)
resource "aws_iam_role" "lambda_exec" {
  name = "ransomware_isolation_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

# 2. 보안 그룹 변경 권한 정책 연결
resource "aws_iam_role_policy" "lambda_ec2_policy" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:ModifyInstanceAttribute", "ec2:DescribeInstances"]
      Resource = "*"
    }]
  })
}

# 3. 자동 격리 람다 함수 (Python)
resource "aws_lambda_function" "isolate_ec2" {
  filename      = "lambda_function.zip" # 파이썬 코드를 압축한 파일
  function_name = "IsolateCompromisedEC2"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  environment {
    variables = {
      ISOLATION_SG_ID = var.isolation_sg_id # 격리용 SG ID 전달
    }
  }
}