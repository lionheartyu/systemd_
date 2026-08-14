#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
set -eux
set -o pipefail

# shellcheck source=test/units/generator-utils.sh
. "$(dirname "$0")/generator-utils.sh"

GENERATOR_BIN="${GENERATOR_BIN:-/usr/lib/systemd/system-generators/systemd-cryptsetup-generator}"
OUT_DIR="$(mktemp -d /tmp/cryptsetup-generator.XXX)"
CRYPTTAB_FILE="$(mktemp /tmp/cryptsetup-generator-crypttab.XXX)"

at_exit() {
    rm -fr "${OUT_DIR:?}" "${CRYPTTAB_FILE:?}"
}

trap at_exit EXIT

if [[ ! -x "${GENERATOR_BIN:?}" ]]; then
    echo "systemd-cryptsetup-generator is not installed, skipping the test"
    exit 0
fi

check_no_cryptsetup_units() {
    [[ "$(find "$OUT_DIR" ! -type d | wc -l)" -eq 0 ]]
}

cryptsetup_unit_path() {
    echo "$OUT_DIR/normal/systemd-cryptsetup@$(systemd-escape "${1:?}").service"
}

check_cryptsetup_unit_contains_uuid() {
    grep -F "/dev/disk/by-uuid/${2:?}" "$(cryptsetup_unit_path "${1:?}")" >/dev/null
}

UUID="b40f1abf-2a53-400a-889a-2eccc27eaa40"
UUID_HEX_UPPER="B40F1ABF2A53400A889A2ECCC27EAA40"
CRYPTTAB_UUID="a40f1abf-2a53-400a-889a-2eccc27eaa40"

: "cryptsetup-generator: valid luks.uuid"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.uuid=$UUID" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path "luks-$UUID")"

: "cryptsetup-generator: valid luks.uuid with luks- prefix"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.uuid=luks-$UUID" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path "luks-$UUID")"

: "cryptsetup-generator: valid luks.uuid canonicalized"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.uuid=$UUID_HEX_UPPER" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path "luks-$UUID")"

: "cryptsetup-generator: invalid luks.uuid"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.uuid=not-a-uuid" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
check_no_cryptsetup_units

: "cryptsetup-generator: invalid luks.uuid with luks- prefix"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.uuid=luks-not-a-uuid" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
check_no_cryptsetup_units

: "cryptsetup-generator: crypttab baseline"
printf 'other UUID=%s none -\n' "$CRYPTTAB_UUID" >"$CRYPTTAB_FILE"
SYSTEMD_CRYPTTAB="$CRYPTTAB_FILE" SYSTEMD_PROC_CMDLINE="" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path other)"

: "cryptsetup-generator: crypttab UUID canonicalized"
printf 'root UUID=%s none luks,discard\n' "$UUID_HEX_UPPER" >"$CRYPTTAB_FILE"
SYSTEMD_CRYPTTAB="$CRYPTTAB_FILE" SYSTEMD_PROC_CMDLINE="luks.uuid=$UUID_HEX_UPPER" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path root)"
test ! -e "$(cryptsetup_unit_path "luks-$UUID")"

: "cryptsetup-generator: invalid luks.uuid enables allow-list"
printf 'other UUID=%s none -\n' "$CRYPTTAB_UUID" >"$CRYPTTAB_FILE"
SYSTEMD_CRYPTTAB="$CRYPTTAB_FILE" SYSTEMD_PROC_CMDLINE="luks.uuid=not-a-uuid" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
check_no_cryptsetup_units

: "cryptsetup-generator: valid luks.name canonicalized"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.name=$UUID_HEX_UPPER=mydisk" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
test -e "$(cryptsetup_unit_path mydisk)"
check_cryptsetup_unit_contains_uuid mydisk "$UUID"

: "cryptsetup-generator: invalid luks.name"
SYSTEMD_CRYPTTAB=/dev/null SYSTEMD_PROC_CMDLINE="luks.name=deadbeef=root" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
check_no_cryptsetup_units

: "cryptsetup-generator: invalid luks.name enables allow-list"
SYSTEMD_CRYPTTAB="$CRYPTTAB_FILE" SYSTEMD_PROC_CMDLINE="luks.name=deadbeef=root" run_and_list "$GENERATOR_BIN" "$OUT_DIR"
check_no_cryptsetup_units
