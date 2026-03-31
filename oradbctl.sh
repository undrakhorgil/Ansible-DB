#!/usr/bin/env bash
set -euo pipefail

MODE=""
SINGLE=""
RANGE=""
ROOT_PW="${ROOT_PW:-Welcome1}"
STATE_FILE="${ORADBCTL_STATE_FILE:-/tmp/oradbctl.state}"

usage() {
  echo "Usage:" >&2
  echo "  $0 -s <n> [-p <root_password>]" >&2
  echo "  $0 -u <n> [-p <root_password>]" >&2
  echo "  $0 -s -r <start-end> [-p <root_password>]" >&2
  echo "  $0 -u -r <start-end> [-p <root_password>]" >&2
  echo "  $0 -l" >&2
  echo "  $0 -?   (help; quote it in zsh: $0 '-?')" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 -s 7" >&2
  echo "  $0 -s -r 1-9" >&2
  echo "  $0 -u 10" >&2
  echo "  $0 -u -r 6-12   # reverse order" >&2
  echo "" >&2
  echo "Notes:" >&2
  echo "  - Undo uses the same step number: $0 -u <n>" >&2
  echo "  - $0 -l shows DONE flags from: ${STATE_FILE}" >&2
}

step_status() {
  local n="$1"
  [[ -f "${STATE_FILE}" ]] || { echo ""; return 0; }
  # Format: step <n> <status> <timestamp>
  awk -v n="$n" '$1=="step" && $2==n { s=$3 } END { print s }' "${STATE_FILE}" 2>/dev/null || true
}

write_step_status() {
  local n="$1" status="$2"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
  mkdir -p "$(dirname "${STATE_FILE}")" 2>/dev/null || true
  # Replace existing record for this step (last-write-wins).
  local tmp
  tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
  if [[ -f "${STATE_FILE}" ]]; then
    awk -v n="$n" '$1=="step" && $2==n { next } { print }' "${STATE_FILE}" > "${tmp}" 2>/dev/null || true
  fi
  printf "step %s %s %s\n" "${n}" "${status}" "${ts}" >> "${tmp}"
  mv "${tmp}" "${STATE_FILE}"
}

clear_step_status() {
  local n="$1"
  [[ -f "${STATE_FILE}" ]] || return 0
  local tmp
  tmp="$(mktemp "${STATE_FILE}.XXXXXX")"
  awk -v n="$n" '$1=="step" && $2==n { next } { print }' "${STATE_FILE}" > "${tmp}" 2>/dev/null || true
  mv "${tmp}" "${STATE_FILE}"
}

list_steps() {
  local max_step=$(( ${#RAC_STEP[@]} - 1 ))
  echo "Steps:"
  for ((i=1;i<=max_step;i++)); do
    local st
    st="$(step_status "$i")"
    local tag=""
    case "$st" in
      DONE) tag="[DONE]" ;;
      FAILED) tag="[FAILED]" ;;
      *) tag="" ;;
    esac
    # Keep columns aligned: status column is fixed width (8 chars).
    printf "  %-8s %2d  %s\n" "$tag" "$i" "${STEP_TITLE[$i]}"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -\?|--help|-h) usage; exit 0 ;;
    -l|--list) MODE="list" ;;
    -s) MODE="step"; [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]] && SINGLE="$2" && shift ;;
    -u) MODE="undo"; [[ $# -gt 1 && "$2" =~ ^[0-9]+$ ]] && SINGLE="$2" && shift ;;
    -r) RANGE="$2"; shift ;;
    -p) ROOT_PW="$2"; shift ;;
    *) usage; exit 2 ;;
  esac
  shift
done

RAC_STEP=(
  "" "01_precheck_network.yml" "02_os_packages.yml" "03_users_groups.yml" "04_create_folders.yml"
  "05_hosts_sync.yml" "06_shared_disks_udev.yml" "07_oracle_user_env_ssh.yml" "08_grid_software_install.yml"
  "09_run_cluvfy.yml"
  "10_gridsetup.yml" "11_grid_rootsh.yml" "12_executeconfigtools.yml"
  "13_grid_postcheck_discover.yml" "14_grid_postcheck_run.yml"
  "15_db_software_unzip.yml" "16_db_software_install.yml"
  "17_db_rootsh.yml" "18_db_postcheck.yml" "19_create_diskgroups.yml"
  "20_create_orcl_database.yml" "21_summary.yml" "22_change_all_passwords.yml"
)

STEP_TITLE=(
  ""
  "Precheck networking"
  "OS packages & time sync"
  "Users, groups, limits"
  "Create Oracle directories"
  "Sync hosts file"
  "Shared disks (ASM) + udev"
  "User env & SSH"
  "Unzip Grid Infrastructure"
  "Run CVU precheck"
  "Grid setup (silent)"
  "Run root scripts"
  "Execute config tools"
  "Grid postcheck (discover)"
  "Grid postcheck (run)"
  "Unzip DB software"
  "Install DB software"
  "Run DB root scripts"
  "DB postcheck"
  "Create ASM disk groups"
  "Create database"
  "Summary"
  "Rotate root/oracle/grid passwords"
)

RAC_UNDO=(
  "" "undo_01_precheck_network.yml" "undo_02_os_packages.yml" "undo_03_users_groups.yml" "undo_04_create_folders.yml"
  "undo_05_hosts_sync.yml" "undo_06_shared_disks_udev.yml" "undo_07_oracle_user_env_ssh.yml" "undo_08_grid_software_install.yml"
  "undo_09_run_cluvfy.yml"
  "undo_10_gridsetup.yml" "undo_11_grid_rootsh.yml" "undo_12_executeconfigtools.yml"
  "undo_13_grid_postcheck_discover.yml" "undo_14_grid_postcheck_run.yml"
  "undo_15_db_software_unzip.yml" "undo_16_db_software_install.yml"
  "undo_17_db_rootsh.yml" "undo_18_db_postcheck.yml" "undo_19_create_diskgroups.yml"
  "undo_20_create_orcl_database.yml" "undo_21_summary.yml" "undo_22_change_all_passwords.yml"
)

if [[ "${MODE:-}" == "list" ]]; then
  list_steps
  exit 0
fi

[[ -n "${MODE:-}" ]] || { usage; exit 2; }
[[ -n "${SINGLE:-}" || -n "${RANGE:-}" ]] || { usage; exit 2; }
[[ -z "${SINGLE:-}" || -z "${RANGE:-}" ]] || { echo "Choose single or range."; exit 2; }

run_one() {
  local step="$1"
  local idx="$step"
  local max_step=$(( ${#RAC_STEP[@]} - 1 ))
  (( idx>=1 && idx<=max_step )) || { echo "Unsupported step $idx (max=$max_step)"; exit 2; }
  if [[ "$MODE" == "step" ]]; then
    if ansible-playbook -i inventory.yml playbooks/run_step.yml -e "target_root_password=$ROOT_PW" -e "rac_step=${RAC_STEP[$idx]}"; then
      write_step_status "$idx" "DONE"
    else
      write_step_status "$idx" "FAILED"
      return 1
    fi
  else
    local undo_task="${RAC_UNDO[$idx]:-}"
    [[ -n "$undo_task" ]] || { echo "No undo mapping for step $idx"; exit 2; }
    if ansible-playbook -i inventory.yml playbooks/run_undo_step.yml -e "target_root_password=$ROOT_PW" -e "rac_undo_step=${undo_task}"; then
      # Undo succeeded: clear prior status so -l reflects "not done".
      clear_step_status "$idx"
    else
      return 1
    fi
  fi
}

if [[ -n "$SINGLE" ]]; then
  run_one "$SINGLE"
else
  [[ "$RANGE" =~ ^([0-9]+)-([0-9]+)$ ]] || { echo "Invalid range"; exit 2; }
  s="${BASH_REMATCH[1]}"; e="${BASH_REMATCH[2]}"
  if [[ "$MODE" == "undo" ]]; then
    for ((i=e;i>=s;i--)); do run_one "$i"; done
  else
    for ((i=s;i<=e;i++)); do run_one "$i"; done
  fi
fi
