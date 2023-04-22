
resource "aws_wafv2_web_acl" "alb_web_acl" {
  name        = "${local.project}-alb-web-acl"
  description = "Web ACL for Application Load Balancer"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = toset(local.waf.managed_rules)

    content {
      name     = rule.value
      priority = index(local.waf.managed_rules, rule.value) + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value
          vendor_name = "AWS"

          rule_action_override {
            action_to_use {
              count {}
            }

            name = "SizeRestrictions_BODY"
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWS-${rule.value}"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.project}-alb-web-acl"
    sampled_requests_enabled   = false
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "alb_web_acl_log_config" {
  log_destination_configs = [aws_cloudwatch_log_group.aws_waf_log.arn]
  resource_arn            = aws_wafv2_web_acl.alb_web_acl.arn
}
