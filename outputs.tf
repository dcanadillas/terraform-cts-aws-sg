output "instance" {
  value = {for ip,s in var.services : ip => "${data.aws_instance.app[ip].public_ip}:${s.port}"}
}

# output "sg" {
#   value = { for ip,s in var.services : ip => element(tolist(data.aws_network_interface.instance[ip].security_groups),0) }
# }
