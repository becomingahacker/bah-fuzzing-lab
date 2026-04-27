---
title: Environment setup
permalink: /setup/
---

# Environment setup

Each pod gets one `ubuntu-fuzzing` VM provisioned by Terraform. The image
is baked with the workshop tooling so you can jump straight into the labs.

## Connecting

- **SSH**: use the per-pod Ed25519 private key from the Terraform output as
  the `cisco` user. The pod's public IPv4 address is also in the output.
- **Console**: from the CML workbench, open the `ubuntu-fuzzing` node's
  console. The desktop auto-logs in as `cisco` for VNC use.

Password auth is disabled in `sshd`. If you lose the key, you can still
add a new `authorized_keys` entry from the CML console and re-enable key
auth from there.

## Pre-installed tooling

The image ships with (non-exhaustive):

- `clang` / `clang++` with sanitizers (ASan, UBSan, MSan)
- `afl++` and `honggfuzz`
- `libfuzzer` headers/runtime
- `gdb`, `lldb`, `rr`
- Common build tooling: `cmake`, `ninja`, `make`, `pkg-config`

Run `which afl-fuzz clang++` to confirm.

## Where to next

- [Lab 1 — AFL++ basics]({{ '/labs/lab-01-afl-basics/' | relative_url }})
- [Back to home]({{ '/' | relative_url }})
