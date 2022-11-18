# output "instance" {
#   value = {for ip,s in var.services : ip => "${data.aws_instance.app[ip].public_ip}:${s.port}"}
# }

# output "app_lb" {
#   value = {for ip,s in var.services : ip => "${aws_lb.app_http.dns_name}:${s.port}"}
# }

# output "sg" {
#   value = { for ip,s in var.services : ip => element(tolist(data.aws_network_interface.instance[ip].security_groups),0) }
# }

# output "test" {
#   value = flatten([ for s in data.aws_subnet_ids.app : s.ids ])
# }