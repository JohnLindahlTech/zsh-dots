#!/bin/zsh

REPO_URL_HTTPS="https://github.com/JohnLindahlTech/zsh-dots.git"
REPO_URL_GIT="git@github.com:JohnLindahlTech/zsh-dots.git"

DOTS_DIR=$HOME/.dots

git clone $REPO_URL_HTTPS $DOTS_DIR
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

os=$(echo $OSTYPE | tr '[:upper:]' '[:lower:]')

if [[ "$os" == "linux-gnu"* ]]; then
  echo "Might ask for elevated access:"
  # Linux
  $SUDO apt update
  $SUDO apt install -y --ignore-missing "${tools}"

elif [[ "$os" == "darwin"* ]]; then
  # Mac OSX
  $SUDO export PATH="/usr/local/bin:$PATH"

  # Install hombrew if needed
  if ! which -s brew; then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi

  # Prefetch all binaries
  brew fetch --deps "${tools}" &
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
  $SUDO pkg install -y "${tools}"  || echo "Failed to install tools, will continue..."
else
  #Unknown
  echo "Unknown OS"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ~ || exit

RUNZSH="no" KEEP_ZSHRC="yes" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || echo "Failed to install Oh My ZSH"


echo "$DIR"

ln -s "$DOTS_DIR/themes/nilslarson.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/nilslarson.zsh-theme" || echo ""
cp "$DOTS_DIR/.p10k.zsh" "$HOME/.p10k.zsh"

git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || echo ""

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k || echo ""

if [[ "$os" == "linux-gnu"* ]]; then
  # Linux
  sed -i -e 's#ZSH_THEME="robbyrussell"#ZSH_THEME="powerlevel10k/powerlevel10k"#g' "$HOME/.zshrc"
  sed -i -e 's/plugins=(git)/plugins=(git copypath copybuffer dirhistory copyfile kubectl rsync sudo yarn z zsh-autosuggestions)/g' "$HOME/.zshrc"
  sed -i -e '$ a\
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
' "$HOME/.zshrc"
  sed -i -e '$ a\
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
' "$HOME/.zshrc"


elif [[ "$os" == "darwin"* ]]; then
  # Mac OSX
  sed -i "" 's#ZSH_THEME="robbyrussell"#ZSH_THEME="powerlevel10k/powerlevel10k"#g' "$HOME/.zshrc"
  sed -i "" 's/plugins=(git)/plugins=(git copypath copybuffer dirhistory copyfile kubectl rsync sudo yarn z zsh-autosuggestions)/g' "$HOME/.zshrc"
  sed -i "" '$ a\
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
' "$HOME/.zshrc"
  sed -i '' '$ a\
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
' "$HOME/.zshrc"


elif [[ "$os" == "freebsd"* ]]; then
  # FreeBSD
  sed -i '' 's#ZSH_THEME="robbyrussell"#ZSH_THEME="powerlevel10k/powerlevel10k"#g' "$HOME/.zshrc"
  sed -i '' 's/plugins=(git)/plugins=(git copypath copybuffer dirhistory copyfile kubectl rsync sudo yarn z zsh-autosuggestions)/g' "$HOME/.zshrc"
  sed -i '' '$ a\
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
' "$HOME/.zshrc"
  sed -i '' '$ a\
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
' "$HOME/.zshrc"


else
  #Unknown
  exit 1
fi

