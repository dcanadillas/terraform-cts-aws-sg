terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.38.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# locals {
#   consul_service_ids = transpose({
#     for id, s in var.services : id => [s.name]
#   })
#   consul_services = {
#     for name, ids in local.consul_service_ids : name => [for id in ids : var.services[id]]
#   }
# }

data "aws_instance" "app" {
  for_each = var.services
  filter {
    name   = "private-ip-address"
    values = [each.value.node_address]
  }
}

data "aws_subnet" "subnet" {
  for_each = data.aws_instance.app
  id = each.value.subnet_id
}


data "aws_network_interface" "instance" {
  for_each = data.aws_instance.app
  id = data.aws_instance.app[each.key].network_interface_id
}

# resource "aws_security_group" "apps" {
#   for_each = data.aws_subnet.subnet
#   name = "cts-app-example-${each.value.vpc_id}"
#   vpc_id = each.value.vpc_id
#   tags = {
#     "Name" = "allow service"
#   }
# }


resource "aws_security_group_rule" "app" {
  for_each = var.services
  type              = "ingress"
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # security_group_id = aws_security_group.apps[each.key].id
  security_group_id = element(tolist(data.aws_network_interface.instance[each.key].security_groups),0)

}

# resource "aws_security_group_rule" "app_outbound" {
#   for_each = var.services
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   # security_group_id = aws_security_group.apps[each.key].id
#   security_group_id = element(data.aws_network_interface.instance[each.key].security_groups,0)
# }


