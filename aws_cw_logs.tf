resource "aws_cloudwatch_log_group" "aws_waf_log_alb" {
  name = "aws-waf-logs-${local.project}-alb"
  tags = local.tags
}
