# Chromebook to Linux Lab Box

![Xubuntu](https://img.shields.io/badge/Xubuntu-26.04.1_LTS-0044AA?logo=xubuntu&logoColor=white)
![Firmware](https://img.shields.io/badge/Firmware-MrChromebox_UEFI-informational)
![SSH](https://img.shields.io/badge/SSH-key--only-success)

I repurposed an end-of-life HP Chromebook as a hardened Xubuntu machine. It now serves as the **target host** in my [home security lab](https://github.com/cre-scen/homelab).

## Background

ChromeOS security updates for this device ended in **July 2026**. An unpatched device shouldn't be used for everyday work. But with UEFI firmware and a current Linux distribution, the hardware is still useful as an isolated, disposable lab target.

## Hardware

| Component | Specification |
| :--- | :--- |
| Model | HP Chromebook 14 (db0xxx) |
| Board | CAREENA (AMD Stoney Ridge) |
| CPU / GPU | AMD A4-9120C / Radeon R4 |
| Memory / Storage | 4 GB RAM / 32 GB eMMC |

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

I ran **Backup Current Firmware** first, verified the file, then ran **Install/Update UEFI (Full ROM) Firmware**.

### 5. Install Linux

- Downloaded **Xubuntu 26.04.1 LTS**, verified its SHA256 checksum and wrote it to USB with Rufus.
- Installed to the internal eMMC (whole disk).
- Wi-Fi (`ath10k`), graphics (`amdgpu`), touchpad and audio all worked without extra drivers.

### 6. Harden remote access

| Control | Implementation |
| :--- | :--- |
| Host firewall | `ufw` enabled, inbound limited to SSH |
| Authentication | OpenSSH with **ed25519** keys, passphrase-protected |
| Password login | Disabled (`PasswordAuthentication no`) |

### 7. Prepare as a lab target

I installed Docker (`docker.io`) to run intentionally vulnerable applications. They bind to `127.0.0.1` only and are reached through SSH tunnels. See [homelab](https://github.com/cre-scen/homelab).

## Challenges and lessons learned

| Challenge | Outcome / lesson |
| :--- | :--- |
| The keyboard ribbon connector's locking latch (J9) came off during disassembly | The built-in keyboard is out of service and I use a USB keyboard. Lesson: release ZIF latches with a spudger before handling ribbons. |
| Conflicting compatibility information online | Verify against the maintainer's current documentation, not secondary wikis. |
| Several irreversible steps (firmware flash, disk erase) | Verify before each one: a firmware backup in two locations, a checksum-verified ISO and a confirmed target disk. |

## Skills demonstrated

- Hardware disassembly and firmware write-protect bypass on owned hardware
- Firmware backup, recovery planning and UEFI flashing
- Linux installation, hardware driver validation and post-install hardening
- SSH key management and host firewall configuration
- Risk management for irreversible operations

## Status

| Item | State |
| :--- | :--- |
| UEFI firmware | Complete |
| Xubuntu install and updates | Complete |
| SSH hardening and firewall | Complete |
| Docker lab services | In progress |
| DHCP reservation | Planned |

<!-- TODO before public: add screenshots (write-protect status, firmware utility menu, backup file listing, fastfetch on Xubuntu) to an images/ folder and link them in the relevant steps -->
