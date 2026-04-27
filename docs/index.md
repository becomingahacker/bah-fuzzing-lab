---
title: Home
layout: page
---

# Becoming a Hacker — Fuzzing Workshop

Welcome. This site is the lab guide for the Becoming a Hacker fuzzing
workshop. The CML lab notes pane points here; bookmark this page for the
full set of modules.

Each lab runs on the per-pod `ubuntu-fuzzing` VM provisioned by Terraform
in your CML pod. SSH access is via the per-pod Ed25519 key shown in the
Terraform output; password auth is disabled.

## Lab modules

1. [Lab 1 — AFL++ basics]({{ '/labs/lab-01-afl-basics/' | relative_url }})
2. [Lab 2 — libFuzzer + sanitizers]({{ '/labs/lab-02-libfuzzer-sanitizers/' | relative_url }})

More modules will be added as the workshop curriculum grows.

## Before you start

- Confirm you can reach the per-pod VM via SSH using the Ed25519 key from
  your pod's Terraform output.
- Confirm the VM has Internet access (the lab's `external_connector`
  uplink should give you DNS and HTTPS out).
- Skim the [environment overview]({{ '/setup/' | relative_url }}) for the
  tooling pre-installed on the image.

## Reporting issues

Found a bug or unclear instruction? File an issue on the
[bah-fuzzing-lab repo](https://github.com/becomingahacker/bah-fuzzing-lab/issues)
and tag the lab number.
