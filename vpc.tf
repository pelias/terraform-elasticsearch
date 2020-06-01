# get all subnets from the VPC
# this is used when creating ELBs and ASGs
data "aws_subnet_ids" "all_subnets" {
  vpc_id = "${var.aws_vpc_id}"

  filter {
    name = "${var.subnet_name_filter_property}"
    values = ["${var.subnet_name_filter}"]
  }
}
