#!/bin/sh
# Menu for the shaper (SQM, cake) on the OpenWrt bridge. Run it for the menu, or give the action
# on the command line for a keybinding:  ./sqm.sh on | off | toggle | status | key
#
# One SSH session per action. The box prints the state it is in, then switches in the background,
# because stopping or starting the shaper on eth1 drops the session that carried the command.
# Without a key each action asks for the root password once; "key" installs one and ends that.
# Key: SQM_KEY=<file> picks a private key; otherwise ~/.ssh/id_wr845n if it exists; otherwise ssh's
# own rules (a Host block in ~/.ssh/config, the agent). SQM_BOX overrides the address.
BOX="${SQM_BOX:-192.168.1.245}"
DEV=eth1
KEY="${SQM_KEY:-$HOME/.ssh/id_wr845n}"
OPTS="-o HostKeyAlgorithms=+ssh-rsa -o ConnectTimeout=5"
[ -f "$KEY" ] && OPTS="$OPTS -i $KEY -o IdentitiesOnly=yes"

remote() { ssh $OPTS "root@$BOX" "$1"; }
is_on="tc qdisc show dev $DEV | grep -q cake"
go_on="echo 'was off, switching on (about 5 s)'; ( sleep 1; /etc/init.d/sqm start ) >/dev/null 2>&1 &"
go_off="echo 'was on, switching off (about 5 s)'; ( sleep 1; /etc/init.d/sqm stop ) >/dev/null 2>&1 &"

run() {
	case "$1" in
		status) remote "if $is_on; then echo 'SQM on: cake on $DEV'; else echo 'SQM off: no shaper on $DEV'; fi" ;;
		on)     remote "if $is_on; then echo 'already on'; else $go_on fi" ;;
		off)    remote "if $is_on; then $go_off else echo 'already off'; fi" ;;
		toggle) remote "if $is_on; then $go_off else $go_on fi" ;;
		key)
			[ -f "$KEY" ] || ssh-keygen -t ed25519 -N "" -f "$KEY" -C wr845n >/dev/null
			[ -f "$KEY.pub" ] || { echo "no public key next to $KEY" >&2; return 1; }
			echo "installing $KEY.pub, last password prompt:"
			ssh -o HostKeyAlgorithms=+ssh-rsa "root@$BOX" \
				'mkdir -p /etc/dropbear; cat >> /etc/dropbear/authorized_keys; chmod 600 /etc/dropbear/authorized_keys; echo key installed' < "$KEY.pub"
			ssh -o HostKeyAlgorithms=+ssh-rsa -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes "root@$BOX" 'echo login without a password works'
			;;
		*) echo "unknown action '$1': on, off, toggle, status, key" >&2; return 1 ;;
	esac
}

if [ -n "$1" ]; then run "$1"; exit; fi

while :; do
	printf '\n  SQM on %s\n\n  1  status\n  2  on\n  3  off\n  4  toggle\n  5  key      install an SSH key, no more passwords\n  q  quit\n\n> ' "$BOX"
	read -r c || exit 0
	case "$c" in
		1) run status ;; 2) run on ;; 3) run off ;; 4) run toggle ;; 5) run key ;;
		q|'') exit 0 ;;
	esac
done
