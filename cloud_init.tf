data "template_file" "setup" {
  template = "${file("${path.module}/templates/setup.sh.tpl")}"

  vars {
    elasticsearch_data_dir            = "${var.elasticsearch_data_dir}"
    elasticsearch_log_dir             = "${var.elasticsearch_log_dir}"
    es_cluster_name                   = "${var.service_name}-${var.environment}-elasticsearch"
    es_allowed_urls                   = "${var.es_allowed_urls}"
    aws_security_group                = "${aws_security_group.elasticsearch.id}"
    aws_region                        = "${var.aws_region}"
    availability_zones                = "${var.availability_zones}"
    expected_nodes                    = "${var.elasticsearch_desired_instances}"
    elasticsearch_heap_memory_percent = "${var.elasticsearch_heap_memory_percent}"
    elasticsearch_fielddata_limit     = "${var.elasticsearch_fielddata_limit}"
    elasticsearch_search_queue_size   = "${var.elasticsearch_search_queue_size}"
    allocation_awareness_attributes   = "${var.allocation_awareness_attributes}"
    elasticsearch_wait_retry_count    = "${var.elasticsearch_wait_retry_count}"
    elasticsearch_wait_retry_timeout  = "${var.elasticsearch_wait_retry_timeout}"
  }
}

data "template_file" "load_snapshot" {
  template = "${file("${path.module}/templates/load_snapshot.sh.tpl")}"

  vars {
    snapshot_s3_bucket = "${var.snapshot_s3_bucket}"
    snapshot_base_path = "${var.snapshot_base_path}"
    snapshot_name = "${var.snapshot_name}"
    snapshot_replica_count = "${var.snapshot_replica_count}"
    snapshot_alias_name = "${var.snapshot_alias_name}"
    snapshot_repository_read_only = "${var.snapshot_repository_read_only}"
    high_disk_watermark               = "${var.elasticsearch_high_disk_watermark}"
    low_disk_watermark               = "${var.elasticsearch_low_disk_watermark}"
    elasticsearch_delayed_allocation  = "${var.elasticsearch_delayed_allocation}"
  }
}

data "template_cloudinit_config" "cloud_init" {
  gzip = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.setup.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.load_snapshot.rendered}"
  }
}
