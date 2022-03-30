data "template_file" "setup" {
  template = "${file("${path.module}/templates/setup.sh.tpl")}"

  vars {
    elasticsearch_data_dir            = "${var.elasticsearch_data_dir}"
    elasticsearch_log_dir             = "${var.elasticsearch_log_dir}"
    es_cluster_name                   = "${var.service_name}-${var.environment}-elasticsearch"
    es_allowed_urls                   = "${var.es_allowed_urls}"
    elasticsearch_heap_memory_percent = "${var.elasticsearch_heap_memory_percent}"
    elasticsearch_fielddata_limit     = "${var.elasticsearch_fielddata_limit}"
    elasticsearch_search_queue_size   = "${var.elasticsearch_search_queue_size}"
  }
}

data "template_file" "load_snapshot" {
  template = "${file("${path.module}/templates/load_snapshot.sh.tpl")}"

  vars {
    snapshot_s3_bucket = "${var.snapshot_s3_bucket}"
    snapshot_base_path = "${var.snapshot_base_path}"
    snapshot_name = "${var.snapshot_name}"
    snapshot_alias_name = "${var.snapshot_alias_name}"
    snapshot_repository_read_only = "${var.snapshot_repository_read_only}"
    high_disk_watermark               = "${var.elasticsearch_high_disk_watermark}"
    low_disk_watermark               = "${var.elasticsearch_low_disk_watermark}"
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
