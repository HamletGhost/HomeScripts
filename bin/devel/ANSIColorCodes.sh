#!/bin/bash
#
# Print on screen the extended colors
#

printf 'Extended (256) terminal colors ("\\e[38;5;xxxm": foreground; "\\e[48;5;xxxm": background)'
for (( ColorCode = 0; ColorCode < 256 ; ++ColorCode )); do
	[[ $((ColorCode % 8)) == 0 ]] && printf "\n"
	printf "\e[48;5;${ColorCode}m%4d \e[0;38;5;${ColorCode}m%4d \e[0m" "$ColorCode" "$ColorCode"
done
echo
