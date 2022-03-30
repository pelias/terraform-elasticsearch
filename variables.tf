## AWS Gobal settings

variable "ssh_key_name" {
  description = "Name of AWS key pair"
}

variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "aws_vpc_id" {
  description = "These templates assume a VPC already exists"
}

variable "subnet_name_filter" {
  description = "Filter subnets within the VPC by using this name"
  default     = "Elasticsearch"
}

variable "subnet_name_filter_property" {
  description = "Filter subnets within the VPC by using this name"
  default     = "tag:Name"
}

# security settings
variable "ssh_ip_range" {
  description = "Range of IPs able to SSH into the Elasticsearch nodes"
  default = "0.0.0.0/0"
}

# Autoscaling Group Settings

# t3.large is a good economic default for low volume full planet builds
# for more performance, use m5.2xlarge, c5.2xlarge or similar. High throughput
# geocoders really love having lots of CPU available
variable "elasticsearch_instance_type" {
  description = "Elasticsearch instance type."
  default     = "c5d.9xlarge"
}

# Elasticsearch ASG instance counts
# a full planet build can run on a single node, but 2 is better
variable "elasticsearch_min_instances" {
  description = "total instances"
  default     = "2"
}

variable "elasticsearch_desired_instances" {
  description = "total instances"
  default     = "2"
}

variable "elasticsearch_max_instances" {
  description = "total instances"
  default     = "2"
}

# higher values here tune elasticsearch for use on smaller clusters
# lower values give better performance if there is lots of RAM available
variable "elasticsearch_heap_memory_percent" {
  description = "Elasticsearch heap size as a percent of system RAM"
  default     = "30"
}

## Launch Configuration settings

# Extra security groups to associate with the Elasticsearch nodes
variable "elasticsearch_node_extra_security_groups" {
  default = []
}

variable "elasticsearch_root_volume_size" {
  default = "8"
}

variable "elasticsearch_data_volume_size" {
  default = "300"
}

variable "elasticsearch_data_volume_type" {
  default = "gp2"
}

variable "elasticsearch_log_volume_size" {
  default = "5"
}

variable "elasticsearch_log_volume_type" {
  default = "gp2"
}

# AMI Settings

variable "ami_env_tag_filter" {
  default = "production"
}

# elasticsearch.yml settings

variable "elasticsearch_data_dir" {
  default = "/usr/local/var/data/elasticsearch"
}

variable "elasticsearch_log_dir" {
  default = "/usr/local/var/log/elasticsearch"
}

variable "es_allowed_urls" {
  description = "List of URLs to allow creating snapshot repositories from"
  default     = ""
}

variable "elasticsearch_fielddata_limit" {
  description = "fielddata circuit breaker limit"
  default     = "30%"
}

variable "elasticsearch_search_queue_size" {
  description = "the thread_pool queue size for searches. Defaults to ES default (1000) if unset"
  default     = ""
}

# disk based shard allocation filtering settings
# https://www.elastic.co/guide/en/elasticsearch/reference/current/disk-allocator.html
variable "elasticsearch_high_disk_watermark" {
  description = "Elasticsearch high disk watermark setting"
  default = ""
}

variable "elasticsearch_low_disk_watermark" {
  description = "Elasticsearch low disk watermark setting"
  default = ""
}

## snapshot loading settings
variable "snapshot_s3_bucket" {
  description = "The bucket where ES snapshots can be loaded from S3."
  default = ""
}

variable "snapshot_base_path" {
  description = "The path within the snapshot repository where the snapshot to load is found"
  default = ""
}

variable "snapshot_name" {
  description = "The name of the snapshot to load from S3. If blank, the first snapshot in the repository will be used"
  default = ""
}

variable "snapshot_alias_name" {
  description = "The alias to give to the loaded snapshot. None made if blank"
  default = ""
}

variable "snapshot_repository_read_only" {
  description = "Whether the snapshot repository is read_only. Default true"
  default = "true"
}

# General settings
variable "service_name" {
  description = "Used as a prefix for all instances in case you are running several distinct services"
  default     = "pelias"
}

variable "environment" {
  description = "Which environment (dev, staging, prod, etc) this group of machines is for"
  default     = "dev"
}

variable "tags" {
  description = "Custom tags to add to all resources"
  default     = {}
}

variable "elb" {
  description = "Whether or not to launch an ELB"
  default     = true
}
