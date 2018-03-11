/**
 * Security Groups for Launch Config & ELB
 */

resource "aws_security_group" "etcd" {
  name        = "etcd_nodes_${var.name}"
  description = "Allow Ports 2379 and 2380 within the Autoscale Group"
  vpc_id      = "${data.aws_subnet.selected.vpc_id}"
}


resource "aws_security_group" "elb" {
  name        = "etcd_elb_${var.name}"
  description = "Allow Port 2379 between autoscale group and ELB"
  vpc_id      = "${data.aws_subnet.selected.vpc_id}"
}

resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.etcd.id}"
}

resource "aws_security_group_rule" "allow_all_etcd_traffic" {
  type              = "ingress"
  from_port         = 2379
  to_port           = 2380
  protocol          = "tcp"
  security_group_id = "${aws_security_group.etcd.id}"
  self              = true
}

resource "aws_security_group_rule" "allow_ssh_from_range" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${var.ssh_cidr_block}"]
}

resource "aws_security_group_rule" "allow_etcd_client_traffic" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.etcd.id}"
  security_group_id        = "${aws_security_group.elb.id}"
}

