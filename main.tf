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

locals {
  consul_service_ids = transpose({
    for id, s in var.services : id => [s.name]
  })
  consul_services = {
    for name, ids in local.consul_service_ids : name => [for id in ids : var.services[id]]
  }
  service_addresses = [ for s in var.services : s.address ]
}



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

# We get all the subnets for the vpcs from the instances running with the services. This will be used for the ALB
data "aws_subnet_ids" "app" {
  for_each = var.services
  vpc_id = data.aws_subnet.subnet[each.key].vpc_id 
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

resource "aws_security_group_rule" "lb" {
  for_each = toset(flatten([ for s in data.aws_instance.app : s.vpc_security_group_ids]))
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  # security_group_id = aws_security_group.apps[each.key].id
  security_group_id = each.key

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


## Creating a LB for the instance of the service

# resource "aws_lb" "app" {
#   name               = "app-lb"
#   internal           = false
#   load_balancer_type = "network"
#   subnets            = [ for s in data.aws_instance.app : s.subnet_id ]
#   # security_groups    = [aws_security_group.load_balancer.id] # For an application load balancer

#   # enable_deletion_protection = true

#   tags = {
#     Name = "Application Load Balancer"
#   }
# }


# resource "aws_lb_listener" "app" {
#   for_each = var.services
#   load_balancer_arn = aws_lb.app.arn
#   port              = each.value.port
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app[each.key].arn
#   }
# }

# resource "aws_lb_target_group" "app" {
#   for_each = var.services
#   name     = "app-tg-${each.key}"
#   port     = each.value.port
#   protocol = "TCP"
#   vpc_id   = data.aws_subnet.subnet[each.key].vpc_id
# }

# resource "aws_lb_target_group_attachment" "test" {
#   for_each = var.services
#   target_group_arn = aws_lb_target_group.app[each.key].arn
#   target_id        = data.aws_instance.app[each.key].id
#   port             = each.value.port
# }


# ## Load Balancer HTTP
resource "aws_lb" "app_http" {
  name_prefix               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = distinct(flatten([ for s in data.aws_subnet_ids.app : s.ids ]))
  security_groups    = flatten([ for s in data.aws_instance.app : s.vpc_security_group_ids]) # For an application load balancer

  # enable_deletion_protection = true

  tags = {
    Name = "Application Load Balancer"
  }
}

resource "aws_lb_listener" "app" {
  for_each = var.services
  load_balancer_arn = aws_lb.app_http.arn
  port              = each.value.port
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
  # lifecycle {
  #   # The port of the listener must not exist.
  #   precondition {
  #     condition     = data.aws_lb_listener.existing[each.key].port == each.value.port
  #     error_message = "Listener port is already configured for this LB"
  #   }
  # }
}

resource "aws_lb_target_group" "app" {
  for_each = var.services
  name     = "app-tg-${each.value.name}"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = data.aws_subnet.subnet[each.key].vpc_id
}

resource "aws_lb_target_group_attachment" "test" {
  for_each = var.services
  target_group_arn = aws_lb_target_group.app[each.key].arn
  target_id        = data.aws_instance.app[each.key].id
  port             = each.value.port
}

output "instance" {
  value = {for ip,s in var.services : ip => "${data.aws_instance.app[ip].public_ip}:${s.port}"}
}

output "app_lb" {
  value = {for ip,s in var.services : ip => "${aws_lb.app_http.dns_name}:${s.port}"}
}