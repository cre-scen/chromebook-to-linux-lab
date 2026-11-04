#!/usr/bin/env bash
# Re-checks every hardening claim in the README against the live system.
# Read-only: changes nothing. Run on the lab box:  sudo bash scripts/verify-hardening.sh
# Exit code 0 = all checks passed, 1 = at least one failed.
set -u

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo (sshd -T, ufw and dmidecode need root)." >&2
    exit 2
fi

# Networks allowed to reach SSH. Override, e.g.: sudo ALLOWED_NETS="10.0.0.0/24" bash scripts/verify-hardening.sh
ALLOWED_NETS=${ALLOWED_NETS:-"192.168.0.0/24 192.168.100.0/24"}

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
check "No SSH rule open to Anywhere"   bash -c '! grep -Eq "^22/tcp.*ALLOW IN +Anywhere" <<<"$1"' _ "$ufw_out"
# Every ALLOW IN rule must be SSH from one of the allowed networks
unexpected=$(grep 'ALLOW IN' <<<"$ufw_out" | while read -r line; do
    ok=0
    for net in $ALLOWED_NETS; do
        [[ $line =~ ^22/tcp[[:space:]]+ALLOW\ IN[[:space:]]+${net//./\\.}([[:space:]]|$) ]] && ok=1
    done
    [[ $ok -eq 0 ]] && echo "$line"
done)
if [[ -z $unexpected ]]; then
    pass "Only SSH from $ALLOWED_NETS is allowed in"
else
    fail "Unexpected inbound rules: $(tr '\n' ';' <<<"$unexpected")"
fi

echo "== Exposed services"
# Anything listening on a non-loopback address other than SSH is a finding
exposed=$(ss -tlnH | awk '{print $4}' | grep -Ev '^(127\.|\[::1\]|::1)' | grep -Ev ':22$' || true)
if [[ -z $exposed ]]; then
    pass "Only SSH listens on non-loopback addresses"
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
