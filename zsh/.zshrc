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

alias k='kubectl'

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

# Check if the API keys export script exists and source it
if [[ -f "$HOME/.llm-provider/export-api-keys.sh" ]]; then
    source "$HOME/.llm-provider/export-api-keys.sh"
fi

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Start ssh-agent if not already running
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
  eval "$(ssh-agent -s)" > /dev/null 2>&1
fi
# ssh-add ~/.ssh/YOUR_GITHUB_SSH_PRIVATE_KEY > /dev/null 2>&1

# Set up mise
if [[ -f "$HOME/.local/bin/mise" ]]; then
  eval "$($HOME/.local/bin/mise activate zsh)"
fi

export PATH="$HOME/scripts:$PATH"

# Set up global npm packages path
# mkdir "${HOME}/.npm-packages"
# npm config set prefix "${HOME}/.npm-packages"
NPM_PACKAGES="$HOME/.npm-packages"
if [[ -d "$NPM_PACKAGES" ]]; then
  export PATH="$NPM_PACKAGES/bin:$PATH"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source ~/.p10k/powerlevel10k.zsh-theme

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
