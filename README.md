# Chromebook to Linux Lab Box

![Xubuntu](https://img.shields.io/badge/Xubuntu-26.04.1_LTS-0044AA?logo=xubuntu&logoColor=white)
![Firmware](https://img.shields.io/badge/Firmware-MrChromebox_UEFI-informational)
![SSH](https://img.shields.io/badge/SSH-key--only-success)
![License](https://img.shields.io/badge/License-MIT-green)

I repurposed an end-of-life HP Chromebook as a hardened Xubuntu machine. It now serves as the **target host** in my [home security lab](https://github.com/cre-scen/homelab).

Every claim below is backed by real command output in **[docs/evidence.md](docs/evidence.md)**, and can be re-checked on the box with [`scripts/verify-hardening.sh`](scripts/verify-hardening.sh).

## Background

ChromeOS security updates for this device ended in **July 2026**. An unpatched device shouldn't be used for everyday work. But with UEFI firmware and a current Linux distribution, the hardware is still useful as an isolated, disposable lab target.

## Hardware

| Component | Specification |
| :--- | :--- |
| Model | HP Chromebook 14 (db0xxx), board CAREENA (AMD Stoney Ridge) |
| CPU / GPU | AMD A4-9120C / Radeon R4 |
| Memory / Storage | 4 GB RAM (3.7 GiB usable) / 32 GB eMMC (29.1 GiB) |

## Process

### 1. Assess compatibility

I checked the [MrChromebox supported-devices table](https://docs.mrchromebox.tech/docs/supported-devices.html) for the board. It confirmed **UEFI Full ROM** support and a write-protect method of **CR50 (battery)**. An older community wiki listed only RW_LEGACY support for this platform, which is why I used the current primary source instead.

### 2. Disable firmware write protection

- Enabled Developer Mode and confirmed write protect was enabled (`1`).
- Opened the chassis and disconnected the internal battery, then booted on AC power alone. Write protect then read `0`.

### 3. Back up the stock firmware

I saved the 16 MB stock firmware image to USB and copied it to a second machine. The flashing utility refuses to restore stock firmware on devices past their update-expiry date, so this backup is the only recovery path.

### 4. Flash UEFI firmware

From the ChromeOS VT2 shell, as the `chronos` user:

```bash
cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
```

I ran **Backup Current Firmware** first, verified the file, then ran **Install/Update UEFI (Full ROM) Firmware**. The box now reports `coreboot` / `MrChromebox-2609.2` as its firmware.

### 5. Install Linux

- Downloaded **Xubuntu 26.04.1 LTS**, verified its SHA256 checksum and wrote it to USB with Rufus.
- Installed to the internal eMMC (whole disk).
- Wi-Fi (`ath10k`), graphics (`amdgpu`), touchpad and audio all worked without extra drivers.

### 6. Harden remote access

| Control | Implementation |
| :--- | :--- |
| Host firewall | `ufw`, default deny inbound; SSH allowed only from the admin laptop (`192.168.0.101`, reserved in the router). Since [SecureVault_Suite](https://github.com/cre-scen/SecureVault_Suite) M3b, the lab API (`5000/tcp`) is also allowed from `192.168.0.0/24`, and a separate nftables table drops IPs that LogSentinel bans ([evidence](https://github.com/cre-scen/SecureVault_Suite/blob/main/docs/m3b-firewall-evidence.md)) |
| Authentication | OpenSSH with **ed25519** keys only; the private key is passphrase-protected |
| Password login | Disabled (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`). A forced password attempt gets `Permission denied (publickey)` |
| Root login | Disabled (`PermitRootLogin no`, in a drop-in under `sshd_config.d/`) |
| Unneeded services | CUPS (printing) stopped and masked. Only SSH listens beyond localhost, plus the SecureVault API while it runs |

### 7. Prepare as a lab target

I installed Docker (`docker.io`) to run intentionally vulnerable applications. They bind to `127.0.0.1` only and are reached through SSH tunnels. The applications themselves are documented in [homelab](https://github.com/cre-scen/homelab).

## Verify it yourself

On the box:

```bash
sudo bash scripts/verify-hardening.sh
```

It is read-only and changes nothing. It checks the firmware, the SSH settings, the firewall rules, what is listening on the network and CUPS, and exits non-zero if anything has drifted. Override who may connect with `SSH_SOURCES`, `API_SOURCES` and `API_PORT`, e.g. `sudo SSH_SOURCES="10.0.0.5" bash scripts/verify-hardening.sh`. Use `API_PORT=""` if the SecureVault API isn't deployed.

## Challenges and lessons learned

| Challenge | Outcome / lesson |
| :--- | :--- |
| The keyboard ribbon connector's locking latch (J9) came off during disassembly | The built-in keyboard is out of service and I use a USB keyboard. Lesson: release ZIF latches with a spudger before handling ribbons. |
| Conflicting compatibility information online | Verify against the maintainer's current documentation, not secondary wikis. |
| Several irreversible steps (firmware flash, disk erase) | Verify before each one: a firmware backup in two locations, a checksum-verified ISO and a confirmed target disk. |
| My first evidence capture showed root could still log in with a key, SSH was open to any source, and an unused printing service was running | Fixed all three and recorded the before/after state. Lesson: "hardened" needs checking against the live system, not assuming. |
| After restricting SSH to `192.168.100.0/24`, new connections timed out: the box had moved to the second router's `192.168.0.0/24` network | I had kept the existing SSH session open, so I could diagnose from inside (`$SSH_CLIENT`, `hostname -I`) and add the right subnet without physical access. Lesson: never close your only session while changing firewall or SSH rules; and a DHCP reservation prevents the address moving. |

## Skills demonstrated

- Hardware disassembly and firmware write-protect bypass on owned hardware
- Firmware backup, recovery planning and UEFI flashing
- Linux installation, hardware driver validation and post-install hardening
- SSH key management, host firewall configuration and attack-surface reduction
- Verifying security controls with evidence and a repeatable check script
- Risk management for irreversible operations and remote changes

## Status

| Item | State |
| :--- | :--- |
| UEFI firmware | Complete |
| Xubuntu install and updates | Complete |
| SSH hardening and firewall | Complete, verified ([evidence](docs/evidence.md)) |
| Docker installed | Complete; vulnerable apps run under [homelab](https://github.com/cre-scen/homelab) |
| DHCP reservation | Complete: IP-MAC binding on the Tenda Wi-Fi router, so the box always gets the same address |

## License

[MIT](LICENSE)
