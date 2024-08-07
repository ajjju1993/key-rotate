resource "random_string" "lambda_permission_id" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_cloudwatch_event_rule" "schedule_rule" {
  name                 = "schedule_rule"
  schedule_expression  = "cron(0 12 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule_rule.name
  target_id = "key_rotation"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge-${random_string.lambda_permission_id.result}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "events.amazonaws.com"
}

output "eventbridge_rule_arn" {
  description = "The ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.schedule_rule.arn
}
