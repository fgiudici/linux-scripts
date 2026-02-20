#!/bin/bash

: ${ITEMS:="Archive,bin,Dev,Documents,Music,Notes,Pictures,.bashrc.d,.ssh"}

usage() {
	echo "backup.sh {COMMAND} {REMOTEPATH} [BKUPDIRS] [OPTIONS]"
	echo "  COMMAND:    [save | restore]"
	echo "  REMOTEPATH: remote host:path to sync with"
	echo "  BKUPDIRS: comma-separated directories to sync (default: \$ITEMS)"
	echo "  options:"
	echo "    -x    # eXecute the file sync"
	echo "    -d    # delete extra remote files (rsync --delete option)"
	echo "    -g    # ignore if files have a different user group (rsync --no-group option)"
	echo "    -p    # backup also Priv folders (by default Priv folders are skipped)"
	echo ""
	echo "example: backup.sh save REMOTE-HOST:/base/dir -x -d"
	echo "example: backup.sh save REMOTE-HOST:/home/user Documents,Music -x"
}

help_and_quit() {
	usage
	exit 1
}

parseargs() {
	local pos=0
	local include_priv=false

	while [ $# -gt 0 ]; do
		case "$1" in
			-x) DO=true ;;
			-d) RSYNC_OPTIONS="$RSYNC_OPTIONS --delete"
				OPTPRINT="${OPTPRINT}[Del]" ;;
			-g) RSYNC_OPTIONS="$RSYNC_OPTIONS --no-group"
				OPTPRINT="${OPTPRINT}[NoG]" ;;
			-p) include_priv=true ;;
			-*) help_and_quit ;;
			*)
				case $pos in
					0) ARG_COMMAND="$1" ;;
					1) ARG_REMOTEPATH="$1" ;;
					2) ITEMS="$1" ;;
					*) help_and_quit ;;
				esac
				((pos++))
				;;
		esac
		shift
	done

	if [ $pos -lt 2 ]; then
		help_and_quit
	fi

	if [ "$ARG_COMMAND" != "save" ] && [ "$ARG_COMMAND" != "restore" ]; then
		help_and_quit
	fi

	if ! $include_priv; then
		RSYNC_OPTIONS="$RSYNC_OPTIONS --exclude Priv"
	else
		OPTPRINT="${OPTPRINT}[Priv]"
	fi

	case $ARG_COMMAND in
		"save")
			SRCPATH="$PWD"
			DSTPATH="$ARG_REMOTEPATH"
			;;
		"restore")
			SRCPATH="$ARG_REMOTEPATH"
			DSTPATH="$PWD"
			;;
	esac
}

# main

DO=false
RSYNC_OPTIONS=""
SRCPATH=""
DSTPATH=""
OPTPRINT=""

parseargs "$@"


IFS=',' read -ra ITEMS_ARR <<< "$ITEMS"
for i in "${ITEMS_ARR[@]}"; do
	SRC="$SRCPATH/$i/"
	DST="$DSTPATH/$i/"
	DELIMITER="=================================================================="
	echo -e "\n${DELIMITER}\n  $SRC -> $DST $OPTPRINT\n${DELIMITER}\n"
	output=$(rsync -haun --itemize-changes $RSYNC_OPTIONS $SRC $DST)
	if [ -n "$output" ]; then
		echo "$output"
	else
		echo "No changes detected, skipping..."
		sleep 1
		continue
	fi
	
	if $DO; then
		echo -n "Perform Sync? [y]es [s]kip [q]uit"
		read -rsn1 res
		echo ""
		case $res in
		"y")
			rsync -havu $RSYNC_OPTIONS $SRC $DST
			;;
		"s")
			continue
			;;
		*)
			exit 0
			;;
		esac
	else
		read -rsn1
	fi
done

