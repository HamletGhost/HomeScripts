#!/bin/bash

if which qdbus6 >& /dev/null ; then
    KDEplasma=6
else
    KDEplasma=5
fi

case "$KDEplasma" in
  ( 5 ) qdbus org.kde.ksmserver /KSMServer logout 0 0 0 ;;
  ( 6 ) qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout ;;
  ( * ) echo "${BASH_SOURCE}: internal error (KDEPlasma='${KDEplasma}')." ;;
esac

