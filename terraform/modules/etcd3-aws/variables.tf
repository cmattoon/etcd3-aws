variable "region" {
  description = "The AWS region to deploy to"
  type        = "string"
}

variable "name" {
  description = "A name for the cluster (optional)"
  type        = "string"
  default     = "Cluster"
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = "string"
  default     = "t2.medium"
}

variable "backup_bucket_name" {
  description = "The name of an existing S3 bucket. Will be used like 's3://{bucket_name}/{prefix}/'"
  type        = "string"
}

variable "backup_bucket_prefix" {
  description = "The S3 prefix. Will be used like 's3://{bucket_name}/{prefix}/'"
  type        = "string"
}

variable "subnets" {
  description = "A list of Subnet IDs to use (3)"
  type        = "list"
  default     = ["", "", ""]
}

variable "key_pair_name" {
  description = "SSH KeyPair name. Should already exist"
  type        = "string"
}

variable "dns_zone_domain" {
  description = "The Route53 zone where 'dns_record_elb' will be created."
  type        = "string"
}

variable "dns_record_elb" {
  description = "Name of the ALIAS record to create"
  type        = "string"
  default     = "etcd"
}

variable "num_nodes" {
  description = "The number of etcd nodes to maintain"
  type        = "string"
  default     = "3"
}

variable "ssh_cidr_block" {
  description = "Allow SSH from this CIDR block"
  type        = "string"
  default     = "172.31.0.0/16"
}
