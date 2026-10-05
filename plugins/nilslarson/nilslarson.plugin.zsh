update(){
  local RED="\033[1;31m" GREEN="\033[1;32m" NOCOLOR="\033[0m"
  local OS=${(L)OSTYPE}

  ## LINUX SPECIFICS
  if [[ "$OS" == "linux-gnu"* ]]; then
    if (( $+commands[apt-get] )); then
      local SUDO=sudo
      (( EUID == 0 )) && SUDO=

      echo "${GREEN}Update apt${NOCOLOR}"
      $SUDO apt-get update

      echo "${GREEN}Upgrade apt${NOCOLOR}"
      $SUDO apt-get upgrade -y

      echo "${GREEN}Autoremove apt${NOCOLOR}"
      $SUDO apt-get autoremove -y
    else
      echo "${RED}LINUX WITHOUT APT NOT YET SUPPORTED.${NOCOLOR}"
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
