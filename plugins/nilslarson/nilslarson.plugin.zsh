update(){
  local RED="\033[1;31m" GREEN="\033[1;32m" NOCOLOR="\033[0m"
  local OS=${(L)OSTYPE}

  ## LINUX SPECIFICS
  if [[ "$OS" == "linux-gnu"* ]]; then
    if (( $+commands[midclt] )); then
      # TrueNAS: the OS is managed from its UI/updater; never apt it by hand
      echo "${RED}TRUENAS DETECTED: skipping apt, update the OS from the TrueNAS UI.${NOCOLOR}"
    elif (( $+commands[apt-get] )); then
      local SUDO=sudo
      (( EUID == 0 )) && SUDO=

      echo "${GREEN}Update apt${NOCOLOR}"
      $SUDO apt-get update

      echo "${GREEN}Upgrade apt${NOCOLOR}"
      $SUDO apt-get upgrade -y

      echo "${GREEN}Autoremove apt${NOCOLOR}"
      $SUDO apt-get autoremove -y
    elif (( $+commands[apk] )); then
      local SUDO=sudo
      (( EUID == 0 )) && SUDO=
      (( EUID != 0 && ! $+commands[sudo] && $+commands[doas] )) && SUDO=doas

      echo "${GREEN}Update apk${NOCOLOR}"
      $SUDO apk update

      echo "${GREEN}Upgrade apk${NOCOLOR}"
      $SUDO apk upgrade
    else
      echo "${RED}LINUX WITHOUT APT OR APK NOT YET SUPPORTED.${NOCOLOR}"
    fi


  ## MacOS SPECIFICS
  elif [[ "$OS" == "darwin"* ]]; then
    echo "${GREEN}MacOS Updates${NOCOLOR}"

    echo "${GREEN}Update brew${NOCOLOR}"
    brew update

    echo "${GREEN}Upgrade brew${NOCOLOR}"
    brew upgrade

    echo "${GREEN}Cleanup brew${NOCOLOR}"
    brew cleanup -s --prune-prefix

  ## FreeBSD SPECIFICS
  elif [[ "$OS" == "freebsd"* ]]; then
    echo "${RED}FREEBSD NOT YET SUPPORTED.${NOCOLOR}"
  else
    echo "${RED}UNKNOWN OS (${OS}) NOT YET SUPPORTED.${NOCOLOR}"
  fi

  ## Generics
  local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  local p10k_before=$(git -C "$p10k_dir" rev-parse HEAD 2>/dev/null)

  echo "${GREEN}Update powerlevel10k${NOCOLOR}"
  git -C "$p10k_dir" pull

  # omz update restarts the shell itself (exec zsh) when Oh My Zsh changed,
  # so anything below only runs when it did not.
  echo "${GREEN}Update Oh-my-zsh${NOCOLOR}"
  omz update

  echo "${GREEN}Update Done!${NOCOLOR}"

  # A restart is only needed if what is already loaded in this shell changed.
  local -a changed
  [[ "$(git -C "$p10k_dir" rev-parse HEAD 2>/dev/null)" != "$p10k_before" ]] && changed+=powerlevel10k
  local zsh_now=${${(s: :)"$(command zsh --version 2>/dev/null)"}[2]}
  [[ -n $zsh_now && $zsh_now != $ZSH_VERSION ]] && changed+="zsh ($ZSH_VERSION -> $zsh_now)"

  if (( $#changed )); then
    echo "${RED}!!! Restart terminal to apply changes: ${(j:, :)changed} !!!${NOCOLOR}"
  else
    echo "No restart needed."
  fi
}

## SSH connection sharing (ControlMaster, see ~/.ssh/config)
# Hosts to act on when none are given: every non-wildcard "Host" in ~/.ssh/config
_nilslarson_ssh_hosts() {
  awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' ~/.ssh/config 2>/dev/null
}

# ssh-status [host...]  show which shared connections are alive
ssh-status() {
  local -a hosts=("$@")
  (( $# )) || hosts=(${(f)"$(_nilslarson_ssh_hosts)"})
  local h out found=0
  for h in $hosts; do
    if out=$(ssh -O check "$h" 2>&1); then
      print -r -- "$h: $out"; found=1
    elif (( $# )); then
      print -r -- "$h: not connected"
    fi
  done
  (( found || $# )) || print "No shared SSH connections."
}

# ssh-stop [host...]  graceful: no new sessions, master exits when the current ones end
ssh-stop() {
  local -a hosts=("$@")
  (( $# )) || hosts=(${(f)"$(_nilslarson_ssh_hosts)"})
  local h
  for h in $hosts; do ssh -O stop "$h" 2>/dev/null && print "$h: stopping"; done
}

# ssh-kill [host...]  immediate: closes the master and every session on it (use when one hangs)
ssh-kill() {
  local -a hosts=("$@")
  (( $# )) || hosts=(${(f)"$(_nilslarson_ssh_hosts)"})
  local h
  for h in $hosts; do ssh -O exit "$h" 2>/dev/null && print "$h: closed"; done
}

(( $+functions[compdef] )) && compdef _ssh ssh-status ssh-stop ssh-kill
