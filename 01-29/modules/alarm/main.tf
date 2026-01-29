# 1. 통합 로그 그룹
resource "aws_cloudwatch_log_group" "integrated_logs" {
  name              = "/aws/ec2/web-server-logs-v2"
  retention_in_days = 7
}

# 2. 통합 SNS 주제
resource "aws_sns_topic" "integrated_alerts" {
  name = "INTEGRATED_INFRA_SECURITY_ALERTS"
}

# 3. 이메일 구독
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.integrated_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# [A] 로그 기반 감시 (랜섬웨어 감지) - 최종 보강
resource "aws_cloudwatch_log_metric_filter" "ransomware_detect" {
  name           = "RansomwareDetectionFilterV4"
  pattern        = "{ $.event = \"RansomwareDetected\" }"
  
  log_group_name = aws_cloudwatch_log_group.integrated_logs.name 

  metric_transformation {
    name          = "RansomwareEventCountV4"
    namespace     = "SecurityMonitoring"
    value         = "1"
    default_value = 0 
  }
}

resource "aws_cloudwatch_metric_alarm" "ransomware_alarm" {
  # ✅ 알람 이름을 V4로 변경하여 새 엔진을 활성화합니다.
  alarm_name          = "CRITICAL_RANSOMWARE_DETECTED_V4"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  
  # ✅ 필터에서 생성된 지표 이름을 직접 참조 (오타 방지)
  metric_name         = aws_cloudwatch_log_metric_filter.ransomware_detect.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.ransomware_detect.metric_transformation[0].namespace
  
  period              = "60"
  statistic           = "Sum"
  threshold           = "1" 
  
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.integrated_alerts.arn]
}
# ---------------------------------------------------------
# [B] 인프라 상태 변화 감시 (수정 없음)
# ---------------------------------------------------------
resource "aws_cloudwatch_event_rule" "infra_status_rule" {
  name        = "combined-infra-status-rule"
  description = "EC2 및 RDS 상태 변화 통합 감시"

  event_pattern = jsonencode({
    "source": ["aws.ec2", "aws.rds"],
    "detail-type": [
      "EC2 Instance State-change Notification",
      "RDS DB Instance Event"
    ]
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.infra_status_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.integrated_alerts.arn
}

# ---------------------------------------------------------
# [C] 권한 설정 (수정 없음)
# ---------------------------------------------------------
resource "aws_sns_topic_policy" "allow_cloudwatch_events" {
  arn = aws_sns_topic.integrated_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.integrated_alerts.arn
      }
    ]
  })
}