resource "as_sqs_queue" "events" {
  name = "etcd-${var.name}-events"
}

