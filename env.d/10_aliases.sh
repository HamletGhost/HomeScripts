# requires the ??-functions to be loaded
[[ -n "$FUNCTIONS_SH_LOADED" ]] || echo "Warning: bash functions not loaded." >&2

# common aliases
alias du0="du -x --max-depth=0"
alias du1="du -x --max-depth=1"
alias du2="du -x --max-depth=2"
alias v="ls --color=auto -alv"
alias rgrep="grep -R"
alias vi='vim'

alias xc='xclock -update 1'
alias inject='eject -t'

function chdirl() {
	local Dir="$1"
	chdir "$Dir" && mkdir "logs"
}

function rl() { readlink -f "${1:-.}" ; }


#############################################################################
### which
###
SYSTEM_WHICH="$(readlink -f "$(which which)")"
if [[ -x "$SYSTEM_WHICH" ]]; then
	export SYSTEM_WHICH
	
	function which() {
		if [[ $# == 0 ]]; then
			cat <<EOH

Shows which executable would be executed by giving specified commands.

Usage:  which  ProgramName [...]

For each ProgramName, a line is printed.
If there is a matching alias definition, the alias definition is printed.
Otherwise, if a matching shell function is defined, the complete definition of
the function is printed.
Otherwise, the system-wide "which" program is called.
Return value is 0 if all ProgramName arguments have been resolved, 1 otherwise.

Variables:
SYSTEM_WHICH ('${SYSTEM_WHICH}')
	the complete path of the system-wide "which" program
NOALIASES ('${NOALIASES}')
	if set and non-zero, program names won't be searched in the shell aliases
	list
NOFUNCTIONS ('${NOFUNCTIONS}')
	if set and non-zero, program names won't be searched in the shell functions
	list
NOSYSTEMWHICH ('${NOSYSTEMWHICH}')
	if set and non-zero, program names won't be searched by calling the
	system-wide which program

Example:

NOFUNCTIONS=1 which which
will give the system-wide which program; if NOFUNCTIONS is not set, it will
print the definition of the which you have just called, which is a shell
function.

EOH
			return 1
		fi
		
		local nErrors=0
		for ARG in "$@" ; do
			
			# look in aliases
			if ! isFlagSet NOALIASES ; then
				alias "$ARG" 2> /dev/null
				[[ $? == 0 ]] && continue
			fi
			
			# look in shell functions (mind of spacing of search key in grep and awk)
			if ! isFlagSet NOFUNCTIONS ; then
				if set | grep -q "^$ARG () \$" ; then
					set | awk "{ if (\$0 == \"${ARG} () \") status=1; if (status == 1) { print \$0; if (\$0 == \"}\") exit ; } }" status=0
					continue
				fi
			fi
			
			# ask (true) which to find it for us
			if ! isFlagSet NOSYSTEMWHICH ; then
				"$SYSTEM_WHICH" "$ARG" 2> /dev/null
				[[ $? == 0 ]] && continue
			fi
			
			ERROR "which: no match found for '${ARG}'."
			let ++nErrors
		done
		
		[[ $nErrors -gt 0 ]] && return 1
		return 0
	}
fi

