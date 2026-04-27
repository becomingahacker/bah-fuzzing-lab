#
# This file is part of Becoming a Hacker Foundations
# Copyright (c) 2024, Cisco Systems, Inc.
# All rights reserved.
#

output "cml_credentials" {
  value     = { for user in module.user : user.username => user.password }
  sensitive = true
}

# Per-pod credentials for the `cisco` user on the ubuntu-fuzzing VM.
# Keyed by pod number (1-based) to match the pod layout in main.tf.
# Retrieve with:
#   tofu output -json ubuntu_fuzzing_credentials
#   tofu output -raw -json ubuntu_fuzzing_credentials | jq -r '.["1"].password'
output "ubuntu_fuzzing_credentials" {
  value = {
    for idx, pod in module.pod :
    tostring(idx + 1) => {
      username = pod.cisco_username
      password = pod.cisco_password
    }
  }
  sensitive = true
}

# Per-pod direct-to-VM SSH endpoints for the ubuntu-fuzzing VM. Each entry
# maps pod number (1-based) to the host (the per-pod /32 advertised over
# BGP), tcp/22, and a ready-to-paste `ssh` command that references the
# per-pod private key written to `~/.ssh/bah-fuzzing-pod<N>_ed25519`.
# Materialize the keys with `ubuntu_fuzzing_ssh_private_keys` below.
# Retrieve:
#   tofu output -json ubuntu_fuzzing_ssh
#   tofu output -json ubuntu_fuzzing_ssh | jq -r '.["1"].command'
output "ubuntu_fuzzing_ssh" {
  value = {
    for idx, pod in module.pod :
    tostring(idx + 1) => pod.ssh_endpoint
  }
}

# Per-pod Ed25519 SSH private keys (OpenSSH PEM) for the ubuntu-fuzzing
# VM's `cisco` user. SSH password auth is disabled on the VM, so this is
# the only way in over the PATty-exposed public path. Keys are generated
# fresh on every `tofu apply` that recreates the module instance, mirroring
# the existing password-regeneration behavior; rotate students' workstation
# copies accordingly.
#
# Materialize a single pod's key with restrictive permissions:
#   umask 077 && tofu output -json ubuntu_fuzzing_ssh_private_keys \
#     | jq -r '.["1"]' > ~/.ssh/bah-fuzzing-pod1_ed25519
#
# Or all of them at once:
#   umask 077 && tofu output -json ubuntu_fuzzing_ssh_private_keys \
#     | jq -r 'to_entries[] | "\(.key)\t\(.value)"' \
#     | while IFS=$'\t' read -r pod key; do
#         printf '%s' "$key" > ~/.ssh/bah-fuzzing-pod${pod}_ed25519
#       done
output "ubuntu_fuzzing_ssh_private_keys" {
  value = {
    for idx, pod in module.pod :
    tostring(idx + 1) => pod.cisco_ssh_private_key_openssh
  }
  sensitive = true
}

# Per-pod Ed25519 public keys (OpenSSH single-line format) and SHA-256
# fingerprints. Useful for verifying the host you're about to SSH to, or
# for sharing with another tool that expects the public half. Non-sensitive.
output "ubuntu_fuzzing_ssh_public_keys" {
  value = {
    for idx, pod in module.pod :
    tostring(idx + 1) => {
      public_key  = pod.cisco_ssh_public_key_openssh
      fingerprint = pod.cisco_ssh_public_key_fingerprint_sha256
    }
  }
}