#
# Sets a colorful prompt showing where we are
#

function use_color() {
  
  local ColorDB
  for ColorDB in ~/.dir_colors /etc/DIR_COLORS "" ; do
    [[ -r "$ColorDB" ]] && break
  done

  dircolors -b ${ColorDB:+"${ColorDB}"} | (
    while read Key TerminalPattern Others ; do
      [[ "${Key^^}" == 'TERM' ]] || continue
      [[ "$TERM" == ${TerminalPattern} ]] || continue
      return 0
    done
  )

  # return value is the one from the last command,
  # which is the one from the last element of the pipeline

} # use_color()


# Set colorful PS1 only on colorful terminals.
if use_color ; then
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
unset use_color

