RED="\033[1;31m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"

update(){

  OS=$(echo $OSTYPE | tr '[:upper:]' '[:lower:]')

  ## LINUX SPECIFICS
  if [[ "$OS" == "linux-gnu"* ]]; then
    echo "${RED}LINUX NOT YET SUPPORTED.${NOCOLOR}"


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
  echo "${GREEN}Update powerlevel10k${NOCOLOR}"
  git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" pull

  echo "${GREEN}Update Oh-my-zsh${NOCOLOR}"
  omz update

  echo "${GREEN}Update Done!${NOCOLOR}"
  echo "${RED}!!! Restart terminal to apply changes !!!${NOCOLOR}"
}
