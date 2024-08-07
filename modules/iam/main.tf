resource "aws_iam_role" "lambda_iam_role" {
  name = var.readonly_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "lambda_iam_policy"
  description = "IAM policy for Lambda to manage IAM keys"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:ListAccessKeys",
          "iam:CreateAccessKey",
          "iam:UpdateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListUsers",
          "iam:GetAccessKeyLastUsed"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DeleteSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_iam_policy_attachment" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

resource "aws_iam_user" "readonly_user" {
  name = var.readonly_user_name
}

resource "null_resource" "delete_existing_readonly_keys" {
  provisioner "local-exec" {
    command = <<EOF
    #!/bin/bash
    existing_keys=$(aws iam list-access-keys --user-name ${var.readonly_user_name} --query 'AccessKeyMetadata[*].AccessKeyId' --output text)
    for key in $existing_keys; do
      aws iam delete-access-key --user-name ${var.readonly_user_name} --access-key-id $key
    done
    EOF
    interpreter = ["bash", "-c"]
  }
  depends_on = [aws_iam_user.readonly_user]
}

resource "aws_iam_access_key" "readonly_user_key" {
  user = aws_iam_user.readonly_user.name
  depends_on = [null_resource.delete_existing_readonly_keys]
}

resource "aws_iam_user" "test_user" {
  name = var.test_user_name
}

resource "null_resource" "delete_existing_test_keys" {
  provisioner "local-exec" {
    command = <<EOF
    #!/bin/bash
    existing_keys=$(aws iam list-access-keys --user-name ${var.test_user_name} --query 'AccessKeyMetadata[*].AccessKeyId' --output text)
    for key in $existing_keys; do
      aws iam delete-access-key --user-name ${var.test_user_name} --access-key-id $key
    done
    EOF
    interpreter = ["bash", "-c"]
  }
  depends_on = [aws_iam_user.test_user]
}

resource "aws_iam_access_key" "test_user_key" {
  user = aws_iam_user.test_user.name
  depends_on = [null_resource.delete_existing_test_keys]
}

resource "aws_secretsmanager_secret" "readonly_user_secret" {
  name = var.secrets_manager_secret_name
}

resource "aws_secretsmanager_secret_version" "readonly_user_secret_version" {
  secret_id     = aws_secretsmanager_secret.readonly_user_secret.id
  secret_string = jsonencode({
    AccessKeyId     = aws_iam_access_key.readonly_user_key.id
    SecretAccessKey = aws_iam_access_key.readonly_user_key.secret
  })
}
