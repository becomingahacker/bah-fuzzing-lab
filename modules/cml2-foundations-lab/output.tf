#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

output "lab_id" {
  value = cml2_lab.foundations_lab.id
}

# Password for the `cisco` user on the ubuntu-fuzzing node. Generated at apply
# time and injected via cloud-init user-data. Marked sensitive so it is not
# echoed in plan/apply output; retrieve with:
#   tofu output -json cisco_credentials
output "cisco_password" {
  value     = random_password.cisco_user.result
  sensitive = true
}

output "cisco_username" {
  value = "cisco"
}

# Per-pod Ed25519 SSH keypair for the ubuntu-fuzzing VM's `cisco` user. The
# public key is installed via cloud-init authorized_keys (see
# `fuzzing-workshop.user-data.tftpl`); the private key is the only way to
# SSH in once `PasswordAuthentication no` takes effect. Treat the private
# key like any other secret: keep it in tfstate (already access-controlled
# by the GCS backend), or write it out with restrictive perms and remove
# from the working copy after use.
output "cisco_ssh_private_key_openssh" {
  value     = tls_private_key.ubuntu_fuzzing.private_key_openssh
  sensitive = true
}

output "cisco_ssh_public_key_openssh" {
  value = trimspace(tls_private_key.ubuntu_fuzzing.public_key_openssh)
}

output "cisco_ssh_public_key_fingerprint_sha256" {
  value = tls_private_key.ubuntu_fuzzing.public_key_fingerprint_sha256
}

# SSH endpoint info for the ubuntu-fuzzing VM. We now route the per-pod
# /32 (`var.global_ipv4_address`) directly to the VM and SSH on tcp/22, so
# there's no PATty hop for SSH anymore. (The PATty tag on the node and
# `var.ssh_pat_external_port` are kept for now as a fallback path; remove
# once the BGP-advertised /32 path has been validated end-to-end.)
#
# The rendered `command` points at a per-pod private-key path that the
# operator is expected to write the private key to (see
# `ubuntu_fuzzing_ssh_private_keys` at the root); we don't materialize the
# key on disk from Terraform to avoid leaking it into the working tree.
output "ssh_endpoint" {
  value = {
    host             = var.global_ipv4_address
    port             = 22
    user             = "cisco"
    private_key_path = "~/.ssh/bah-fuzzing-pod${var.pod_number}_ed25519"
    # `IdentitiesOnly=yes` is required so ssh doesn't pre-offer every key
    # loaded in the operator's ssh-agent before the pod-specific key. The
    # pod's sshd is hardened with `MaxAuthTries 3`, so an agent holding
    # three unrelated keys would get disconnected for "Too many
    # authentication failures" before the right key was ever tried.
    command = "ssh -o IdentitiesOnly=yes -i ~/.ssh/bah-fuzzing-pod${var.pod_number}_ed25519 cisco@${var.global_ipv4_address}"
  }
}
