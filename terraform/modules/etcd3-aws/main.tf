/**
 * Creates an AutoScaling Group with three CoreOS instances, each running a few Docker containers
 * 
 *        [ALIAS]
 *           | 
 *         [ELB]
 *         /  | \
 *       /    |   \
 *     /      |     \
 *  +----+ +----+ +----+
 *  | [] | | [] | | [] |  <-- etcd binary
 *  | [] | | [] | | [] |  <-- etcd3-aws (Monitors LifecycleHooks/SQS)
 *  | [] | | [] | | [] |  <-- etcd3-backup (Periodically backs up to S3)
 *  +----+ +----+ +----+
 */

data "aws_ami" "coreos" {
  most_recent = true

  filter {
    name   = "name"
    values = ["CoreOS-stable-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"]
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.yaml.tpl")}"

  vars {
    region = "${var.region}"
    backup_bucket_name = "${var.backup_bucket_name}"
    backup_key         = "${var.backup_bucket_prefix}"
  }
}
  
data "aws_subnet" "selected" {
  id = "${var.subnets[0]}"
}

resource "aws_launch_configuration" "etcd" {
  name_prefix                 = "etcd3-aws-${var.name}_"
  image_id                    = "${data.aws_ami.coreos.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.key_pair_name}"
  associate_public_ip_address = false
  security_groups             = ["${aws_security_group.etcd.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.etcd.name}"
  user_data                   = "${base64encode(data.template_file.user_data.rendered)}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "etcd" {
  name                 = "etcd-${var.name}-${aws_launch_configuration.etcd.name}"
  load_balancers       = ["${aws_elb.etcd.name}"]
  min_size             = "${var.num_nodes}"
  desired_capacity     = "${var.num_nodes}"
  max_size             = "${var.num_nodes*2}"
  min_elb_capacity     = "${var.num_nodes}"
  
  vpc_zone_identifier  = ["${var.subnets}"]
  launch_configuration = "${aws_launch_configuration.etcd.name}"

  tags = [{
    propagate_at_launch = true
    key                 = "Name"
    value               = "etcd-${var.name}"
  }]

  initial_lifecycle_hook {
    name                    = "etcd-${var.name}-terminating"
    default_result          = "CONTINUE"
    heartbeat_timeout       = 30
    lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
    notification_target_arn = "${aws_sqs_queue.events.arn}"
    role_arn                = "${aws_iam_role.lifecycle_hook.arn}"
  }

  lifecycle {
    create_before_destroy = true
  }
  
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupTotalInstances",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances"
  ]
}

resource "aws_elb" "etcd" {
  name            = "etcd-${var.name}"
  subnets         = ["${var.subnets}"]
  security_groups = ["${aws_security_group.elb.id}"]
  internal        = true

  cross_zone_load_balancing = true

  listener {
    instance_port     = "2379"
    instance_protocol = "tcp"
    lb_port           = "2379"
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 5
    target              = "HTTP:2379/health"
    interval            = 10
  }

  tags {
    Name = "etcd-${var.name}"
  }
}

