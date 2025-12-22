# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# https://github.com/basecamp/omarchy/tree/master/default/bash

## shell #################################################################################
# History control
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE="${HISTSIZE}"

# Autocompletion
if [[ ! -v BASH_COMPLETION_VERSINFO && -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

# Ensure command hashing is off for mise
set +h

## alias ################################################################################
# File system
# if command -v eza &>/dev/null; then
#  alias ls='eza -lh --group-directories-first --icons=auto'
#  alias lsa='ls -a'
#  alias lt='eza --tree --level=2 --long --icons --git'
#  alias lta='lt -a'
# fi

# if command -v lsd &>/dev/null; then
#  alias ls='lsd'
#  alias lt='ls --tree'
# fi
alias l='ls -l'
alias la='ls -a'
alias ll='ls -la'
alias lla='ls -la'

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

if command -v zoxide &>/dev/null; then
  alias cd="zd"
  zd() {
    if [ $# -eq 0 ]; then
      builtin cd ~ && return
    elif [ -d "$1" ]; then
      builtin cd "$1"
    else
      z "$@" && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"
    fi
  }
fi

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

## prompt ###############################################################################
# Technicolor dreams
force_color_prompt=yes
color_prompt=yes

# Simple bash prompt
if [[ $EUID -eq 0 ]]; then
  PS1='\u@\h:\w # '
else
  PS1='\u@\h:\w $ '
fi

## envs #################################################################################
# Editor used by CLI
if command -v nvim &>/dev/null; then
  alias vi='nvim'
  alias vim='nvim'
  export EDITOR='nvim'
  export VISUAL='nvim'
  export SUDO_EDITOR="$EDITOR"
fi
export BAT_THEME=ansi

## init #################################################################################
# Set up mise
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate bash)"
fi

if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

if command -v fzf &>/dev/null; then
  # Set up fzf key bindings and fuzzy completion
  eval "$(fzf --bash)"
fi

## inputrc ##############################################################################
set meta-flag on
set input-meta on
set output-meta on
set convert-meta off
set completion-ignore-case on
set completion-prefix-display-length 2
set show-all-if-ambiguous on
set show-all-if-unmodified on

# Immediately add a trailing slash when autocompleting symlinks to directories
set mark-symlinked-directories on

# Do not autocomplete hidden files unless the pattern explicitly begins with a dot
set match-hidden-files off

# Show all autocomplete results at once
set page-completions off

# If there are more than 200 possible completions for a word, ask to show them all
set completion-query-items 200

# Show extra file information when completing, like `ls -F` does
set visible-stats on

# Be more intelligent when autocompleting by also looking at the text after
# the cursor. For example, when the current line is "cd ~/src/mozil", and
# the cursor is on the "z", pressing Tab will not autocomplete it to "cd
# ~/src/mozillail", but to "cd ~/src/mozilla". (This is supported by the
# Readline used by Bash 4.)
set skip-completed-text on

# Coloring for Bash 4 tab completions.
set colored-stats on

##### Append ~/scripts/ to PATH #####
export PATH="$HOME/scripts:$PATH"

# Set up global npm packages path
# mkdir "${HOME}/.npm-packages"
# npm config set prefix "${HOME}/.npm-packages"
NPM_PACKAGES="$HOME/.npm-packages"
if [[ -d "$NPM_PACKAGES" ]]; then
  export PATH="$NPM_PACKAGES/bin:$PATH"
fi

# pnpm
if [ -f "$HOME/.local/share/pnpm/pnpm" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  alias pn='pnpm'
fi
# pnpm end
