# Evidence

Real command output from the lab box, captured on 2026-11-04 over SSH. It backs up every claim in the [README](../README.md). Re-run the checks yourself with [`scripts/verify-hardening.sh`](../scripts/verify-hardening.sh).

## System

```
== OS
Ubuntu 26.04.1 LTS            # Xubuntu flavour
7.0.0-42-generic
== Firmware                   # sudo dmidecode -s bios-vendor / bios-version / system-product-name
coreboot
MrChromebox-2609.2
Careena
== CPU
CPU(s):                                  2
Model name:                              AMD A4-9120C RADEON R4, 5 COMPUTE CORES 2C+3G
== Memory
               total        used        free      shared  buff/cache   available
Mem:           3.7Gi       1.0Gi       1.9Gi       6.7Mi       958Mi       2.7Gi
== Disk
NAME           SIZE TYPE MODEL
mmcblk1       29.1G disk                 # 32 GB eMMC (decimal GB vs GiB)
== Docker
Docker version 29.1.3, build 29.1.3-0ubuntu4.1
```

`coreboot` / `MrChromebox-…` confirms the stock ChromeOS firmware has been replaced by the MrChromebox UEFI Full ROM.

## Hardening: before and after

I reviewed the first capture and found three gaps, then fixed them.

| Check | Before | After |
|---|---|---|
| Root login over SSH | `permitrootlogin prohibit-password` (root could log in with a key) | `permitrootlogin no` |
| Who can reach SSH | `22/tcp ALLOW IN Anywhere` (+ IPv6) | `22/tcp ALLOW IN 192.168.0.0/24` and `192.168.100.0/24` only |
| Printing service (CUPS) | Listening on `127.0.0.1:631` and `[::1]:631` | Stopped and masked |

### SSH, effective configuration (`sudo sshd -T`)

```
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
```

The root-login change lives in a drop-in, so the distribution's `sshd_config` stays untouched:

```
$ cat /etc/ssh/sshd_config.d/99-lab-hardening.conf
PermitRootLogin no
```

### Password login is refused

Forcing a login without the key, against the server's LAN address:

```
$ ssh -o PubkeyAuthentication=no cardinal@192.168.0.103
cardinal@192.168.0.103: Permission denied (publickey).
```

The server never offers a password prompt; the only method it accepts is a key.

### Firewall (`sudo ufw status verbose`)

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    192.168.100.0/24
22/tcp                     ALLOW IN    192.168.0.0/24
```

There are two subnets because the home network has two routers: the ISP's Huawei ONT (`192.168.100.0/24`) and a Wi-Fi router behind it (`192.168.0.0/24`). There is no IPv6 allow rule, so IPv6 SSH is dropped by the default policy.

### Listening sockets (`sudo ss -tlnH`)

```
0.0.0.0:22          # SSH (filtered by ufw to the two LAN subnets)
127.0.0.1:44103     # containerd (Docker's runtime), random localhost port
127.0.0.53%lo:53    # systemd-resolved stub
127.0.0.54:53       # systemd-resolved
[::]:22             # SSH over IPv6 (no ufw allow rule, so dropped)
```

Only SSH listens beyond loopback.

### CUPS

```
$ systemctl is-enabled cups.service cups.socket cups.path
masked
masked
masked
```

All three units are masked, because `cups.socket` and `cups.path` can re-activate `cups.service` on their own.

## Update 2026-11-04: SecureVault M3b firewall

The firewall above was narrowed later the same day for [SecureVault_Suite M3b](https://github.com/cre-scen/SecureVault_Suite/blob/main/docs/m3b-firewall-evidence.md). The output above is kept as the state at hardening time.

```
$ sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       192.168.0.101              # SSH: admin laptop
5000/tcp                   ALLOW       192.168.0.0/24             # SecureVault API (lab)
```

- SSH now comes from the admin laptop only. Its address is reserved in the router (IP-MAC binding to the Wi-Fi adapter), because this rule would lock out any other address.
- `5000/tcp` is the SecureVault API, open to the lab subnet. It listens on `192.168.0.103:5000` only while the API runs.
- A separate nftables table (`inet securevault`, loaded by `securevault-firewall.service`) drops IPs that LogSentinel bans, before ufw sees them. `nftables.service` stays disabled, because its `flush ruleset` would wipe ufw.
- nmap from a Kali VM on the LAN: before, `22/tcp open`; after, `5000/tcp open` only.

## verify-hardening.sh

The script was tested by replaying the exact outputs above through stub commands. It passes all 11 checks on the "after" state. On the "before" state it fails 4: root login, the SSH rule open to `Anywhere` (counted twice), and CUPS.

Updated for M3b (2026-11-04): it now expects SSH from `SSH_SOURCES` (default `192.168.0.101`) and the API port from `API_SOURCES` (default `192.168.0.0/24`), fails if no SSH rule exists for the admin (the lockout case), fails on any rule open to `Anywhere`, and fails if `nftables.service` is enabled. Replayed through stubs, it passes all 13 checks on the M3b state above, and the earlier two-subnet SSH rules now fail 2 checks, as intended.

Run on the live box 2026-11-04 (firmware `MrChromebox-2609.2`, SecureVault API running): all 13 checks passed, exit 0.
