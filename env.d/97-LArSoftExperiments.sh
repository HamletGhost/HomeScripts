#!/usr/bin/env bash

Setup -Q LArSoft

function isExperiment() {
	
	local -ar ExperimentNames=( 'MicroBooNE' 'DUNE' 'SBND' 'LArIAT' 'ArgoNeuT' 'ICARUS' )
	local -A IFDHExperiments
	local Name
	for Name in "${ExperimentNames[@]}" ; do
		IFDHExperiments[$Name]="${Name,,}"
	done
	
	local Option
	local Format='Default'
	local OldOPTIND=$OPTIND
	OPTIND=1
	while getopts ':fh' Option "$@" ; do
		case "$Option" in
			( 'f' ) Format='IFDH' ;;
			( * )
				if [[ "$Option" == 'h' ]] || [[ "$OPTARG" == '?' ]]; then
					cat <<-EOH
					Detects and prints the experiment the machine belongs to.
					
					Options:
					-f       print the name in "IFDH format"
					-h , -?  print this help message
					EOH
					return 0
				else
					ERROR "${FUNCNAME} does not support option '-${OPTARG}'."
					return 1
				fi
		esac
	done
	OPTIND=$OldOPTIND
		
	local Experiment
	if [[ -d '/uboone' ]]; then
		Experiment="MicroBooNE"
	elif [[ -d '/dune' ]]; then
		Experiment="DUNE"
	elif [[ -d '/lariat' ]]; then
		Experiment="LArIAT"
	elif [[ -d '/lar1nd' ]] || [[ -d '/sbnd' ]] ; then
		Experiment="SBND"
	elif [[ -d '/icarus' ]]; then
		Experiment="ICARUS"
	elif [[ -d '/argoneut' ]]; then
		Experiment="ArgoNeuT"
	fi
	if [[ -z "$Experiment" ]]; then
		ERROR "Can't detect the experiment."
		return 1
	fi
	
	case "$Format" in
		( 'IFDH' )        echo "${IFDHExperiments[$Experiment]}" ;;
		( 'Default' | * ) echo "$Experiment" ;;
	esac
	
} # isExperiment()


function grid_proxy() {
	local Experiment="${1:-$(isExperiment)}"
	local Role="${2:-Analysis}"
	local Server
	local Command
	case "$Experiment" in
		( 'DUNE' )
			###
			### DUNE setup
			###
			Server="dune"
			Command="/dune/Role=${Role}"
			;;
		( 'MicroBooNE' | 'uBooNE' )
			###
			### MicroBooNE setup
			###
			Server="fermilab"
			Command="/fermilab/uboone/Role=${Role}"
			;;
		( 'SBND' )
			###
			### SBND setup
			###
			Server="fermilab"
			Command="/fermilab/sbnd/Role=${Role}"
			;;
		( 'ICARUS' )
			###
			### ICARUS setup
			###
			Server="fermilab"
			Command="/fermilab/icarus/Role=${Role}"
			;;
		( * )
			echo "No grid certificate settings for experiment '${Experiment}'" >&2
			return 1
	esac
	which cigetcert >& /dev/null || setup cigetcert
	cigetcert -s 'fifebatch.fnal.gov' || return $?
	echo "Requesting ${Experiment} certificate: ${Server}${Command:+":${Command}"}"
	voms-proxy-init -noregen -rfc -voms "${Server}${Command:+":${Command}"}"
} # grid_proxy()

unalias grid_proxy >& /dev/null
export -f grid_proxy

