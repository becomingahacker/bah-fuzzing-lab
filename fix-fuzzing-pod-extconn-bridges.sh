#!/usr/bin/env bash
#
# fix-fuzzing-pod-extconn-bridges.sh
#
# Repair the per-pod `Internet` (`ext-conn-0`) external_connector node so
# its `configuration` matches the form the CML UI itself sends, namely a
# named-config wrapper around the device name (`virbr1`):
#
#     {"configuration":[{"name":"default","content":"virbr1"}]}
#
# When you'd run this
# -------------------
# After `tofu apply` against the cml2 provider v0.8.3..v0.9.0-beta3
# series. Those versions ship a normalizer (internal/provider/resource/
# node/extconn_normalize.go) that rewrites a device name like "virbr1"
# into the connector *label* "NAT 1" before posting to the controller.
# CML's controller, however, persists external_connector configurations
# as named-configs (`[{"name":"default","content":"<device>"}]`), and on
# this deployment it resolves them by *device name*, not by label. Result
# of the normalizer mismatch is `[{"name":"default","content":"NAT 1"}]`
# stored on the node, which the UI then renders as
#
#     NAT 1: (non-existent)
#
# even though a healthy `NAT 1: (virbr1)` connector exists on the host.
# The lab "starts" but the fabric never wires the per-pod /32 onto a real
# bridge, BGP doesn't peer, and outbound Internet from the pod's
# ubuntu-fuzzing VM is dead.
#
# This script reproduces, in bulk, the manual fix observed when the CML
# UI's "Connector Selection" dropdown is reset to `NAT 1: (virbr1)`:
#
#   1. PATCH the node's `configuration` to the canonical named-config form.
#   2. Bounce the lab (stop -> start) so the fabric service rebuilds the
#      veth against the now-correct bridge. The link is wired at
#      lab-start time, so the PATCH alone is invisible to a running lab.
#
# The matching Terraform-side change (so the next `tofu apply` does not
# re-flip the node back to the broken value) is to add
#
#     lifecycle { ignore_changes = [configuration] }
#
# to `cml2_node.ext-conn-0` in modules/cml2-foundations-lab/main.tf.
#
# Safety properties
# -----------------
# * Defaults to a dry-run that prints, per matched lab, the current
#   `configuration` value, the current state, and exactly what the
#   script would do. You must pass `--apply` to actually PATCH/stop/start.
# * `--apply` also prompts for typed confirmation (`FIX`).
# * Skips any lab whose `ext-conn-0` already has the canonical form.
#   That makes it safe to re-run.
# * Restores each lab's *original* run state (STARTED stays STARTED,
#   STOPPED stays STOPPED, DEFINED_ON_CORE stays DEFINED_ON_CORE) unless
#   you pass --leave-stopped.
# * Bails on any HTTP error; never logs admin password or bearer tokens.
#
# Usage
# -----
#   source .envrc                                  # if you don't use direnv
#   ./fix-fuzzing-pod-extconn-bridges.sh                # dry run
#   ./fix-fuzzing-pod-extconn-bridges.sh --apply        # actually PATCH + bounce
#
# Optional flags:
#   --lab-pattern    REGEX   override lab title regex (default: ^OS2026 Fuzzing Workshop - [0-9]+$)
#   --device         NAME    target device name to set (default: virbr1)
#   --leave-stopped          do NOT restart labs that this script stops to apply the fix
#   --no-bounce              PATCH only; do not stop/start any lab (you must bounce later)
#   --converge-timeout SECS  per-lab timeout waiting for STOPPED/STARTED (default: 240)
#   --config         FILE    path to config.yml (default: ./config.yml)
#
# Notes
# -----
# * Runs serially. 14 pods at ~60s stop + ~90s start ~= 35 min wallclock.
# * Idempotent: re-running after a successful pass is a no-op.
#

set -Eeuo pipefail

# ---------- defaults / args ----------
APPLY=0
CONFIG_FILE="config.yml"
LAB_PATTERN='^OS2026 Fuzzing Workshop - [0-9]+$'
TARGET_DEVICE="virbr1"
LEAVE_STOPPED=0
NO_BOUNCE=0
CONVERGE_TIMEOUT=240

while (( $# )); do
  case "$1" in
    --apply)             APPLY=1 ;;
    --lab-pattern)       LAB_PATTERN="$2"; shift ;;
    --device)            TARGET_DEVICE="$2"; shift ;;
    --leave-stopped)     LEAVE_STOPPED=1 ;;
    --no-bounce)         NO_BOUNCE=1 ;;
    --converge-timeout)  CONVERGE_TIMEOUT="$2"; shift ;;
    --config)            CONFIG_FILE="$2"; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---------- preflight ----------
for tool in conjur jq curl python3; do
  command -v "$tool" >/dev/null 2>&1 \
    || { echo "ERROR: '$tool' not on PATH" >&2; exit 2; }
done

[[ -r "$CONFIG_FILE" ]] || { echo "ERROR: cannot read $CONFIG_FILE" >&2; exit 2; }
[[ -n "${TF_VAR_proxy_token:-}" ]] \
  || { echo "ERROR: TF_VAR_proxy_token is empty (source .envrc?)" >&2; exit 2; }

# ---------- read config.yml ----------
read -r CML_URL SECRET_MANAGER CML_USERNAME CML_PASSWORD_PATH <<<"$(
  python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
mgr = (cfg.get("secret") or {}).get("manager")
app = ((cfg.get("secret") or {}).get("secrets") or {}).get("app") or {}
url = "https://" + (cfg.get("lb_fqdn") or "").strip()
print(url, mgr, app.get("username", ""), app.get("path", ""))
PY
)"

[[ "$SECRET_MANAGER" == "conjur" ]] \
  || { echo "ERROR: this script only handles secret.manager=conjur (found: $SECRET_MANAGER)" >&2; exit 2; }
[[ -n "$CML_USERNAME" && -n "$CML_PASSWORD_PATH" ]] \
  || { echo "ERROR: missing secrets.app.username or .path in $CONFIG_FILE" >&2; exit 2; }

# ---------- fetch admin password from Conjur ----------
CML_PASSWORD="$(conjur variable get -i "$CML_PASSWORD_PATH")"
[[ -n "$CML_PASSWORD" ]] || { echo "ERROR: empty admin password from Conjur" >&2; exit 2; }

# ---------- shared curl helpers ----------
CURL_BASE=(curl -sS --fail-with-body
            -H "Proxy-Authorization: Bearer ${TF_VAR_proxy_token}"
            -H "Content-Type: application/json")

# ---------- authenticate to CML ----------
TOKEN_RAW="$("${CURL_BASE[@]}" -X POST "${CML_URL}/api/v0/authenticate" \
  --data "$(jq -n --arg u "$CML_USERNAME" --arg p "$CML_PASSWORD" \
           '{username:$u, password:$p}')")"
CML_TOKEN="$(printf '%s' "$TOKEN_RAW" | jq -r 'if type=="string" then . else .token // empty end')"
[[ -n "$CML_TOKEN" ]] || { echo "ERROR: did not get a CML token from /authenticate" >&2; exit 2; }

CURL_AUTH=("${CURL_BASE[@]}" -H "Authorization: Bearer ${CML_TOKEN}")

# ---------- canonical configuration we want on every ext-conn-0 ----------
# Matches the body the CML UI sends when you change the connector selection
# from the dropdown:
#
#   {"configuration":[{"name":"default","content":"virbr1"}]}
#
CANONICAL_CONFIG_JSON="$(jq -nc --arg dev "$TARGET_DEVICE" \
  '{configuration: [{name:"default", content:$dev}]}')"
EXPECTED_CONFIG_VALUE="$(jq -nc --arg dev "$TARGET_DEVICE" \
  '[{name:"default", content:$dev}]')"

# ---------- discover labs ----------
# /api/v0/labs?show_all=true returns a flat array of UUID strings; we have
# to GET each one to read its title/state. Cheap on a few-dozen-lab
# controller.
ALL_LAB_IDS_JSON="$("${CURL_AUTH[@]}" "${CML_URL}/api/v0/labs?show_all=true")"

declare -a TARGET_LAB_IDS=()
declare -A LAB_TITLE=()
declare -A LAB_STATE=()

for lab_id in $(jq -r '.[]' <<<"$ALL_LAB_IDS_JSON"); do
  lab_json="$("${CURL_AUTH[@]}" "${CML_URL}/api/v0/labs/${lab_id}")"
  title="$(jq -r '.lab_title // .title // empty' <<<"$lab_json")"
  state="$(jq -r '.state // empty' <<<"$lab_json")"
  if [[ -n "$title" ]] && [[ "$title" =~ $LAB_PATTERN ]]; then
    TARGET_LAB_IDS+=("$lab_id")
    LAB_TITLE["$lab_id"]="$title"
    LAB_STATE["$lab_id"]="$state"
  fi
done

if (( ${#TARGET_LAB_IDS[@]} == 0 )); then
  echo "No labs matched lab-pattern: ${LAB_PATTERN}"
  exit 0
fi

# ---------- helpers ----------
# Find the ext-conn-0 node (label "Internet" or node_definition
# "external_connector") in a lab. Echos node_id on stdout, empty if none.
find_ext_conn_node() {
  local lab_id="$1"
  "${CURL_AUTH[@]}" "${CML_URL}/api/v0/labs/${lab_id}/nodes?data=true" \
    | jq -r '
        (if type=="array" then . else .nodes // [] end)
        | map(select(.node_definition=="external_connector"))
        | .[0].id // empty
      '
}

# Echos the current `configuration` of a node as compact JSON.
get_node_config() {
  local lab_id="$1" node_id="$2"
  "${CURL_AUTH[@]}" "${CML_URL}/api/v0/labs/${lab_id}/nodes/${node_id}?data=true" \
    | jq -c '.configuration'
}

# Echos the current lab state.
get_lab_state() {
  local lab_id="$1"
  "${CURL_AUTH[@]}" "${CML_URL}/api/v0/labs/${lab_id}" | jq -r '.state // empty'
}

# Wait until lab state matches expected (or any of the expected values
# space-separated). Times out per --converge-timeout.
wait_lab_state() {
  local lab_id="$1"; shift
  local -a wanted=("$@")
  local elapsed=0 cur=""
  while (( elapsed < CONVERGE_TIMEOUT )); do
    cur="$(get_lab_state "$lab_id")"
    for w in "${wanted[@]}"; do
      if [[ "$cur" == "$w" ]]; then
        return 0
      fi
    done
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "ERROR: lab ${lab_id} (${LAB_TITLE[$lab_id]}) did not reach state {${wanted[*]}} within ${CONVERGE_TIMEOUT}s (last seen: ${cur})" >&2
  return 1
}

stop_lab() {
  local lab_id="$1"
  # Newer endpoint first, then legacy fallback (matches gocmlclient).
  "${CURL_AUTH[@]}" -X PUT "${CML_URL}/api/v0/labs/${lab_id}/stop" >/dev/null 2>/dev/null \
    || "${CURL_AUTH[@]}" -X PUT "${CML_URL}/api/v0/labs/${lab_id}/state/stop" >/dev/null
}

start_lab() {
  local lab_id="$1"
  "${CURL_AUTH[@]}" -X PUT "${CML_URL}/api/v0/labs/${lab_id}/start" >/dev/null 2>/dev/null \
    || "${CURL_AUTH[@]}" -X PUT "${CML_URL}/api/v0/labs/${lab_id}/state/start" >/dev/null
}

patch_node_config() {
  local lab_id="$1" node_id="$2"
  "${CURL_AUTH[@]}" -X PATCH "${CML_URL}/api/v0/labs/${lab_id}/nodes/${node_id}" \
    --data "${CANONICAL_CONFIG_JSON}" >/dev/null
}

# ---------- plan & report ----------
# Build a per-lab decision table before doing any writes.
declare -A LAB_NODE=()
declare -A LAB_CURCFG=()
declare -A LAB_ACTION=()   # "skip" | "patch_only" | "patch_bounce"

for lab_id in "${TARGET_LAB_IDS[@]}"; do
  node_id="$(find_ext_conn_node "$lab_id" || true)"
  if [[ -z "$node_id" ]]; then
    LAB_ACTION["$lab_id"]="skip-no-node"
    continue
  fi
  LAB_NODE["$lab_id"]="$node_id"
  cur_cfg="$(get_node_config "$lab_id" "$node_id")"
  LAB_CURCFG["$lab_id"]="$cur_cfg"
  if [[ "$cur_cfg" == "$EXPECTED_CONFIG_VALUE" ]]; then
    LAB_ACTION["$lab_id"]="skip-already-fixed"
  else
    if (( NO_BOUNCE == 1 )); then
      LAB_ACTION["$lab_id"]="patch_only"
    else
      LAB_ACTION["$lab_id"]="patch_bounce"
    fi
  fi
done

echo "Discovered ${#TARGET_LAB_IDS[@]} lab(s) matching '${LAB_PATTERN}':"
echo
printf '  %-38s %-38s %-18s %-18s %s\n' "LAB ID" "TITLE" "STATE" "ACTION" "CURRENT configuration"
printf '  %-38s %-38s %-18s %-18s %s\n' "$(printf '%*s' 38 | tr ' ' '-')" "$(printf '%*s' 38 | tr ' ' '-')" "$(printf '%*s' 18 | tr ' ' '-')" "$(printf '%*s' 18 | tr ' ' '-')" "$(printf '%*s' 40 | tr ' ' '-')"
for lab_id in "${TARGET_LAB_IDS[@]}"; do
  printf '  %-38s %-38s %-18s %-18s %s\n' \
    "$lab_id" \
    "${LAB_TITLE[$lab_id]:0:38}" \
    "${LAB_STATE[$lab_id]:-?}" \
    "${LAB_ACTION[$lab_id]}" \
    "${LAB_CURCFG[$lab_id]:-(no node)}"
done
echo

# ---------- dry-run gate ----------
n_to_fix=0
for lab_id in "${TARGET_LAB_IDS[@]}"; do
  case "${LAB_ACTION[$lab_id]}" in
    patch_only|patch_bounce) n_to_fix=$((n_to_fix + 1)) ;;
  esac
done

if (( n_to_fix == 0 )); then
  echo "Nothing to do."
  exit 0
fi

if (( APPLY == 0 )); then
  echo "(dry run) ${n_to_fix} lab(s) would be patched. Re-run with --apply to execute."
  exit 0
fi

prompt_suffix=""
(( NO_BOUNCE == 0 )) && prompt_suffix=" (with stop/start)"
read -r -p "Type FIX to confirm patching ${n_to_fix} lab(s)${prompt_suffix}: " ans
[[ "$ans" == "FIX" ]] || { echo "Aborted."; exit 1; }

# ---------- execute ----------
fail=0

for lab_id in "${TARGET_LAB_IDS[@]}"; do
  action="${LAB_ACTION[$lab_id]}"
  title="${LAB_TITLE[$lab_id]}"
  node_id="${LAB_NODE[$lab_id]:-}"
  start_state="${LAB_STATE[$lab_id]:-DEFINED_ON_CORE}"

  case "$action" in
    skip-no-node)
      echo "[${title}] no external_connector node found -- skipping"
      continue
      ;;
    skip-already-fixed)
      echo "[${title}] already canonical -- skipping"
      continue
      ;;
    patch_only)
      echo "[${title}] PATCH only (no-bounce mode)"
      if ! patch_node_config "$lab_id" "$node_id"; then
        echo "  ERROR: PATCH failed" >&2
        fail=$((fail + 1))
        continue
      fi
      ;;
    patch_bounce)
      echo "[${title}] starting state: ${start_state}"
      if [[ "$start_state" == "STARTED" || "$start_state" == "QUEUED" || "$start_state" == "BOOTED" ]]; then
        echo "  stopping lab..."
        if ! stop_lab "$lab_id"; then
          echo "  ERROR: stop call failed" >&2
          fail=$((fail + 1))
          continue
        fi
        if ! wait_lab_state "$lab_id" "STOPPED" "DEFINED_ON_CORE"; then
          fail=$((fail + 1))
          continue
        fi
      fi
      echo "  patching ext-conn-0 (${node_id})..."
      if ! patch_node_config "$lab_id" "$node_id"; then
        echo "  ERROR: PATCH failed" >&2
        fail=$((fail + 1))
        continue
      fi
      # Verify the new value sticks.
      new_cfg="$(get_node_config "$lab_id" "$node_id")"
      if [[ "$new_cfg" != "$EXPECTED_CONFIG_VALUE" ]]; then
        echo "  WARNING: post-patch configuration is ${new_cfg}, expected ${EXPECTED_CONFIG_VALUE}" >&2
      fi
      if (( LEAVE_STOPPED == 1 )); then
        echo "  --leave-stopped set; not restarting"
      elif [[ "$start_state" == "STARTED" || "$start_state" == "QUEUED" || "$start_state" == "BOOTED" ]]; then
        echo "  starting lab..."
        if ! start_lab "$lab_id"; then
          echo "  ERROR: start call failed" >&2
          fail=$((fail + 1))
          continue
        fi
        if ! wait_lab_state "$lab_id" "STARTED" "BOOTED"; then
          fail=$((fail + 1))
          continue
        fi
      else
        echo "  lab was not running before; leaving in ${start_state}"
      fi
      echo "  done."
      ;;
  esac
done

if (( fail > 0 )); then
  echo
  echo "Completed with ${fail} failure(s). Review output above." >&2
  exit 1
fi

echo
echo "All matched labs are now canonical: configuration = ${EXPECTED_CONFIG_VALUE}"
