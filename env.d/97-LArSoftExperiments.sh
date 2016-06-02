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


case "$(isExperiment)" in
	( 'DUNE' )
		###
		### DUNE setup
		###
		alias grid_proxy='echo No proxy available for LBNE...'
		break
	( 'MicroBooNE' )
		###
		### MicroBooNE setup
		###
		alias grid_proxy='kx509;voms-proxy-init -noregen -rfc -voms fermilab:/fermilab/uboone/Role=Analysis'
		;;
	( * )
esac

