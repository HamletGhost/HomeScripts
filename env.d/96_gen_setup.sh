if [[ -r "${HOME}/bin/env/LoadSetup" ]]; then
	source "${HOME}/bin/env/LoadSetup"
	Setup -Q bin
	Setup terminal
fi

