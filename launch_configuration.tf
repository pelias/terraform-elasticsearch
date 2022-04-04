resource "aws_launch_template" "elasticsearch" {
  name_prefix                 = "${var.service_name}-${var.environment}-elasticsearch-"
  image_id                    = "${data.aws_ami.elasticsearch_ami.id}"
  instance_type               = "${var.elasticsearch_instance_type}"
  # TODO(joe.thompson): Update this to correctly pull values without using list.
  vpc_security_group_ids      = ["${compact(concat(list(aws_security_group.elasticsearch.id), var.elasticsearch_node_extra_security_groups))}"]

  key_name             = "${var.ssh_key_name}"
  user_data            = "${data.template_cloudinit_config.cloud_init.rendered}"
  iam_instance_profile {
    arn = "${aws_iam_instance_profile.elasticsearch.arn}"
  }

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size = "${var.elasticsearch_data_volume_size}"
      volume_type = "${var.elasticsearch_data_volume_type}"
    }
  }
  block_device_mappings {
    device_name = "/dev/sdc"
    ebs {
      volume_size = "${var.elasticsearch_log_volume_size}"
      volume_type = "${var.elasticsearch_log_volume_type}"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = "${var.tags}"
  }
}

