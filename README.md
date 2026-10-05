# zsh-dots

## Prerequirements
* curl/wget
* git
* zsh

## Install

```bash
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/JohnLindahlTech/zsh-dots/main/install.sh)"
```

```bash
zsh -c "$(wget https://raw.githubusercontent.com/JohnLindahlTech/zsh-dots/main/install.sh -O -)"
```

```bash
zsh ./install.sh
```

## Existing config

The installer never silently clobbers files you already have (`~/.zshrc`, `~/.p10k.zsh`, the theme/plugin symlinks).
If one would change it asks: **abort**, **overwrite** (backed up), **merge** (`.zshrc` only: missing settings are added, your own are kept) or **skip**, with **diff** to look first.
Everything it changes is backed up as `<file>.dots-backup-<timestamp>`.

```bash
zsh ./install.sh --dry-run                  # show the diff, write nothing
zsh ./install.sh --config-only              # just (re)apply config files, no packages or downloads
zsh ./install.sh --on-conflict=merge        # ask | abort | overwrite | merge | skip (no terminal: ask = skip)
```

It is safe to re-run.

## Uninstall
```bash
rm -rf  ~/.p10k.zsh ~/.zshrc ~/.oh-my-zsh ~/.dots
```