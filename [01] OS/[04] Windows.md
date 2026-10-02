# Windows 11: minimal ISO, your own answer file, hands-off install

Laid out like the [Arch](./[01]%20ArchAIO.md) and [Bazzite](./[03]%20Bazzite.md) guides: one file per step in [`win/`](./win/), background in [`win/99-notes.md`](./win/99-notes.md). Written against Windows 11 Pro 26H2 (build 26300.9539, September 2026). The tweak scripts assume a desktop with at least a Ryzen 5 3600 class CPU and 16 GB of RAM. Anything faster is fine.

What you get is Windows 11 Pro without Edge, the Store or the inbox apps, with the latest cumulative update already in, two partitions, a local account, and the performance, privacy and interface settings applied on first logon. The apps are left out of the image instead of being removed afterwards and nothing in the OS is patched, so Defender and Windows Update keep working.

Building it takes about an hour the first time. After that an install takes around ten minutes and needs no clicks.

## Before you start

- You make your own files. The answer file in this repo is a template with placeholder values. Import it into the generator or read it, but don't copy it to a stick.
- **CHANGE** marks the values that are yours (user name, disk size, country). The rest can stay as written.
- The install wipes one whole disk. Which one depends on a size range you type in step 3. Back up first.
- Windows search is off. Typing in Start finds nothing, and the build expects Open-Shell or another launcher. Step 4 says which lines to delete if you want to keep it.
- Every step ends with a check. If yours doesn't match, stop and fix it before going on.
- You need a Windows 10 or 11 PC to build on, 25 GB free, a USB stick of 8 GB or more, and Ethernet on the target PC.

## Steps

| # | File | What you do | Time |
|---|---|---|---|
| 1 | [01-minimal-iso.md](./win/01-minimal-iso.md) | Build a Pro-only ISO from UUP dump with the apps left out | 30 to 60 min |
| 2 | [02-answer-file.md](./win/02-answer-file.md) | Fill in the answer-file generator, top to bottom | 30 min |
| 3 | [03-disk-script.md](./win/03-disk-script.md) | Inside step 2: paste the disk script and set which disk gets wiped | |
| 4 | [04-first-logon-scripts.md](./win/04-first-logon-scripts.md) | Inside step 2: paste the three tweak scripts | |
| 5 | [05-flash-usb.md](./win/05-flash-usb.md) | Put the ISO and the answer file on a USB stick | 10 min |
| 6 | [06-install-and-verify.md](./win/06-install-and-verify.md) | Install, check the result, change things later | 15 min |
| 7 | [07-firewall.md](./win/07-firewall.md) | Optional: firewall allowlist for the Windows components | 5 min |

Steps 3 and 4 happen inside step 2. They cover the two places in the generator form where you paste files from this repo.

## What is in `win/`

| Folder | Contents | Used in |
|---|---|---|
| [`iso/`](./win/iso/) | `ConvertConfig.ini`, `CustomAppsList.txt` | step 1 |
| [`unattend/`](./win/unattend/) | `pe.cmd` (disk script), `autounattend.example.xml` (template), `ventoy.json`, `sync-example.ps1` | steps 2, 3, 5 |
| [`scripts/`](./win/scripts/) | `01-perf.ps1`, `02-privacy.ps1`, `03-interface.ps1` | step 4 |
| [`firewall/`](./win/firewall/) | `tinywall-windows.tws` | step 7 |

`pe.cmd` and the three `.ps1` files are in the repo twice: as standalone files that you read, edit and paste, and embedded in `autounattend.example.xml`, which is where Setup runs them from. Both copies are the same text. The `.ps1` files can also be run by hand on an existing install (end of step 4), `pe.cmd` can't.
