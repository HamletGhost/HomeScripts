#!/bin/sh

SessionCfgPath="$1"
: ${tmuxConfigDir:="${HOME}/etc/tmux"}

SessionName="${2:-"$(basename "${SessionCfgPath%.conf}")"}"

if ! tmux has-session -t "$SessionName" >& /dev/null ; then
	tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}"
	[[ -f "$tmuxConfig" ]] || tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}.conf"
	
	if [[ ! -r "$tmuxConfig" ]] ; then
		tmux new-session -s "$SessionName"
	elif tmux ls >& /dev/null ; then
		# although our session does not exist, the server is running
		# (with other sessions); we don't need to start the server
		tmux source-file "$tmuxConfig"
	else
		# creating a new server and a session using the configuration file;
		# the configuration file is expected to create the session, detached
		echo "Creating session '${SessionName}'"
		tmux -f "$tmuxConfig" start-server
	fi
fi

tmux attach-session -d -t "$SessionName"

