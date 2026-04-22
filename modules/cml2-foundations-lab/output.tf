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
