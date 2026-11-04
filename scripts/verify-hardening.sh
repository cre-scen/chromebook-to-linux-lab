#!/usr/bin/env bash
# Re-checks every hardening claim in the README against the live system.
# Read-only: changes nothing. Run on the lab box:  sudo bash scripts/verify-hardening.sh
# Exit code 0 = all checks passed, 1 = at least one failed.
set -u

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo (sshd -T, ufw and dmidecode need root)." >&2
    exit 2
fi

# Who may reach what. Override, e.g.: sudo SSH_SOURCES="10.0.0.5" bash scripts/verify-hardening.sh
# SSH: the admin laptop only (reserved in the router). API: the SecureVault lab API
# (SecureVault_Suite M3b) from the lab subnet. Set API_PORT="" if the API isn't deployed.
SSH_SOURCES=${SSH_SOURCES:-"192.168.0.101"}
API_PORT=${API_PORT-5000}
API_SOURCES=${API_SOURCES:-"192.168.0.0/24"}

fails=0
pass() { printf '  [PASS] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; fails=$((fails + 1)); }
check() { # check "description" command...
    local desc=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

sshd_cfg=$(sshd -T 2>/dev/null)
# shellcheck disable=SC2329  # called indirectly through check()
sshd_has() { grep -qx "$1" <<<"$sshd_cfg"; }

echo "== Firmware"
bios=$(dmidecode -s bios-version 2>/dev/null)
check "MrChromebox UEFI firmware (found: ${bios:-unknown})" grep -q '^MrChromebox' <<<"$bios"

echo "== SSH"
check "Password login disabled"            sshd_has "passwordauthentication no"
check "Keyboard-interactive login disabled" sshd_has "kbdinteractiveauthentication no"
check "Public-key login enabled"            sshd_has "pubkeyauthentication yes"
check "Root login disabled"                 sshd_has "permitrootlogin no"

echo "== Firewall"
ufw_out=$(ufw status verbose 2>/dev/null)
check "ufw active"                     grep -q '^Status: active' <<<"$ufw_out"
check "Default deny incoming"          grep -q 'deny (incoming)' <<<"$ufw_out"
# shellcheck disable=SC2016  # single quotes intended: expanded by the inner bash
# shellcheck disable=SC2016  # single quotes intended: expanded by the inner bash
check "No rule open to Anywhere"       bash -c '! grep -Eq "ALLOW IN +Anywhere" <<<"$1"' _ "$ufw_out"
# allowed_rule PORT SOURCE: true if `line` is exactly "PORT/tcp ALLOW IN SOURCE" (+ optional comment)
allowed_rule() { [[ $line =~ ^$1/tcp[[:space:]]+ALLOW\ IN[[:space:]]+${2//./\\.}([[:space:]]|$) ]]; }
# Every ALLOW IN rule must be SSH from an admin source, or the API from the lab subnet
unexpected=$(grep 'ALLOW IN' <<<"$ufw_out" | while read -r line; do
    ok=0
    for src in $SSH_SOURCES; do allowed_rule 22 "$src" && ok=1; done
    if [[ -n $API_PORT ]]; then
        for src in $API_SOURCES; do allowed_rule "$API_PORT" "$src" && ok=1; done
    fi
    [[ $ok -eq 0 ]] && echo "$line"
done)
if [[ -z $unexpected ]]; then
    pass "Only SSH from $SSH_SOURCES${API_PORT:+ and port $API_PORT from $API_SOURCES} allowed in"
else
    fail "Unexpected inbound rules: $(tr '\n' ';' <<<"$unexpected")"
fi
# Without this, a missing SSH rule would pass the check above and lock the admin out
line_has_ssh=$(grep 'ALLOW IN' <<<"$ufw_out" | while read -r line; do
    for src in $SSH_SOURCES; do allowed_rule 22 "$src" && echo yes; done
done)
check "SSH allowed from the admin source" test -n "$line_has_ssh"
# shellcheck disable=SC2016  # single quotes intended: expanded by the inner bash
check "nftables.service not enabled (its flush ruleset would wipe ufw)" \
    bash -c '[[ $(systemctl is-enabled nftables.service 2>/dev/null) != enabled ]]'

echo "== Exposed services"
# Anything listening on a non-loopback address other than SSH (and the API port, which
# ufw limits to the lab subnet) is a finding. The API only listens while it is running.
allowed_ports=":22${API_PORT:+|:$API_PORT}"
exposed=$(ss -tlnH | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | grep -Ev "(${allowed_ports})\$" || true)
if [[ -z $exposed ]]; then
    pass "Only SSH${API_PORT:+ and port $API_PORT} listen on non-loopback addresses"
else
    fail "Also listening beyond localhost: $(tr '\n' ' ' <<<"$exposed")"
fi
# shellcheck disable=SC2016  # single quotes intended: expanded by the inner bash
check "CUPS (printing) masked" bash -c '[[ $(systemctl is-enabled cups.service 2>/dev/null) == masked ]]'

echo
if [[ $fails -eq 0 ]]; then
    echo "All checks passed."
    exit 0
fi
echo "$fails check(s) failed."
exit 1
