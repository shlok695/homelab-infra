resource "aws_sqs_queue" "sync_dlq" {
  name                      = "ipl-sync-dlq"
  message_retention_seconds = 1209600 #14 days
}


resource "aws_sqs_queue" "sync" {
  name                       = "ipl-sync"
  visibility_timeout_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sync_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_iam_role" "scheduler" {
  name = "ipl-scheduler"
  assume_role_policy = jsonencode({
    version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRole",
      Principal = { Service = "scheduler.amazonaws.com" }
    }]
  })
}

# Lets the scheduler put messages on the sync queue, and nothing else
resource "aws_iam_role_policy" "scheduler_send" {
  name = "ipl-scheduler-send"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sqs:SendMessage",
    Resource = aws_sqs_queue.sync.arn }]
  })
}

#One entry per trigger pattern the worker uses today (America/New_York):
#weekdays 12:30, 14:30, 16:00 . weekends 08:30, 09:55, 12:30, 14:30, 16:00

locals {
  sync_schedules = {
    "weekday-1230-1430"     = "cron(30 12,14 ? * MOn-Fri *)"
    "weekend-0830-230-1430" = "cron(30 8,2,14 ? * SAT,SUN *)"
    "weekend-0955"          = "cron(55 9 ? * SAT,SUN *)"
    "daily-1600"            = "cron(0 16 ? * * *)" #weekdays and weekends
  }
}

resource "aws_scheduler_schedule" "sync" {
  for_each                     = local.sync_schedules
  name                         = "ipl-sync-${each.key}"
  schedule_expression          = each.value
  schedule_expression_timezone = "America/New_York"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_sqs_queue.sync.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = jsonencode({ reason = each.key })
  }
}

resource "aws_s3_bucket" "backups" { bucket = "ipl-backups" }

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "expire-30d"
    status = "Enabled"
    filter {}
    expiration { days = 30 }
  }
}

resource "aws_secretsmanager_secret" "rapidapi" { name = "ipl/rapidapi" }

output "sync_queue_url" { value = aws_sqs_queue.sync.url }
output "dlq_url" { value = aws_sqs_queue.sync_dlq.url }

