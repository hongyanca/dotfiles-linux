function set_prompt_icon
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

    # If you want to force a specific icon regardless of OS,
    # uncomment one of these:
    # set prompt_icon 󰦝
    # set prompt_icon 
    # set prompt_icon 

    echo $prompt_icon
end
