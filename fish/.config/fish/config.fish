if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Use `fish_config theme show` to see the list of themes
# fish_config theme choose "ayu Dark"
fish_config theme choose Nord

# Bind Ctrl+Y to accept autosuggestions
bind \cy accept-autosuggestion

alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias ll='ls -la'
alias lla='ls -la'
alias lt='ls --tree'
# set -x NVIM_APPNAME nvim-lazyvim
alias vi='nvim'
alias vim='nvim'

# Set up fzf key bindings
fzf --fish | source
set -x FZF_DEFAULT_COMMAND "fd --exclude={.git,.idea,.vscode,.sass-cache,node_modules,build} --type f"

# Set up yazi `y` shell wrapper that provides the ability to
# change the current working directory when exiting Yazi.
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# Set up zoxide
zoxide init fish | source
alias j='z'

# Install NPM into home directory with distribution nodejs package
set -x NPM_PACKAGES "$HOME/.npm-packages"

# Cargo env
# source "$HOME/.cargo/env.fish"

# Set $PATH
set -x PATH $PATH $NPM_PACKAGES/bin $HOME/.local/bin $HOME/scripts
