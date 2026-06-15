resource "random_password" "db" {
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.environment}-${var.app_name}-db-password"
  description             = "Database password for ${var.app_name} (${var.environment})"
  recovery_window_in_days = 0

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

data "aws_iam_policy_document" "ecs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.environment}-${var.app_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust.json

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

data "aws_iam_policy_document" "task_permissions" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_secretsmanager_secret.db_password.arn]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "${var.environment}-${var.app_name}-task-policy"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_permissions.json
}
