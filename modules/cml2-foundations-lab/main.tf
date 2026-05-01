#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

resource "random_password" "cisco_user" {
  length = 16
  # Keep the generated password copy-paste friendly from the CML console.
  # Exclude quoting/escape-prone chars; keep a handful of punctuation to
  # preserve entropy.
  special          = true
  override_special = "!@#%^&*_-+="
}

# Per-pod Ed25519 keypair for SSH'ing into the ubuntu-fuzzing VM as `cisco`.
# Ed25519 is preferred over RSA for new keys: smaller, faster, and immune to
# the ECDSA nonce-reuse class of bugs. Generated at apply time and injected
# via cloud-init (see authorized_keys below). The private key is surfaced as
# a sensitive output and is the *only* way to SSH in once we disable password
# auth in sshd.
resource "tls_private_key" "ubuntu_fuzzing" {
  algorithm = "ED25519"
}

locals {
  v4_name_server = "169.254.169.254" # GCP DNS
  v6_name_server = "2620:0:ccc::2"   # OpenDNS IPv6
  l0_prefix      = cidrsubnet(var.ip_prefix, 8, 1)
  l1_prefix      = cidrsubnet(var.ip_prefix, 8, 2)

  foundations_lab_notes = templatefile("${path.module}/templates/fuzzing-workshop-notes.md.tftpl", {
    domain_name = var.domain_name,
  })

  fuzzing_workshop_user_data = templatefile("${path.module}/templates/fuzzing-workshop.user-data.tftpl", {
    domain_name               = var.domain_name,
    v4_name_server            = local.v4_name_server,
    l0_prefix                 = local.l0_prefix,
    cisco_password            = random_password.cisco_user.result,
    cisco_public_key          = trimspace(tls_private_key.ubuntu_fuzzing.public_key_openssh),
    global_ipv4_address       = var.global_ipv4_address,
    global_ipv4_prefix_length = var.global_ipv4_prefix_length,
    bgp_ipv4_peer             = var.bgp_ipv4_peer,
    pod_number                = var.pod_number,
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

resource "cml2_node" "ubuntu-fuzzing" {
  lab_id          = cml2_lab.foundations_lab.id
  label           = "ubuntu-fuzzing"
  nodedefinition  = "ubuntu-fuzzing"
  imagedefinition = "ubuntu-fuzzing"
  ram             = 8192
  boot_disk_size  = 64
  x               = 80
  y               = 120
  tags            = ["host"]
  configurations = [
    {
      name    = "user-data"
      content = local.fuzzing_workshop_user_data
    }
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
  configuration = "bridge0"
}

resource "cml2_link" "l0" {
  lab_id = cml2_lab.foundations_lab.id
  node_a = cml2_node.ubuntu-fuzzing.id
  node_b = cml2_node.ext-conn-0.id
  slot_a = 0
  # external_connector ("Internet") only exposes a single port at slot 0.
  # Earlier copies of this file declared slot_b=1, which silently drifted
  # against reality (the controller had created the link at slot 0). Forcing
  # a link recreate exposed it as `Interface #1 label None is ...` from CML.
  slot_b = 0
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
    cml2_node.ubuntu-fuzzing,
    cml2_node.ext-conn-0
  ]
}
