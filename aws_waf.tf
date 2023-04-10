
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
  log_destination_configs = [aws_cloudwatch_log_group.aws_waf_log_alb.arn]
  resource_arn            = aws_wafv2_web_acl.alb_web_acl.arn
}

resource "aws_cloudwatch_dashboard" "alb_web_acl_cw_dashboard" {
  dashboard_name = "${local.project}-alb-web-acl-cw-dashboard"
  dashboard_body = <<EOF
{
    "widgets": [
        {
            "height": 6,
            "width": 6,
            "y": 0,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields httpRequest.country\n| stats count(*) as requestCount by httpRequest.country\n| sort requestCount desc\n| limit 100",
                "region": "${local.region}",
                "stacked": false,
                "view": "pie",
                "title": "Countries by number of requests"
            }
        },
        {
            "height": 6,
            "width": 9,
            "y": 0,
            "x": 6,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | # fields @timestamp, @message\n# | sort @timestamp desc\n# | limit 20\n\n\nfields action, ruleGroupList.0.excludedRules.0.exclusionType\n| stats count(*) as Waf_Action by action, ruleGroupList.0.excludedRules.0.exclusionType\n| sort action desc\n| limit 100",
                "region": "${local.region}",
                "stacked": false,
                "title": "Allowed vs Blocked requests",
                "view": "pie"
            }
        },
        {
            "height": 6,
            "width": 5,
            "y": 9,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields httpRequest.country\n| stats count(*) as requestCount by httpRequest.country\n| sort requestCount desc\n| limit 10",
                "region": "${local.region}",
                "title": "Top 10 countries",
                "view": "table"
            }
        },
        {
            "height": 6,
            "width": 5,
            "y": 9,
            "x": 5,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields httpRequest.clientIp\n| stats count(*) as requestCount by httpRequest.clientIp\n| sort requestCount desc\n| limit 10",
                "region": "${local.region}",
                "stacked": false,
                "view": "table",
                "title": "Top 10 ip addresses"
            }
        },
        {
            "height": 6,
            "width": 10,
            "y": 15,
            "x": 5,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @timestamp, @message\n| parse @message '{\"name\":\"User-Agent\",\"value\":\"*\"}' as userAgent\n| stats count(*) as requestCount by userAgent\n| sort requestCount desc\n| limit 10",
                "region": "${local.region}",
                "stacked": false,
                "view": "table",
                "title": " Top 10 user-agents"
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 9,
            "x": 10,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @timestamp, @message\n| parse @message '{\"name\":\"Host\",\"value\":\"*\"}' as host\n| stats count(*) as requestCount by host\n| sort requestCount desc\n| limit 10",
                "region": "${local.region}",
                "stacked": false,
                "title": "Top 10 hosts",
                "view": "table"
            }
        },
        {
            "height": 6,
            "width": 7,
            "y": 15,
            "x": 15,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields terminatingRuleId\n| stats count(*) as requestCount by terminatingRuleId\n| sort requestCount desc\n| limit 10",
                "region": "${local.region}",
                "stacked": false,
                "view": "table",
                "title": "Top 10 terminating rules"
            }
        },
        {
            "height": 6,
            "width": 7,
            "y": 9,
            "x": 16,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields httpRequest.uri\n| stats count(*) as requestCount by httpRequest.uri\n| sort requestCount desc\n| limit 20",
                "region": "${local.region}",
                "stacked": false,
                "view": "table",
                "title": "Top 20 URI"
            }
        },
        {
            "height": 9,
            "width": 9,
            "y": 0,
            "x": 15,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields action, ruleGroupList.0.excludedRules.0.exclusionType\n| stats count(*) as requestCount by action, ruleGroupList.0.excludedRules.0.exclusionType\n| sort requestCount desc\n| limit 100",
                "region": "${local.region}",
                "stacked": false,
                "title": "Allowed vs Blocked Requests",
                "view": "bar"
            }
        },
        {
            "height": 3,
            "width": 3,
            "y": 6,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @action\n| stats count(*) as requestCount",
                "region": "${local.region}",
                "stacked": false,
                "title": "All Requests",
                "view": "table"
            }
        },
        {
            "height": 3,
            "width": 3,
            "y": 6,
            "x": 3,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @action\n| filter action=\"BLOCK\"\n| stats count(*)",
                "region": "${local.region}",
                "stacked": false,
                "title": "Blocked Requests",
                "view": "table"
            }
        },
        {
            "height": 6,
            "width": 5,
            "y": 15,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @httpRequest.httpMethod\n| stats count(*) as httpMethod by httpRequest.httpMethod\n| sort requestCount desc",
                "region": "${local.region}",
                "stacked": false,
                "view": "pie",
                "title": "HTTP Methods"
            }
        },
        {
            "height": 6,
            "width": 24,
            "y": 21,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields action, ruleGroupList.0.terminatingRule.ruleId, ruleGroupList.1.terminatingRule.ruleId, ruleGroupList.2.terminatingRule.ruleId, ruleGroupList.3.terminatingRule.ruleId\n| filter action=\"BLOCK\"\n| sort @timestamp desc",
                "region": "${local.region}",
                "stacked": false,
                "view": "table",
                "title": "BlockedRequestsByRuleID"
            }
        },
        {
            "height": 3,
            "width": 3,
            "y": 6,
            "x": 6,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @action\n| filter action=\"ALLOW\" and ruleGroupList.0.excludedRules.0.exclusionType!=\"EXCLUDED_AS_COUNT\"\n| stats count(*)",
                "region": "${local.region}",
                "stacked": false,
                "title": "Allowed Requests",
                "view": "table"
            }
        },
        {
            "height": 3,
            "width": 3,
            "y": 6,
            "x": 9,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @action\n| filter action=\"ALLOW\" and ruleGroupList.0.excludedRules.0.exclusionType=\"EXCLUDED_AS_COUNT\"\n| stats count(*)",
                "region": "${local.region}",
                "stacked": false,
                "title": "Allowed as Counted",
                "view": "table"
            }
        },
        {
            "height": 6,
            "width": 24,
            "y": 27,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '${aws_cloudwatch_log_group.aws_waf_log_alb.name}' | fields @timestamp, action as WAF_ACTION, httpRequest.uri as uri, httpRequest.country as country\n| parse @message '{\"name\":\"Host\",\"value\":\"*\"}' as host\n| parse @message '{\"exclusionType\":\"EXCLUDED_AS_COUNT\",\"ruleId\":\"*\"}' as EXCLUDED_AS_COUNT_RuleId\n| filter ispresent(EXCLUDED_AS_COUNT_RuleId)\n| limit 100",
                "region": "${local.region}",
                "stacked": false,
                "title": "EXCLUDED_AS_COUNT Requests",
                "view": "table"
            }
        }
    ]
}
EOF

  depends_on = [aws_wafv2_web_acl.alb_web_acl]
}
