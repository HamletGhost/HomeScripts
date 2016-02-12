if [[ -r "${HOME}/bin/env/LoadSetup" ]]; then
	source "${HOME}/bin/env/LoadSetup"
	Setup -q2 bin ""
	Setup -q2 terminal ""
fi

