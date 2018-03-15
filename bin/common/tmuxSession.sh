#!/bin/bash

SessionCfgPath="$1"
FallbackTMux="${HOME}/local/bin/tmux"

: ${tmuxConfigDir:="${HOME}/etc/tmux"}

SessionName="${2:-"$(basename "${SessionCfgPath%.conf}")"}"

tmux="${FallbackTMux}"
# tmux="$(which tmux 2> /dev/null)"
# if [[ $? != 0 ]]; then
# 	echo "Using fallback tmux at '${FallbackTMux}'"
# 	tmux="${FallbackTMux}"
# fi

if [[ ! -x "$tmux" ]] ; then
	echo "Can't run TMux ('${tmux}')." >&2
	exit 2
fi

if ! $tmux has-session -t "$SessionName" >& /dev/null ; then
	tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}"
	[[ -f "$tmuxConfig" ]] || tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}.conf"
	
	if [[ ! -r "$tmuxConfig" ]] ; then
		echo "tmux configuration file '${tmuxConfig}' not found, a plain session will be created."
		$tmux new-session -s "$SessionName"
	elif $tmux ls >& /dev/null ; then
		echo "Creating a session with configuration file: '${tmuxConfig}'"

		# although our session does not exist, the server is running
		# (with other sessions); we don't need to start the server
		$tmux source-file "$tmuxConfig"
	else
		# creating a new server and a session using the configuration file;
		# the configuration file is expected to create the session, detached
		echo "Starting a server and creating a session with configuration file: '${tmuxConfig}'"
		$tmux -f "$tmuxConfig" start-server
	fi
	echo "Running sessions:"
	$tmux ls
else
	echo "Session '${SessionName}' is already ongoing."
fi

echo "Attaching to session '${SessionName}'"
$tmux attach-session -d -t "$SessionName"

