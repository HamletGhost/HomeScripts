#!/bin/bash

# unmount the external disk at FNAL
FNALSCD.sh --umount

# disconnect SSH
killall -HUP ssh

# set the screen to laptop only
SetLaptopScreen.sh

