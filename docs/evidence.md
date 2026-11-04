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

## verify-hardening.sh

The script was tested by replaying the exact outputs above through stub commands. It passes all 11 checks on the "after" state. On the "before" state it fails 4: root login, the SSH rule open to `Anywhere` (counted twice), and CUPS.
