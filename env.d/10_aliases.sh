# requires the ??-functions to be loaded
[[ -n "$FUNCTIONS_SH_LOADED" ]] || echo "Warning: bash functions not loaded. Some functions will be missing." >&2

# common aliases
alias du0="du -x --max-depth=0"
alias du1="du -x --max-depth=1"
alias du2="du -x --max-depth=2"
alias v="ls --color=auto -alv"
alias rgrep="grep -R"
alias vi='vim'

alias xc='xclock -update 1'
alias gvv='gv --watch'
alias inject='eject -t'

# some fun here...
alias whereami="echo \$(hostname):\$(pwd)"
alias whenami="date"
alias whyami="echo 42"

function go() { local Dir="$1" ; cd "$Dir" && ls ; }

function chdirl() {
	local Dir="$1"
	chdir "$Dir" && mkdir "logs"
}

# function rl() { readlink -f "${1:-.}" ; }
# full_path() is defined in functions.sh
function rl() { full_path "$1" ; }

