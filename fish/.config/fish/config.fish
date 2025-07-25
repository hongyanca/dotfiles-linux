if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Use `fish_config theme show` to see the list of themes
# fish_config theme choose "ayu Dark"
fish_config theme choose Nord

alias ...='cd ../..'

alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias ll='ls -la'
alias lla='ls -la'
alias lt='ls --tree'

alias k='kubectl'

# set -x _nvim_binary "/usr/bin/nvim"
# alias nvim="$_nvim_binary"
# set -x NVIM_APPNAME nvim          # kickstart or other
# set -x NVIM_APPNAME nvim-lazyvim  # LazyVim
alias vi="nvim"
alias vim="nvim"
# Alt+E edit the current command line in an external editor.
# The editor is chosen from the first available of the
# $VISUAL or $EDITOR variables.
set -x EDITOR nvim

# Set up fzf key bindings
fzf --fish | source
set -x FZF_DEFAULT_COMMAND "fd --exclude={.git,.idea,.vscode,.sass-cache,node_modules,build} --type f"

# Set up zoxide
zoxide init fish | source
alias j='z'

# Cargo env
if test -f "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

# Set up mise
if test -f "$HOME/.local/bin/mise"
    "$HOME/.local/bin/mise" activate fish | source
end

# Check if the API keys export script exists and source it
if test -f "$HOME/.llm-provider/export-api-keys.fish"
    source "$HOME/.llm-provider/export-api-keys.fish"
end

# Set $PATH
set -x PATH $PATH $HOME/.local/bin $HOME/scripts
