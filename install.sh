#!/bin/bash

REPO_URL_HTTPS="https://github.com/JohnLindahlTech/zsh-dots.git"
REPO_URL_GIT="git@github.com:JohnLindahlTech/zsh-dots.git"

# if [[ "$OSTYPE" == "linux-gnu"* ]]; then
#   # Linux
# elif [[ "$OSTYPE" == "darwin"* ]]; then
#   # Mac OSX
# elif [[ "$OSTYPE" == "freebsd"* ]]; then
#   # FreeBSD
# else
#   #Unknown
#   exit 1
# fi

tools="git zsh wget curl nano htop"
me="$(whoami)"

if [[ $me == "root" ]]; then
  SUDO=""
else 
  SUDO="sudo"
fi

const os = $OSTYPE | tr '[:upper:]' '[:lower:]';


if [[ "$os" == "linux-gnu"* ]]; then
  echo "Might ask for elevated access:"
  # Linux
  $SUDO apt update
  $SUDO apt install ${tools} -y

elif [[ "$os" == "darwin"* ]]; then
  # Mac OSX
  $SUDO export PATH="/usr/local/bin:$PATH"

  # Install hombrew if needed
  if ! which -s brew; then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  # Prefetch all binaries
  brew fetch --deps ${tools} &
  wait

  # Install brew cask
  brew cask &
  wait

  # Install all binaries
  for p in ${tools}; do
    brew info "$p" | grep -q "Not installed" && brew install "$p"
  done

  $SUDO sh -c "echo $(which zsh) >> /etc/shells" && chsh -s $(which zsh)

elif [[ "$os" == "freebsd"* ]]; then
  # FreeBSD
  $SUDO pkg update || echo "Failed to update pkg."
  $SUDO pkg install -y ${tools}  || echo "Failed to install tools, will continue..."
else
  #Unknown
  echo "Unknown OS"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ~ || exit

RUNZSH="no" KEEP_ZSHRC="yes" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || echo "Failed to install Oh My ZSH"

rm -rf "./.oh-my-zsh/custom/themes"
rm -rf "./.oh-my-zsh/custom/plugins"

echo "$DIR"

ln -s "$DIR/themes" "./.oh-my-zsh/custom/themes" || echo ""
ln -s "$DIR/plugins" "./.oh-my-zsh/custom/plugins" || echo ""

git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || echo ""



if [[ "$os" == "linux-gnu"* ]]; then
  # Linux
  sed -i -e 's/ZSH_THEME="robbyrussell"/ZSH_THEME="nilslarson"/g' ./.zshrc
  sed -i -e 's/plugins=(git)/plugins=(git kubectl rsync sudo yarn z zsh-autosuggestions)/g' ./.zshrc
elif [[ "$os" == "darwin"* ]]; then
  # Mac OSX
  sed -i "" 's/ZSH_THEME="robbyrussell"/ZSH_THEME="nilslarson"/g' ./.zshrc
  sed -i "" 's/plugins=(git)/plugins=(git kubectl rsync sudo yarn z zsh-autosuggestions)/g' ./.zshrc
elif [[ "$os" == "freebsd"* ]]; then
  # FreeBSD
  sed -i "" 's/ZSH_THEME="robbyrussell"/ZSH_THEME="nilslarson"/g' ./.zshrc
  sed -i "" 's/plugins=(git)/plugins=(git kubectl rsync sudo yarn z zsh-autosuggestions)/g' ./.zshrc
else
  #Unknown
  exit 1
fi


