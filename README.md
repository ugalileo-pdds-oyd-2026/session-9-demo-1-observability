# Session 9 — Demo 1: Observability Module

Build app-level logging and cost alerting for a containerized Flask app on AWS ECS using `watchtower`, CloudWatch, SNS, and Terraform modules.

## What students learn

- Why logs written to stdout are silently lost when an ECS container restarts, and how CloudWatch Logs solves this
- How `watchtower` hooks into Python's standard `logging` module so every `logger.info()` call ships to CloudWatch without touching existing call sites
- How to structure a reusable Terraform observability module (log group, alarms, SNS notifications) following the same module pattern used throughout the course
- Why AWS billing metrics (`EstimatedCharges`) only exist in `us-east-1`, and how Terraform provider aliases let a single module span multiple regions
- The difference between a CloudWatch alarm (near-real-time) and `aws_budgets_budget` (governance ceiling, up to 24 h lag) — and why production systems need both
- Why passing `alb_arn_suffix` as a module input keeps the observability module pure and independently testable

## Project structure

```
start/
├── app/
│   ├── main.py             # Flask app — stdout logging only, no watchtower
│   └── requirements.txt    # flask only — no watchtower or boto3
└── infra/
    ├── main.tf             # module calls (compute, secrets, networking)
    ├── versions.tf         # provider config — no us-east-1 alias yet
    └── modules/
        ├── compute/
        ├── networking/
        └── secrets/
        # observability/ does not exist yet — you build it
```

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- [Docker](https://docs.docker.com/get-docker/) (for local image builds if needed)

## Demo workflow

### 1. Tour the start state

```bash
tree start/
cat start/app/main.py
```

Notice that `main.py` uses Python's standard `logging` module with a `StreamHandler` — logs go to stdout only. There is no `watchtower` or `boto3` in `requirements.txt`. If the container crashes and restarts, all logs are gone.

### 2. Wire `watchtower` into the app

Edit `app/main.py` — replace the logging setup block:

```python
import os
import logging
import watchtower

LOG_GROUP_NAME = os.environ.get("LOG_GROUP_NAME", "/app/local")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if LOG_GROUP_NAME != "/app/local":
    cw_handler = watchtower.CloudWatchLogHandler(
        log_group_name=LOG_GROUP_NAME,
        stream_name="app",
    )
    cw_handler.setFormatter(logging.Formatter(
        '{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}'
    ))
    logger.addHandler(cw_handler)
```

The `StreamHandler` stays — logs still appear in `docker logs` for local development. `LOG_GROUP_NAME` will be injected by Terraform as an ECS environment variable.

### 3. Update `requirements.txt`

Edit `app/requirements.txt`:

```
flask==3.1.0
watchtower==3.3.1
boto3==1.34.0
```

`watchtower` uses `boto3` to call the CloudWatch Logs `PutLogEvents` API. The ECS task role already has the required IAM permissions — `watchtower` picks up credentials automatically from the ECS metadata endpoint. No hard-coded credentials needed.

### 4. Create the observability module directory

```bash
mkdir -p infra/modules/observability
touch infra/modules/observability/main.tf
touch infra/modules/observability/variables.tf
touch infra/modules/observability/outputs.tf
```

### 5. Add `aws_cloudwatch_log_group`

In `infra/modules/observability/main.tf`:

```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/app/${var.environment}/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

`retention_in_days` defaults to 30. CloudWatch Logs charges per GB stored — without this setting, retention is infinite and will appear on your bill unexpectedly.

### 6. Add SNS topic + email subscription

In `infra/modules/observability/main.tf`:

```hcl
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-${var.app_name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
```

After `terraform apply`, AWS sends a confirmation email to `notification_email`. You must click the confirmation link or the subscription stays in `Pending` state and no alerts will be delivered.

### 7. Add HTTP 5xx alarm (ALB namespace)

In `infra/modules/observability/main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${var.environment}-${var.app_name}-http-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.http_5xx_threshold
  alarm_description   = "More than ${var.http_5xx_threshold} HTTP 5xx responses in 60 seconds"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}
```

`evaluation_periods = 2` means the alarm waits for two consecutive minutes of 5xx errors before firing — a single spike won't trigger it. The `LoadBalancer` dimension takes the ALB ARN suffix (`app/<name>/<hash>`), not the full ARN.

### 8. Add latency alarm (ALB namespace)

In `infra/modules/observability/main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "latency" {
  alarm_name          = "${var.environment}-${var.app_name}-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p90"
  threshold           = var.latency_threshold_seconds
  alarm_description   = "p90 target response time exceeded ${var.latency_threshold_seconds}s for 3 consecutive minutes"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}
```

`extended_statistic = "p90"` means 90% of requests are faster than the threshold. Use `p90` or `p99` in production rather than `Average`, which hides slow outliers.

### 9. Configure provider alias for `us-east-1`

Add this block at the top of `infra/modules/observability/main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
```

`configuration_aliases` tells Terraform this module expects a `us_east_1` provider alias to be passed in by its caller. The module declares the requirement; the root module will supply it.

### 10. Add billing SNS topic + `EstimatedCharges` alarm

AWS billing metrics only exist in `us-east-1`. CloudWatch also rejects `alarm_actions` pointing to an SNS topic in a different region, so billing alarms need their own SNS topic in `us-east-1`.

In `infra/modules/observability/main.tf`:

```hcl
# Billing metrics only exist in us-east-1; CloudWatch rejects SNS ARNs from other regions.
resource "aws_sns_topic" "billing_alarms" {
  provider = aws.us_east_1
  name     = "${var.environment}-${var.app_name}-billing-alarms"
}

resource "aws_sns_topic_subscription" "billing_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.billing_alarms.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_metric_alarm" "estimated_charges" {
  provider = aws.us_east_1

  alarm_name          = "${var.environment}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 28800
  statistic           = "Maximum"
  threshold           = var.estimated_charges_threshold
  alarm_description   = "Estimated AWS charges exceeded $${var.estimated_charges_threshold} USD"
  alarm_actions       = [aws_sns_topic.billing_alarms.arn]
  ok_actions          = [aws_sns_topic.billing_alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }
}
```

After `terraform apply` you will receive **two** SNS confirmation emails — one for `us-west-2` (app alarms) and one for `us-east-1` (billing alarm). Both must be confirmed.

`period = 28800` (8 hours) is the minimum CloudWatch supports for billing metrics. `statistic = "Maximum"` picks the latest reported value.

### 11. Add `aws_budgets_budget`

In `infra/modules/observability/main.tf`:

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "${var.environment}-${var.app_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alarms.arn]
  }
}
```

Budget alerts read processed billing data and can lag up to 24 hours. Use this for governance and compliance — use the `EstimatedCharges` alarm above for near-real-time cost visibility. The combination of both is the production pattern.

### 12. Add `variables.tf` for the observability module

Create `infra/modules/observability/variables.tf` with input variables for:

- `app_name`, `environment`, `aws_region`
- `log_retention_days` (default: `30`)
- `alb_arn_suffix` — the `app/<name>/<hash>` format CloudWatch expects in the `LoadBalancer` dimension
- `notification_email`
- `http_5xx_threshold`, `latency_threshold_seconds`
- `estimated_charges_threshold` — set this to a value your account has already exceeded so the alarm is immediately in ALARM state
- `monthly_budget_usd`

Every threshold should have a `description` explaining the cost reason or expected format.

### 13. Add `outputs.tf` for the observability module

In `infra/modules/observability/outputs.tf`:

```hcl
output "log_group_name" {
  description = "CloudWatch log group name for the application. Inject this into the ECS task definition as LOG_GROUP_NAME so watchtower can locate the log group."
  value       = aws_cloudwatch_log_group.app.name
}

output "alarm_topic_arn" {
  description = "SNS topic ARN used by all CloudWatch alarms"
  value       = aws_sns_topic.alarms.arn
}

output "http_5xx_alarm_name" {
  description = "Name of the HTTP 5xx CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.http_5xx.alarm_name
}

output "latency_alarm_name" {
  description = "Name of the latency CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.latency.alarm_name
}

output "estimated_charges_alarm_arn" {
  description = "ARN of the EstimatedCharges billing alarm. Referenced by the CloudWatch dashboard alarm widget."
  value       = aws_cloudwatch_metric_alarm.estimated_charges.arn
}
```

### 14. Add provider alias to root `versions.tf`

In `infra/versions.tf` — add the aliased provider block:

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

Modules cannot declare new providers — only the root can. This block says "the root owns a `us-east-1` provider under the alias `us_east_1`."

### 15. Call the observability module from root `main.tf`

In `infra/main.tf` — add the module block and update the compute module:

```hcl
module "observability" {
  source = "./modules/observability"

  app_name                    = var.app_name
  environment                 = var.environment
  aws_region                  = var.aws_region
  log_retention_days          = var.log_retention_days
  alb_arn_suffix              = module.compute.alb_arn_suffix
  notification_email          = var.notification_email
  http_5xx_threshold          = var.http_5xx_threshold
  latency_threshold_seconds   = var.latency_threshold_seconds
  estimated_charges_threshold = var.estimated_charges_threshold
  monthly_budget_usd          = var.monthly_budget_usd

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
}

# Update compute module to inject the log group name
module "compute" {
  source = "./modules/compute"
  # ... existing inputs ...
  log_group_name = "/app/${var.environment}/${var.app_name}"
}
```

The `providers = { }` map threads the aliased provider from the root into the module. `module.compute.alb_arn_suffix` is already an output from the compute module — the observability module consumes it without knowing anything about how it was created.

### 16. Apply and verify

```bash
cd infra
terraform init
terraform plan -var-file="envs/dev/dev.tfvars" --upgrade
terraform apply -var-file="envs/dev/dev.tfvars"
```

After apply, verify in the AWS console:

1. **CloudWatch → Log groups** — `/app/dev/<app_name>` appears with 30-day retention
2. **CloudWatch → Alarms** — three alarms visible: HTTP 5xx, latency, and EstimatedCharges
3. **CloudWatch → Alarms → EstimatedCharges** — should show ALARM state
4. **Email inbox** — two SNS confirmation emails; click both links
5. **AWS Budgets** — monthly budget appears

Expected output:

```
Apply complete! Resources: ~8 added, 1 changed, 0 destroyed.
```

### 17. Clean up

```bash
terraform destroy -var-file="envs/dev/dev.tfvars"
```

## Expected outcomes

By the end of this demo, students should be able to:

1. Integrate `watchtower` into a Python app so all existing `logger.*` calls ship to CloudWatch without changing call sites
2. Write a Terraform observability module that provisions a log group, SNS topic, and CloudWatch alarms as a reusable unit
3. Explain why Terraform provider aliases are necessary when a module creates resources in more than one AWS region
4. Distinguish between a CloudWatch billing alarm (near-real-time) and an `aws_budgets_budget` (governance ceiling, delayed) and know when to use each
5. Confirm that keeping `log_group_name` as a convention string (rather than wiring it through module outputs) keeps the compute and observability modules independently testable
