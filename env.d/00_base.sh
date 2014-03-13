#
# User base environment settings
# Sourced by user's .bashrc
#

if [[ -z "$FUNCTIONS_SH_LOADED" ]] && [[ -r "${HOME}/bin/common/functions.sh" ]]; then
	source "${HOME}/bin/common/functions.sh"
fi

