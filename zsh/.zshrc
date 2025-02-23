# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

alias ..='cd ..'
alias ...='cd ../..'

alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias ll='ls -la'
alias lla='ls -la'
alias lt='ls --tree'

# export _nvim_binary="/usr/bin/nvim"
# alias nvim="NVIM_APPNAME=nvim $_nvim_binary"          # kickstart or other
# alias nvim="NVIM_APPNAME=nvim-lazyvim $_nvim_binary"  # LazyVim
alias vi='nvim'
alias vim='nvim'

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
export FZF_DEFAULT_COMMAND="fd --exclude={.git,.idea,.vscode,.sass-cache,node_modules,build} --type f"

# https://unix.stackexchange.com/questions/273861/unlimited-history-in-zsh
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
HISTFILE=$HOME/.zsh_history
SAVEHIST=500000
HISTSIZE=500000

# Set up zoxide
eval "$(zoxide init zsh)"
alias j='z'

# Set up ShellGPT
if [[ -x "$HOME/.local/bin/uvx" ]]; then
  alias sgpt="$HOME/.local/bin/uvx --from shell-gpt sgpt"
fi

# Check if the API keys export script exists and source it
if [[ -f "$HOME/.llm-provider/export-api-keys.sh" ]]; then
    source "$HOME/.llm-provider/export-api-keys.sh"
fi

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Set up yazi `y` shell wrapper that provides the ability to
# change the current working directory when exiting Yazi.
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# Install NPM into home directory with distribution nodejs package
NPM_PACKAGES="$HOME/.npm-packages"
# Run ` npm config set prefix "$HOME/.npm-packages" `
# before installing npm packages globally.
# export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

export PATH="$NPM_PACKAGES/bin:$HOME/.local/bin:$HOME/scripts:$PATH"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
[[ -d $PYENV_ROOT/bin ]] && eval "$(pyenv init - zsh)"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source ~/.p10k/powerlevel10k.zsh-theme

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
