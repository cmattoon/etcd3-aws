resource "aws_sqs_queue" "events" {
  name = "etcd-${var.name}-events"
}

