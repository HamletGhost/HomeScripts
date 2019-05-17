#!/bin/bash

if [[ $# == 0 ]]; then
	ping -c 10 -i 0.2 www.google.it || exit
fi
ping www.google.it "$@" | cat -n
