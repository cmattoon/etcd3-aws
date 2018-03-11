data "aws_iam_policy_document" "etcd" {
  statement {
    sid       = "AllowIntrospection"
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "ec2:DescribeInstances",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:CompleteLifecycleAction"
    ]
  }

  statement {
    sid       = "SQSReadAndRemove"
    effect    = "Allow"
    resources = ["${aws_sqs_queue.events.arn}"]
    actions   = [
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]
  }

  statement {
    sid       = "AllowS3Backup"
    effect    = "Allow"
    resources = ["arn:aws:s3:::${var.backup_bucket_name}/*"]
    actions   = ["s3:*"]
  }

  statement {
    sid       = "AllowPutCloudWatchMetrics"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["cloudwatch:PutMetricData"]
  }
}

data "aws_iam_policy_document" "lifecycle_hook" {
  statement {
    sid       = "AllowSQSPublish"
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl"
    ]
  }

  statement {
    sid       = "AllowSNSPublish"
    effect    = "Allow"
    resources = ["*"]
    actions = ["sns:Publish"]
  }
}

resource "aws_iam_policy" "etcd" {
  description = "etcd node policy"
  path        = "/"
  name        = "etcd-node-policy-${var.name}"
  policy      = "${data.aws_iam_policy_document.etcd.json}"
}

resource "aws_iam_policy" "lifecycle_hook" {
  description = "policy for autoscale lifecycle hooks"
  path        = "/"
  name        = "etcd-asg-lifecycle-policy-${var.name}"
  policy      = "${data.aws_iam_policy_document.lifecycle_hook.json}"
}

resource "aws_iam_role" "etcd" {
  name               = "etcd-node-role-${var.name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "lifecycle_hook" {
  name               = "etcd-lifecycle-role-${var.name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "autoscaling.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "etcd" {
  name       = "etcd-node-policy-attachment"
  roles      = ["${aws_iam_role.etcd.name}"]
  policy_arn = "${aws_iam_policy.etcd.arn}"
}

resource "aws_iam_policy_attachment" "lifecycle_hook" {
  name       = "etcd-lifecycle-hook-attachment"
  roles      = ["${aws_iam_role.lifecycle_hook.name}"]
  policy_arn = "${aws_iam_policy.lifecycle_hook.arn}"
}

resource "aws_iam_instance_profile" "etcd" {
  name = "etcd-node-profile-${var.name}"
  role = "${aws_iam_role.etcd.name}"
}


