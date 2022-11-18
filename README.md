# Example CTS module for AWS Security Groups

This is a Terraform Module to use with [Consul Terrraform Sync](https://developer.hashicorp.com/consul/tutorials/network-infrastructure-automation/consul-terraform-sync-intro) to create AWS security groups rules that open the ports of the services created or modified in Consul.

*This is a demo repo that is not Production ready*

WIP...

> NOTE: Services injected from CTS need to be using different ports. If they are using the same ports the LB listeners could fail because they are using same port for the LB. 