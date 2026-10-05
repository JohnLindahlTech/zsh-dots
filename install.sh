#!/bin/zsh
# zsh-dots installer. Idempotent: safe to re-run.
#
# Usage: install.sh [--config-only] [--dry-run] [--on-conflict=MODE]
#
#   --config-only   only (re)apply config files; no packages, clones or downloads
#   --dry-run       show what would change as a diff, write nothing (implies --config-only)
#   --on-conflict   what to do when a file you already have would be changed:
#                     ask (default) | abort | overwrite | merge | skip
#                   also settable with DOTS_ON_CONFLICT. Without a terminal, ask means skip.
#                   Anything overwritten or merged is backed up as <file>.dots-backup-<timestamp>.
#
# Files touched:
#   ~/.zshrc          merged (missing settings are added, your own are kept) or replaced
#   ~/.p10k.zsh       copied from the repo
#   ~/.oh-my-zsh/custom/{themes,plugins}/nilslarson   symlinks into the repo

REPO_URL_HTTPS="https://github.com/JohnLindahlTech/zsh-dots.git"
OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

TOOLS=(git zsh curl wget nano htop)
WANT_PLUGINS=(git sudo z zsh-autosuggestions nilslarson)

CONFIG_ONLY=0
DRY_RUN=0
POLICY=${DOTS_ON_CONFLICT:-ask}

for arg in "$@"; do
  case $arg in
    --config-only)   CONFIG_ONLY=1 ;;
    --dry-run)       DRY_RUN=1; CONFIG_ONLY=1 ;;
    --on-conflict=*) POLICY=${arg#*=} ;;
    -h|--help)       sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               print -u2 "Unknown option: $arg"; exit 2 ;;
  esac
done
[[ $POLICY == (ask|abort|overwrite|merge|skip) ]] || { print -u2 "Bad --on-conflict: $POLICY"; exit 2 }

DOTS_DIR=$HOME/.dots
# Running from a checkout? Then that checkout is the source of truth.
[[ -f $0 && -f ${0:A:h}/.p10k.zsh ]] && DOTS_DIR=${0:A:h}
ZSH_DIR=$HOME/.oh-my-zsh
CUSTOM_DIR=${ZSH_CUSTOM:-$ZSH_DIR/custom}
TS=$(date +%Y%m%d-%H%M%S)
os=${(L)OSTYPE}
WORK=$(mktemp -d) || exit 1
trap 'rm -rf $WORK' EXIT

info() { print -r -- $'\e[1;32m==>\e[0m '"$*" }
warn() { print -r -- $'\e[1;33m==> \e[0m'"$*" >&2 }
die()  { print -r -- $'\e[1;31m==> \e[0m'"$*" >&2; exit 1 }

# ---------------------------------------------------------------- packages

install_packages() {
  local -a missing
  local t
  for t in $TOOLS; do (( $+commands[$t] )) || missing+=$t; done

  if (( $#missing )); then
    local SUDO=sudo
    (( EUID == 0 )) && SUDO=
    info "Installing: $missing (might ask for elevated access)"
    case $os in
      linux-gnu*)
        (( $+commands[apt-get] )) || die "Only apt is supported on Linux; install manually: $missing"
        $SUDO apt-get update -qq && $SUDO apt-get install -y --no-install-recommends $missing ;;
      darwin*)
        if (( ! $+commands[brew] )); then
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || die "brew install failed"
          for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$($b shellenv)" && break; done
        fi
        brew install $missing ;;
      freebsd*)
        $SUDO pkg install -y $missing || warn "Failed to install some tools, continuing..." ;;
      *) die "Unknown OS ($os)" ;;
    esac
  else
    info "Required tools already installed"
  fi

  if [[ $os == darwin* && ${SHELL:t} != zsh ]]; then
    local z=$commands[zsh]
    grep -qx "$z" /etc/shells || print -r -- $z | sudo tee -a /etc/shells >/dev/null
    chsh -s $z
  fi
}

# ---------------------------------------------------------------- repo / omz / clones

sync_repo() {
  if [[ -d $DOTS_DIR/.git ]]; then
    git -C $DOTS_DIR pull --ff-only --quiet || warn "Could not update $DOTS_DIR, using it as is"
  else
    git clone --depth=1 $REPO_URL_HTTPS $DOTS_DIR || die "Could not clone $REPO_URL_HTTPS"
  fi
}

install_omz() {
  if [[ -d $ZSH_DIR ]]; then
    info "Oh My Zsh already installed"
  else
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $OMZ_INSTALL_URL)" || warn "Failed to install Oh My Zsh"
  fi
}

clone_once() { # url dest
  [[ -d $2 ]] && return
  git clone --depth=1 --quiet $1 $2 || warn "Failed to clone $1"
}

# ---------------------------------------------------------------- conflict handling

# choose LABEL CAN_MERGE [DIFF_CMD]  ->  sets CHOICE to abort|overwrite|merge|skip
choose() {
  local label=$1 can_merge=$2 p=$POLICY c opts="[a]bort [o]verwrite"
  (( can_merge )) && opts+=" [m]erge"
  opts+=" [s]kip [d]iff"

  if [[ $p == ask ]] && ! { : </dev/tty } 2>/dev/null; then
    warn "$label differs but there is no terminal to ask on; skipping (use --on-conflict=...)"
    p=skip
  fi
  while [[ $p == ask ]]; do
    read -r "c?$label already exists and differs. $opts? " </dev/tty
    case ${c:l} in
      a*) p=abort ;;
      o*) p=overwrite ;;
      m*) (( can_merge )) && p=merge ;;
      s*) p=skip ;;
      d*) [[ -n $3 ]] && eval $3 ;;
    esac
  done
  if [[ $p == merge ]] && (( ! can_merge )); then
    warn "Can't merge $label; skipping"
    p=skip
  fi
  CHOICE=$p
}

backup() { cp -p $1 $1.dots-backup-$TS && info "Backup: $1.dots-backup-$TS" }
same()   { [[ "$(<$1)" == "$(<$2)" ]] }  # ignores trailing-newline differences

# install_file LABEL DEST FRESH [MERGED] [FORCE]
#   FRESH:  full content DEST should have if we own it
#   MERGED: DEST's content with our changes folded in (omit if merging isn't possible)
#   FORCE:  choice to use without asking (e.g. file was created seconds ago by Oh My Zsh)
install_file() {
  local label=$1 dest=$2 fresh=$3 merged=$4 force=$5
  local can_merge=0 target=$fresh
  [[ -n $merged ]] && { can_merge=1; target=$merged }

  if [[ ! -e $dest ]]; then
    (( DRY_RUN )) && { info "Would create $dest"; return }
    cp $fresh $dest && info "Created $dest"
    return
  fi
  if same $dest $fresh || { (( can_merge )) && same $dest $merged }; then
    info "$label up to date"
    return
  fi
  if (( DRY_RUN )); then
    info "$label would change:"
    diff -u $dest $target
    return
  fi

  if [[ -n $force ]]; then CHOICE=$force; else choose $label $can_merge "diff -u $dest $target | ${PAGER:-cat}"; fi
  case $CHOICE in
    abort)     die "Aborted, nothing further changed." ;;
    skip)      info "Skipped $label" ;;
    overwrite) backup $dest && cp $fresh $dest && info "Replaced $label" ;;
    merge)     backup $dest && cp $merged $dest && info "Merged into $label" ;;
  esac
}

link_item() { # src dest
  local src=$1 dest=$2
  [[ -L $dest && ${dest:A} == ${src:A} ]] && return
  if (( DRY_RUN )); then info "Would link $dest -> $src"; return; fi
  mkdir -p ${dest:h}
  if [[ -e $dest || -L $dest ]]; then
    choose $dest 0 "ls -l $dest"
    case $CHOICE in
      abort) die "Aborted, nothing further changed." ;;
      skip)  info "Skipped $dest"; return ;;
    esac
    mv $dest $dest.dots-backup-$TS && info "Backup: $dest.dots-backup-$TS"
  fi
  ln -s $src $dest && info "Linked $dest"
}

# ---------------------------------------------------------------- .zshrc changes

# apply_zshrc IN OUT: write OUT = IN plus whatever of our settings it is missing.
# Idempotent; never removes or changes anything of yours except the stock
# robbyrussell theme and extra plugins being appended to your plugins=(...).
apply_zshrc() {
  setopt local_options extended_glob
  local -a L out block missing have
  local line i j p text
  local theme_idx=0 plug_start=0 plug_end=0 src_idx=0
  [[ -s $1 ]] && L=("${(@f)$(<$1)}")

  _has() { local l; for l in $L; do [[ $l =~ '^[[:space:]]*#' ]] || [[ ! $l =~ $1 ]] || return 0; done; return 1 }

  # A setting you commented out is a decision, not a gap: don't add it back.
  _off() { local l; for l in $L; do [[ $l =~ '^[[:space:]]*#' && $l =~ $1 ]] && return 0; done; return 1 }

  for (( i = 1; i <= $#L; i++ )); do
    line=$L[i]
    [[ $line =~ '^[[:space:]]*#' ]] && continue
    (( theme_idx )) || [[ $line != ZSH_THEME=* ]] || theme_idx=$i
    (( plug_start )) || [[ $line != plugins=\(* ]] || plug_start=$i
    (( src_idx ))  || [[ $line != *oh-my-zsh.sh* ]] || src_idx=$i
  done

  # theme: only swap the stock default; leave a deliberately chosen theme alone
  if (( theme_idx )); then
    case $L[theme_idx] in
      *powerlevel10k*) ;;
      *robbyrussell*)  L[theme_idx]='ZSH_THEME="powerlevel10k/powerlevel10k"' ;;
      *) warn "Custom ZSH_THEME in .zshrc left untouched; set it to powerlevel10k/powerlevel10k to use the dots prompt" ;;
    esac
  else
    block+='ZSH_THEME="powerlevel10k/powerlevel10k"'
  fi

  # plugins: append the ones that are missing, keep the existing list as written
  if (( plug_start )); then
    for (( j = plug_start; j <= $#L; j++ )); do
      [[ ${L[j]%%\#*} == *\)* ]] && { plug_end=$j; break }
    done
    if (( plug_end )); then
      text=${(j: :)${L[plug_start,plug_end]/\#*/}}
      text=${${text#*plugins=\(}%%\)*}
      have=(${=text})
      for p in $WANT_PLUGINS; do (( $have[(Ie)$p] )) || missing+=$p; done
      if (( $#missing )); then
        local head=${L[plug_end]%%\)*} sep=' '
        [[ -z ${head//[[:space:]]/} ]] && sep='  '   # closing paren on its own line
        L[plug_end]="${head}${sep}${(j: :)missing})${L[plug_end]#*\)}"
      fi
    fi
  else
    block+="plugins=(${WANT_PLUGINS})"
  fi

  # startup tuning
  # (the stock template has a commented example of this line with trailing text; that's not an opt-out)
  _has 'zstyle.*:omz:update.*mode|DISABLE_AUTO_UPDATE' ||
    _off "^[[:space:]]*#[[:space:]]*zstyle ':omz:update' mode disabled[[:space:]]*\$" || block+=(
    "# Skip the update check on every shell start; run 'update' (nilslarson plugin) when you want it."
    "zstyle ':omz:update' mode disabled")
  _has 'ZSH_DISABLE_COMPFIX' || _off 'ZSH_DISABLE_COMPFIX' || block+=(
    "# Skip compaudit's directory-permission scan on every start (fine on a single-user machine)."
    "ZSH_DISABLE_COMPFIX=true")
  _has 'ZSH_AUTOSUGGEST_MANUAL_REBIND' || _off 'ZSH_AUTOSUGGEST_MANUAL_REBIND' || block+=(
    "# Don't re-wrap every ZLE widget before each prompt."
    "ZSH_AUTOSUGGEST_MANUAL_REBIND=1")
  (( $#block )) && block=("# zsh-dots" "${(@)block}" "")

  # instant prompt must be the very first thing in the file
  _has 'p10k-instant-prompt' || _off 'p10k-instant-prompt' || out+=(
    '# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.'
    'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then'
    '  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"'
    'fi'
    '')

  for (( i = 1; i <= $#L; i++ )); do
    (( i == src_idx )) && out+=("${(@)block}")
    out+=("$L[i]")
  done
  (( src_idx )) || out+=("${(@)block}")

  _has 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD' || _off 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD' || out+='POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true'
  _has '\.p10k\.zsh' || _off '\.p10k\.zsh' || out+='[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

  print -rl -- "${(@)out}" > $2
}

configure() {
  local zshrc=$HOME/.zshrc force= merged=

  # A .zshrc that Oh My Zsh just generated for us has nothing of yours in it.
  (( ZSHRC_EXISTED )) || force=merge

  # fresh = stock Oh My Zsh template (or a minimal one) + our changes
  local base=$WORK/base
  if [[ -r $ZSH_DIR/templates/zshrc.zsh-template ]]; then
    cp $ZSH_DIR/templates/zshrc.zsh-template $base
  else
    print -rl -- 'export ZSH="$HOME/.oh-my-zsh"' 'ZSH_THEME="robbyrussell"' 'plugins=(git)' 'source $ZSH/oh-my-zsh.sh' > $base
  fi
  apply_zshrc $base $WORK/fresh
  [[ -e $zshrc ]] && { apply_zshrc $zshrc $WORK/merged; merged=$WORK/merged }

  install_file ".zshrc" $zshrc $WORK/fresh "$merged" $force
  install_file ".p10k.zsh" $HOME/.p10k.zsh $DOTS_DIR/.p10k.zsh

  if [[ -d $ZSH_DIR ]]; then
    link_item $DOTS_DIR/themes/nilslarson.zsh-theme $CUSTOM_DIR/themes/nilslarson.zsh-theme
    link_item $DOTS_DIR/plugins/nilslarson          $CUSTOM_DIR/plugins/nilslarson
  fi
}

# ---------------------------------------------------------------- main

ZSHRC_EXISTED=0; [[ -e $HOME/.zshrc ]] && ZSHRC_EXISTED=1

if (( ! CONFIG_ONLY )); then
  install_packages
  sync_repo
  install_omz
  clone_once https://github.com/zsh-users/zsh-autosuggestions $CUSTOM_DIR/plugins/zsh-autosuggestions
  clone_once https://github.com/romkatv/powerlevel10k.git      $CUSTOM_DIR/themes/powerlevel10k
fi

[[ -f $DOTS_DIR/.p10k.zsh ]] || die "$DOTS_DIR is not a zsh-dots checkout"
configure
(( DRY_RUN )) || info "Done. Open a new terminal to apply."
