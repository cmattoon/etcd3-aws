data "aws_route53_zone" "main" {
  name = "${var.dns_zone_domain}"
  private_zone = false
}

resource "aws_route53_record" "elb" {
  zone_id = "${data.aws_route53_zone.main.id}"
  name    = "${var.dns_record}.${var.dns_zone_domain}"
  type    = "A"

  # ALIAS records always have TTL=60
  alias {
    name                   = "${aws_elb.etcd.dns_name}"
    zone_id                = "${aws_elb.etcd.zone_id}"
    evaluate_target_health = true
  }
}
