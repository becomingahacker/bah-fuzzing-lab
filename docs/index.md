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

## Workshop schedule

The workshop runs over two days. Each day has its own set of exercises;
follow them in order.

### [Day 1 — Fuzzing fundamentals]({{ '/day-1/' | relative_url }})

1. [Exercise 1 — AFL++ basics]({{ '/day-1/01-afl-basics/' | relative_url }})
2. [Exercise 2 — libFuzzer + sanitizers]({{ '/day-1/02-libfuzzer-sanitizers/' | relative_url }})

### [Day 2 — Going deeper]({{ '/day-2/' | relative_url }})

1. [Exercise 1 — Structure-aware fuzzing]({{ '/day-2/01-structure-aware-fuzzing/' | relative_url }})
2. [Exercise 2 — Harnessing & triaging a real target]({{ '/day-2/02-real-target-triage/' | relative_url }})

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
and tag the day + exercise number.
