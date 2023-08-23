#!/usr/bin/env bash

Setup -Q LArSoft

function isExperiment() {
	
	local -ar ExperimentNames=( 'MicroBooNE' 'DUNE' 'SBND' 'LArIAT' 'ArgoNeuT' 'ICARUS' )
	local -A IFDHExperiments ExperimentHostNames
	local Name
	for Name in "${ExperimentNames[@]}" ; do
		IFDHExperiments[$Name]="${Name,,}"
		ExperimentHostNames[$Name]="${Name,,}"
	done
	ExperimentHostNames['MicroBooNE']='uboone'
	
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
	local ExperimentCandidate ExperimentHostName
	local HostName="$(hostname)"
	for ExperimentCandidate in "${!ExperimentHostNames[@]}" '' ; do
		[[ "$HostName" =~ ^${ExperimentHostNames[$ExperimentCandidate]} ]] || continue
		Experiment="$ExperimentCandidate"
		break
	done
	if [[ -z "$Experiment" ]]; then
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
	if [[ "$1" != '-f' ]] && [[ "$1" != '--force' ]]; then
		echo "Use \`getToken\` instead (or use --force as first argument to override)." >&2
		return 1
	else
		shift
	fi

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
		( 'SBND' | 'ICARUS' | 'SBN' )
			###
			### SBN/ICARUS/SBND setup
			###
			Server="fermilab"
			Command="/fermilab/${Experiment,,}/Role=${Role}"
			;;
		( * )
			echo "No grid certificate settings for experiment '${Experiment}'" >&2
			return 1
	esac
	which kx509 >& /dev/null || setup kx509
	kx509 || return $?
	echo "Requesting ${Experiment} certificate: ${Server}${Command:+":${Command}"}"
	# valid: 120 hours 0 minutes
	voms-proxy-init -noregen -valid 120:0 -rfc -voms "${Server}${Command:+":${Command}"}"
} # grid_proxy()


function getToken() {
	local Experiment="${1:-$(isExperiment)}"
	htgettoken -a 'htvaultprod.fnal.gov' -i "${Experiment,,}"
} # getToken()


unalias grid_proxy >& /dev/null
export -f grid_proxy getToken isExperiment

