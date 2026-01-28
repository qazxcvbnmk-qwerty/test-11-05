output "log_group_name" {
  value = aws_cloudwatch_log_group.integrated_logs.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.integrated_alerts.arn
}