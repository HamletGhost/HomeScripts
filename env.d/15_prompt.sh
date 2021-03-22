#
# Sets a colorful prompt showing where we are
#

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.
# We run dircolors directly due to its changes in file syntax and
# terminal name patching.
use_color=false
if type -P dircolors >/dev/null ; then
	# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
	LS_COLORS=
	if [[ -f ~/.dir_colors ]] ; then
		eval "$(dircolors -b ~/.dir_colors)"
	elif [[ -f /etc/DIR_COLORS ]] ; then
		eval "$(dircolors -b /etc/DIR_COLORS)"
	else
		eval "$(dircolors -b)"
	fi
	# Note: We always evaluate the LS_COLORS setting even when it's the
	# default.  If it isn't set, then `ls` will only colorize by default
	# based on file attributes and ignore extensions (even the compiled
	# in defaults of dircolors). #583814
	if [[ -n ${LS_COLORS:+set} ]] ; then
		use_color=true
	else
		# Delete it if it's empty as it's useless in that case.
		unset LS_COLORS
	fi
else
	# Some systems (e.g. BSD & embedded) don't typically come with
	# dircolors so we need to hardcode some terminals in here.
	case ${TERM} in
	[aEkx]term*|rxvt*|gnome*|konsole*|screen|cons25|*color) use_color=true;;
	esac
fi

isBSD && use_color=true

if ${use_color} ; then
	# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
	if type -P dircolors >/dev/null ; then
		if [[ -f ~/.dir_colors ]] ; then
			eval $(dircolors -b ~/.dir_colors)
		elif [[ -f /etc/DIR_COLORS ]] ; then
			eval $(dircolors -b /etc/DIR_COLORS)
		fi
	fi

        if [[ ${EUID} == 0 ]] ; then
                PS1='\[\033[01;31m\]\h\[\033[01;34m\]:\w\$\[\033[00m\] '
        else
                PS1='\[\033[01;37m\]\u\[\033[0m\]@\[\033[01;32m\]\h\[\033[01;34m\]:\w\$\[\033[00m\] '
        fi

else
        if [[ ${EUID} == 0 ]] ; then
                # show root@ when we don't have colors
                PS1='\u@\h:\w\$ '
        else
                PS1='\u@\h:\w\$ '
        fi
fi

# debug prompt with file and line number
shopt -s promptvars
export PS4='+ ${BASH_SOURCE[0]:-"<?>"}:${LINENO} '

# Try to keep environment pollution down, EPA loves us.
unset use_color safe_term match_lhs

