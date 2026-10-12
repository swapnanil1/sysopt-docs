# Switching the shaper on the OpenWrt bridge from your PC

Two scripts that do the same job, one for Windows and one for Linux: turn SQM (cake) on the OpenWrt bridge on or off without logging in by hand. The bridge is the TL-WR845N build from its own repository, inline in front of the main router, management address 192.168.1.245, shaping on eth1. The address and device sit at the top of either script for another box.

| | Windows | Linux |
|---|---|---|
| Menu | double-click `sqm.cmd` | `./sqm.sh` |
| Direct | `sqm.cmd on`, `off`, `toggle`, `status` | `./sqm.sh on`, `off`, `toggle`, `status` |
| One-time key | menu item 5, or `sqm.cmd key` | menu item 5, or `./sqm.sh key` |

The menu is a numbered list; press the number, read the answer, press q to leave. The direct form is for a shortcut or a keybinding. No administrator rights, no change to the PC's network settings, no password in the file.

## One session per action

The shaper sits on the port this PC is behind. Starting or stopping it bounces that port, which drops the SSH session that carried the command. A plain `ssh ... /etc/init.d/sqm stop` therefore ends with "Connection reset" every time, and reading the new state back would need a second session. The scripts avoid both: the box reports the state it is in, starts the switch in the background one second later, and the session closes cleanly before the port bounces. The answer reads "was on, switching off (about 5 s)". A status call afterwards confirms it, if you want the confirmation.

So each action is exactly one SSH session, and without a key that is one password prompt.

## Do the key once

Menu item 5 appends a public key to `/etc/dropbear/authorized_keys` on the box and tests a login. It asks for the password one last time. Which key, in order:

1. One you name with the `SQM_KEY` environment variable, on either system. Set it once in the user environment on Windows, or export it in the shell profile on Linux, and every run uses it. Or leave the variable unset and put a Host block in `~/.ssh/config`, which ssh reads on its own:

   ```
   Host 192.168.1.245
     User root
     IdentityFile ~/.ssh/id_s1
     HostKeyAlgorithms +ssh-rsa
   ```

2. Nothing named: the scripts make `id_wr845n` in your `.ssh` folder and use that. A key of its own for a router is the tidier choice, since it can be revoked without touching the keys you use for git.

The key file on the box lives in the writable layer, so it survives reboots and config pushes but not a `sysupgrade -n`; after a reflash run item 5 again.

## What it does not do

It does not change whether the shaper starts at boot. The box boots with SQM on, as configured in its repository, and these scripts only switch it for the current session. A reboot of the box brings it back on.
