#!/usr/bin/env bash

Setup -Q LArSoft

function isExperiment() {
	if [[ -d '/uboone' ]]; then
		echo "MicroBooNE"
		return 0
	elif [[ -d '/dune' ]]; then
		echo "DUNE"
		return 0
	elif [[ -d '/lariat' ]]; then
		echo "LArIAT"
		return 0
	elif [[ -d '/lar1nd' ]] || [[ -d '/sbnd' ]] ; then
		echo "SBND"
		return 0
	elif [[ -d '/argoneut' ]]; then
		echo "ArgoNeuT"
		return 0
	else
		ERROR "Can't detect the experiment."
		return 1
	fi
} # isExperiment()


function grid_proxy() {
	local Experiment="${1:-$(isExperiment)}"
	local Server
	local Command
	case "$Experiment" in
		( 'DUNE' )
			###
			### DUNE setup
			###
			Server="dune"
			Command="/dune/Role=Analysis"
			;;
		( 'MicroBooNE' | 'uBooNE' )
			###
			### MicroBooNE setup
			###
			Server="fermilab"
			Command="/fermilab/uboone/Role=Analysis"
			;;
		( 'SBND' )
			###
			### MicroBooNE setup
			###
			Server="fermilab"
			Command="/fermilab/sbnd/Role=Analysis"
			;;
		( * )
			echo "No grid certificate settings for experiment '${Experiment}'" >&2
			return 1
	esac
	kx509
	voms-proxy-init -noregen -rfc -voms "${Server}${Command:+":${Command}"}"
} # grid_proxy()

unalias grid_proxy >& /dev/null
export -f grid_proxy
