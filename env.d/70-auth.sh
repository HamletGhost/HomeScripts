# !/usr/bin/env bash
#
# Settings for authentication
#

if [[ -x '/usr/bin/ksshaskpass' ]]; then
  # SSH client password via a KDE interface which is password-manager-aware (`man ssh`):
  export SSH_ASKPASS='/usr/bin/ksshaskpass'
  export SSH_ASKPASS_REQUIRE=prefer  # works when DISPLAY is set; may turn to force to rely on password manager?
fi

# GIT (`man git`)
export GIT_ASKPASS="$SSH_ASKPASS"

