resource "aws_autoscaling_policy" "scale_down_single" {
  name                   = "elasticsearch-scale_downsingle"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.elasticsearch.name}"
}

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_description   = "Monitors CPU utilization for ElasticSearch Cluster Nodes"
  alarm_actions       = [aws_autoscaling_policy.scale_down_single.arn]
  alarm_name          = "elasticsearch-scale_up"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "${var.elasticsearch_scale_down_cpu_threshold}"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.elasticsearch.name}"
  }
}

resource "aws_autoscaling_policy" "scale_up_single" {
  name                   = "elasticsearch-scale_up_single"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.elasticsearch.name}"
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_description   = "Monitors CPU utilization for ElasticSearch Cluster Nodes"
  alarm_actions       = [aws_autoscaling_policy.scale_up_single.arn]
  alarm_name          = "elasticsearch-scale_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "${var.elasticsearch_scale_up_cpu_threshold}"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.elasticsearch.name}"
  }
}
resource "aws_autoscaling_group" "elasticsearch" {
  name                 = "${var.service_name}-${var.environment}-elasticsearch"
  max_size             = "${var.elasticsearch_max_instances}"
  min_size             = "${var.elasticsearch_min_instances}"
  desired_capacity     = "${var.elasticsearch_desired_instances}"
  default_cooldown     = 30
  force_delete         = true

  launch_template      = {
    id      = "${aws_launch_template.elasticsearch.id}"
    version = "$$Latest"
  }

  vpc_zone_identifier  = ["${data.aws_subnet_ids.all_subnets.ids}"]
  load_balancers       = ["${aws_elb.elasticsearch_elb.*.id}"]

  tag {
    key                 = "Name"
    value               = "${var.service_name}-${var.environment}-elasticsearch"
    propagate_at_launch = true
  }

  tag {
    key                 = "team"
    value               = "${var.service_name}"
    propagate_at_launch = true
  }

  tag {
    key   = "env"
    value = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [desired_capacity]
  }
}
