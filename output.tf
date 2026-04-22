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