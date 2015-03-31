#!/bin/sh
# A wrapper script, that allows nagios scripts to call only certain riak-admin subcommands.
# By: Manu Maki

CMD="/usr/sbin/riak-admin"

case "$1" in
	"diag")
		$CMD diag
	;;
	"status")
		$CMD status
	;;
	"ringready")
		$CMD ringready
	;;
	*)
		echo "Sorry. Only these options are available to you:"
		echo "$0 [ diag | status | ringready ]"
		exit 1
	;;
esac
