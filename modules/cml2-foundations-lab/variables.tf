#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

variable "title" {
  type        = string
  description = "Lab name"
}

variable "pod_number" {
  type        = number
  description = "Pod number"
}

variable "ip_prefix" {
  type        = string
  description = "IP prefix for the pod"
}

variable "global_ipv4_address" {
  type        = string
  description = "Global IP address for the pod"
}

variable "global_ipv4_netmask" {
  type        = string
  description = "Global IP netmask for the pod"
}

variable "global_ipv6_address" {
  type        = string
  description = "Global IPv6 address for the pod"
}

variable "global_ipv6_prefix_length" {
  type        = number
  description = "Global IPv6 prefix length for the pod"
}

variable "global_ipv6_prefix" {
  type        = string
  description = "Global IPv6 prefix for the pod"
}

variable "internet_mtu" {
  type        = number
  description = "Internet MTU for the pod"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the pod"
}

variable "bgp_ipv4_peer" {
  type        = string
  description = "BGP IPv4 peer address"
}

variable "bgp_ipv6_peer" {
  type        = string
  description = "BGP IPv6 peer address (of CML virbr1)"
}

# External TCP port the CML controller's PATty forwarder will expose for
# inbound SSH to this pod's ubuntu-fuzzing VM (mapped to the VM's tcp/22).
# Must be unique across all pods on the same controller and fall within the
# controller's PATty allowed range (default 2000-7999). Use a non-22 port to
# get past corporate egress filters that RST outbound SSH (e.g. Cisco's
# perimeter blocking tcp/22 to GCP).
variable "ssh_pat_external_port" {
  type        = number
  description = "External TCP port on the CML controller to forward to the ubuntu-fuzzing VM's tcp/22 via PATty"
  validation {
    condition     = var.ssh_pat_external_port >= 2000 && var.ssh_pat_external_port <= 7999
    error_message = "ssh_pat_external_port must be in CML's default PATty range (2000-7999)."
  }
}

# Public hostname (or IP) of the CML controller. Used purely to render a
# friendly `ssh ...` example in module outputs; PATty itself doesn't care.
variable "cml_controller_fqdn" {
  type        = string
  description = "Public FQDN or IP of the CML controller (for SSH-via-PATty output rendering)"
}
