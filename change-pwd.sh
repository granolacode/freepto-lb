#!/usr/bin/env bash

ourdir=~/.config/check-firsttime
mkdir -p $ourdir

if ! [[ -f $ourdir/luks ]]; then
	if zenity --question --title "Cifratura" --text "Dovresti cambiare la password di cifratura del disco. Vuoi farlo ora? Altrimenti, ti verra' chiesto ad ogni avvio"; then
		dev=/dev/$(mount | grep "on /lib/live/mount/persistence/"|awk '{ print $1 }'|awk -F/ '{ print $(NF) }')
		if [[ -b "$dev" ]]; then
			palimpsest --show-volume="$dev"
		else
			palimpsest
		fi
		touch $ourdir/luks
	fi
fi
if ! [[ -f $ourdir/user ]]; then
	if zenity --question --title "Password utente" --text "Dovresti cambiare la password utente. Vuoi farlo ora? Altrimenti, ti verra' chiesto ad ogni avvio"; then
		x-terminal-emulator -e sh -c "passwd paranoid && touch $ourdir/user"
	fi
fi
