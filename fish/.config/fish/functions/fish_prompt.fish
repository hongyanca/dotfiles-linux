function fish_prompt
    set -g __fish_git_prompt_show_informative_status 1

    set -l prompt_icon
    # Check if /etc/os-release exists
    if test -f /etc/os-release
        # Read the OS ID from /etc/os-release
        set os_id (grep -E '^ID=' /etc/os-release | sed 's/"//g' | sed 's/ID=//g')
        # Match OS ID to NerdFont icons
        switch $os_id
            case ubuntu
                set prompt_icon  # Ubuntu icon
            case arch
                set prompt_icon  # Arch Linux icon
            case rhel
                set prompt_icon 󱄛 # RHEL icon
            case fedora
                set prompt_icon  # Fedora icon
            case debian
                set prompt_icon  # Debian icon
            case centos
                set prompt_icon  # CentOS icon
            case almalinux
                set prompt_icon  # AlmaLinux icon
            case '*'
                # Default icon for unknown OS
                set prompt_icon  # Linux penguin icon
        end
    end
    # Other icon options
    #set prompt_icon 󰦝
    #set prompt_icon 
    #set prompt_icon 

    # fish version 3.7 and higher supports 'prompt_pwd -d'
    set fish_version (fish --version | grep -Eo '[0-9]+\.[0-9]+' )
    set fish_major_minor (string split '.' $fish_version)

    if test $fish_major_minor[1] -eq 4; or test \( $fish_major_minor[1] -eq 3 -a $fish_major_minor[2] -ge 7 \)
        string join '' -- (set_color cyan) $prompt_icon ' ' (prompt_pwd -d 12) (fish_git_prompt) (set_color normal) $stat (set_color cyan) '  '
    else
        string join '' -- (set_color cyan) $prompt_icon ' ' (prompt_pwd) (fish_git_prompt) (set_color normal) $stat (set_color cyan) '  '
    end

end

function fish_right_prompt
    set -l last_status $status
    # Prompt status only if it's not 0
    set -l stat
    if test $last_status -ne 0
        set stat (set_color red)"[$last_status]"(set_color normal)
    end

    set_color af8700
    echo -n $stat $hostname
end
