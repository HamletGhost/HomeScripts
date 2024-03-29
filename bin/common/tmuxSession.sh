#!/bin/bash

FallbackTMux=( "${HOME}/local/bin/tmux" "$(which tmux 2> /dev/null)" )

SessionCfgPath="$1"
if [[ -z "$SessionCfgPath" ]]; then
	Experiment="$(isExperiment 2> /dev/null)"
	[[ $? == 0 ]] && [[ -n "$Experiment" ]] && SessionCfgPath="LArS_${Experiment}.conf"
fi

: ${tmuxConfigDir:="${HOME}/etc/tmux"}

SessionName="${2:-"$(basename "${SessionCfgPath%.conf}")"}"

for tmux in "${FallbackTMux[@]}" ; do
	[[ -x "$tmux" ]] && break
done

if [[ ! -x "$tmux" ]] ; then
	echo "Can't run TMux ('${tmux}')." >&2
	exit 2
fi

if ! $tmux has-session -t "$SessionName" >& /dev/null ; then
	tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}"
	[[ -f "$tmuxConfig" ]] || tmuxConfig="${tmuxConfigDir}/${SessionCfgPath}.conf"
	
	if [[ ! -r "$tmuxConfig" ]] ; then
		echo "tmux configuration file '${tmuxConfig}' not found, a plain session will be created."
		$tmux new-session ${SessionName:+-s "$SessionName"}
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
$tmux attach-session -d ${SessionName:+-t "$SessionName"}

