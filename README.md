# Chromebook to Linux Lab Box

Turning an end-of-life HP Chromebook into a hardened Xubuntu machine that I use as a **lab target** in my home security lab (see [homelab](https://github.com/cre-scen/homelab)).

## Why

ChromeOS security updates for this device ended in **July 2026**. An unpatched machine shouldn't be used for daily work. With full Linux it becomes a useful, isolated test box.

## Hardware

| Item | Value |
| :--- | :--- |
| Model | HP Chromebook 14 (db0xxx) |
| Board | CAREENA (AMD Stoney Ridge) |
| CPU / GPU | AMD A4-9120C / Radeon R4 |
| RAM / Storage | 4 GB / 32 GB eMMC |

## Summary of steps

1. **Checked support.** Confirmed on the [MrChromebox supported devices](https://docs.mrchromebox.tech/docs/supported-devices.html) page that CAREENA supports the **UEFI Full ROM**, and read the board's WP Method directly from the table: **CR50 (battery)**.
2. **Enabled Developer Mode** and confirmed write protect was on (`1`).
3. **Disabled hardware write protect** by opening the case and disconnecting the battery, then booting on AC power only. Write protect then read `0`.
4. **Backed up the stock firmware** (16 MB `.rom`) to USB and copied it to a second machine. The script won't restore stock firmware on devices past their update-expiry date, so this backup is the only way back.
5. **Flashed the MrChromebox UEFI Full ROM** from the VT2 shell as `chronos`:
   ```bash
   cd; curl -LOf https://mrchromebox.tech/firmware-util.sh && sudo bash firmware-util.sh
   ```
   Ran **Backup** first, then **Install/Update UEFI Full ROM**.
6. **Installed Xubuntu 26.04.1 LTS** from a SHA256-verified ISO written with Rufus. Erased the internal eMMC, no encryption. Wi-Fi (ath10k), graphics (amdgpu), touchpad and sound all worked out of the box.
7. **Hardened remote access:**
   - Enabled the `ufw` firewall and allowed only SSH
   - Installed OpenSSH server and set up **ed25519 key auth** (with a passphrase)
   - **Disabled password authentication**:
     ```
     # /etc/ssh/sshd_config.d/  (drop-in)
     PasswordAuthentication no
     ```
8. **Installed Docker** (`docker.io`) to run vulnerable apps for practice. These are bound to localhost only.

## What went wrong (and what I learned)

- **Broken keyboard connector.** The locking latch on the keyboard ribbon connector (J9) came off while I was opening the case, so the built-in keyboard no longer works. I use a USB keyboard. Lesson: lift ZIF latches with a spudger, never pull the ribbon.
- **Don't trust old wikis.** An older community wiki said this platform only had RW_LEGACY support. The current MrChromebox table said otherwise. Always check the primary source.
- **Verify everything before an irreversible step.** That meant a firmware backup in two places, an ISO hash check, and confirming the target disk before erasing.

## Status

- [x] UEFI firmware flashed
- [x] Xubuntu installed and updated
- [x] SSH key-only access, firewall enabled
- [ ] DHCP reservation on the home router
- [ ] Vulnerable lab apps running (see homelab)
- [ ] Repair keyboard connector (optional)

<!-- TODO: add screenshots: write-protect status, firmware script menu, backup file, neofetch/fastfetch on Xubuntu -->
