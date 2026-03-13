#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

locals {
  v4_name_server = "169.254.169.254" # GCP DNS
  v6_name_server = "2620:0:ccc::2"   # OpenDNS IPv6
  l0_prefix      = cidrsubnet(var.ip_prefix, 8, 1)
  l1_prefix      = cidrsubnet(var.ip_prefix, 8, 2)

  foundations_lab_notes = templatefile("${path.module}/templates/fuzzing-workshop-notes.md.tftpl", {
    domain_name = var.domain_name,
  })

  fuzzing_workshop_user_data = templatefile("${path.module}/templates/fuzzing-workshop.user-data.tftpl", {
    domain_name    = var.domain_name,
    v4_name_server = local.v4_name_server,
    l0_prefix      = local.l0_prefix,
  })

  fuzzing_workshop_network_config = templatefile("${path.module}/templates/fuzzing-workshop.network-config.tftpl", {
    domain_name    = var.domain_name,
    v4_name_server = local.v4_name_server,
    l0_prefix      = local.l0_prefix,
  })
}

resource "cml2_lab" "foundations_lab" {
  title       = var.title
  description = "Hands-On Fuzzing Workshop"
  notes       = local.foundations_lab_notes
}

resource "cml2_node" "kali" {
  lab_id         = cml2_lab.foundations_lab.id
  label          = "ubuntu-fuzzing"
  nodedefinition = "ubuntu-fuzzing"
  imagedefinition = "ubuntu-fuzzing"
  ram            = 8192
  boot_disk_size = 64
  x              = 80
  y              = 120
  tags           = ["host"]
  configurations = [
    {
      name    = "user-data"
      content = local.fuzzing_workshop_user_data
    },
    {
      name    = "network-config"
      content = local.fuzzing_workshop_network_config
    },
  ]
}

resource "cml2_node" "ext-conn-0" {
  lab_id         = cml2_lab.foundations_lab.id
  label          = "Internet"
  nodedefinition = "external_connector"
  ram            = null
  x              = 680
  y              = 120
  tags           = ["external_connector"]
  configuration  = "virbr1"
}

resource "cml2_lifecycle" "top" {
  lab_id = cml2_lab.foundations_lab.id


  staging = {
    stages          = ["external_connector", "network", "host"]
    start_remaining = true
  }

  # Start in order, according to stages
  #state = "STARTED"
  state = "DEFINED_ON_CORE"

  lifecycle {
    ignore_changes = [
      state
    ]
  }

  depends_on = [
    cml2_node.kali,
    cml2_node.ext-conn-0
  ]
}
