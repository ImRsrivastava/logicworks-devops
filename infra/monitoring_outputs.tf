resource "aws_sns_topic" "alerts" {
  provider = aws.primary
  name     = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  provider  = aws.primary
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "primary_prod_cpu_high" {
  provider            = aws.primary
  alarm_name          = "${var.project_name}-primary-prod-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Alert when Primary Prod ECS CPU exceeds 75%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.primary.name
    ServiceName = aws_ecs_service.primary_prod.name
  }
}

output "primary_ecr_url" {
  value = aws_ecr_repository.primary.repository_url
}

output "secondary_ecr_url" {
  value = aws_ecr_repository.secondary.repository_url
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}