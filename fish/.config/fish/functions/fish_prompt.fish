function fish_prompt
    set -l last_status $status
    # Prompt status only if it's not 0
    set -l stat
    if test $last_status -ne 0
        set stat (set_color red)"[$last_status]"(set_color normal)
    end

    set -g __fish_git_prompt_show_informative_status 1
    string join '' -- (set_color cyan) '  ' (prompt_pwd -d 8) (fish_git_prompt) (set_color normal) $stat (set_color cyan) '  '
end

function fish_right_prompt
    set_color af8700
    echo -n $hostname
end
