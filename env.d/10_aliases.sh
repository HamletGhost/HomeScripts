# requires the ??-functions to be loaded
[[ -n "$FUNCTIONS_SH_LOADED" ]] || echo "Warning: bash functions not loaded. Some functions will be missing." >&2

# this is fundamental enough that we provide a local implementation here:
declare -F isBSD > /dev/null || function isBSD() { [[ "$(uname)" != "Linux" ]]; }

# common aliases
alias du0="du -x -d0"
alias du1="du -x -d1"
alias du2="du -x -d2"

if isBSD ; then
  alias ls="ls -G"
  alias v="ls -al"
  function tailf() { tail -f "$@" ; }
  export -f tailf
else
  alias ls="ls --color=auto"
  alias v="ls --color=auto -alv"
fi
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

# function rl() { readlink -f "${1:-.}" ; }
# full_path() is defined in functions.sh
function rl() { full_path "$1" ; }

