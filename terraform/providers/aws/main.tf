provider "aws" {
  region = "${var.region}"
}

module "etcd" {
  source = "./../../modules/etcd3-aws"

  name = "${var.name}"
  region = "${var.region}"
  instance_type = "${var.instance_type}"
  backup_bucket_name = "${var.backup_bucket_name}"
  backup_bucket_prefix = "${var.name}/etcd3"
  subnets = ["${var.subnets}"]
  key_pair_name = "${var.key_pair_name}"
  ssh_cidr_block = "${var.ssh_cidr_block}"
  dns_zone_domain = "$[var.dns_zone_domain}"
  dns_record_elb = "etcd"
  
}
