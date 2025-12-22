# vim: foldmethod=marker

# {{{ FG/BG toggle
bind \cz 'fg' # <c-k> to toggle-nvim workflow (dropshell)
# }}}

# {{{ New session in last used DIR
function pwd:set
    set -Ux LAST_PWD $PWD
    export LAST_PWD=$PWD
end

function pwd:get
    cd $LAST_PWD
end

function __fish_save_pwd --on-variable PWD
    pwd:set
end
function fish_greeting
    pwd:get
end
# }}}

# {{{ PROMPT - rightside - shell-depth and shell paths (i.e. zsh -> fish  -> fish (lvl 3)
function fish_shell_depth
    set -l depth (math $SHLVL - 1)
    if test $depth -gt 0
        set -l shells ""
        set -l parent_pid $fish_pid
        for i in (seq $depth)
            set -l parent (ps -o ppid= -p $parent_pid 2>/dev/null | string trim)
            if test -n "$parent"
                set -l pname (ps -o comm= -p $parent 2>/dev/null | string replace -r '.*/(.*)' '$1')
                if test -n "$pname"
                    set shells "$pname › $shells"
                end
                set parent_pid $parent
            end
        end
        echo -n (set_color brblack)"$shells"(set_color yellow)"fish"(set_color brblack)" "(set_color normal)
    end
end
# }}}

# {{{ PROMPT - rightside - command duration (Y-m-d [H:i:s -> H:i:s](~24s) (wall/usr/sys)
set -g __cmd_start_time 0
set -g __cmd_start_date ""

function fish_preexec --on-event fish_preexec
    set -g __cmd_start_time (date +%s)
    set -g __cmd_start_date (date "+%H:%M:%S")
end

function fish_cmd_duration
    if test $CMD_DURATION -gt 100
        set -l end_time (date "+%H:%M:%S")
        set -l dur_ms $CMD_DURATION
        set -l dur_s (math "floor($dur_ms / 1000)")
        set -l dur_str ""

        if test $dur_s -ge 3600
            set dur_str (math "floor($dur_s / 3600)")"h"(math "floor($dur_s % 3600 / 60)")"m"
        else if test $dur_s -ge 60
            set dur_str (math "floor($dur_s / 60)")"m"(math "$dur_s % 60")"s"
        else if test $dur_s -gt 0
            set dur_str $dur_s"s"
        else
            set dur_str $dur_ms"ms"
        end

        set -l date_str (date "+%Y-%m-%d")
        echo -n (set_color brblack)"$date_str ["(set_color cyan)"$__cmd_start_date"(set_color brblack)" → "(set_color cyan)"$end_time"(set_color brblack)"](~"(set_color yellow)"$dur_str"(set_color brblack)")"(set_color normal)
    end
end
# }}}

# {{{ PROMPT - leftside - List of BG jobs and statuses
function fish_bg_jobs
    set -l job_list (jobs)
    if test (count $job_list) -gt 0
        echo (set_color brblack)"─── jobs ───"(set_color normal)
        for job in $job_list
            set -l job_num (echo $job | string match -r '^\s*(\d+)' --groups-only)
            set -l job_state (echo $job | string match -r '(running|stopped)' --groups-only)
            set -l job_cmd (echo $job | string replace -r '^.*\t' '' | string sub -l 30)
            if test "$job_state" = "running"
                echo (set_color green)"  ◆ "(set_color brblack)"[$job_num] "(set_color normal)"$job_cmd"
            else
                echo (set_color yellow)"  ◇ "(set_color brblack)"[$job_num] "(set_color normal)"$job_cmd"
            end
        end
        echo (set_color brblack)"────────────"(set_color normal)
    end
end
# }}}

# {{{ PROMPT - leftside - last status indicator (exit code if not 0)
function fish_status_indicator
    set -l last_status $argv[1]
    if test $last_status -ne 0
        echo -n (set_color red)"× $last_status "(set_color normal)
    end
end
# }}}

# {{{ PROMPT - leftside - pull PWD path in transient shell
function fish_pwd_display
    set -l pwd_path (string replace -r "^$HOME" "~" $PWD)
    echo -n (set_color blue)"$pwd_path"(set_color normal)
end
# }}}

# {{{ PROMPT - leftside - only if in GIT show branch and short info (mergin/rebasing etxc.)
function fish_git_info
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        return
    end

    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    set -l git_state ""

    if test -d .git/rebase-merge -o -d .git/rebase-apply
        set git_state (set_color magenta)"REBASING"
    else if test -f .git/MERGE_HEAD
        set git_state (set_color magenta)"MERGING"
    else if test -f .git/CHERRY_PICK_HEAD
        set git_state (set_color magenta)"CHERRY-PICKING"
    else if test -f .git/BISECT_LOG
        set git_state (set_color magenta)"BISECTING"
    end

    if test -z "$branch"
        set branch (git rev-parse --short HEAD 2>/dev/null)
    end

    echo -n (set_color brblack)" ("(set_color green)"$branch"
    if test -n "$git_state"
        echo -n (set_color brblack)"|$git_state"
    end
    echo -n (set_color brblack)")"(set_color normal)
end
# }}}

# {{{ UX - <c-f> would inline fd files fuzzy select
function fish_fd_fzf
    set -l selected (fd --type f --hidden --follow --exclude .git 2>/dev/null | fzf --height 40% --reverse)
    if test -n "$selected"
        commandline -i -- (string escape -- $selected)
    end
    commandline -f repaint
end
bind \cf fish_fd_fzf
# }}}

# {{{ MAKE SURE THE SHELL IS TRANSIENT and does not break anythin in ansii
set -g __fish_transient_prompt 0

function fish_prompt
    set -l last_status $status
    set -g __fish_last_status $last_status

    if test "$__fish_transient_prompt" = "1"
        set -g __fish_transient_prompt 0
        if test (id -u) -eq 0
            echo -n (set_color red)"⋕ "(set_color normal)
        else
            echo -n (set_color cyan)"⊱⋅"(set_color normal)
        end
        return
    end

    fish_bg_jobs
    fish_status_indicator $last_status
    fish_pwd_display
    fish_git_info
    echo
    if test (id -u) -eq 0
        echo -n (set_color red)"⋕ "(set_color normal)
    else
        echo -n (set_color cyan)"⊱⋅"(set_color normal)
    end
end

function fish_right_prompt
    if test "$__fish_transient_prompt" = "1"
        return
    end
    fish_shell_depth
    fish_cmd_duration
end

function fish_transient_execute
    set -g __fish_transient_prompt 1
    commandline -f repaint
    commandline -f execute
end

bind \r fish_transient_execute
bind \n fish_transient_execute
# }}}

# {{{ USE NATIVE ICONS - UTF-16 tops
# ⋕  - root prompt
# ⊱⋅ - user prompt
# ◆  - running job
# ◇  - stopped job
# ×  - failed command
# ›  - shell chain
# }}}

# {{{ UTIL
function l
    ls -lAh -s -tr $argv # -[t]imesort[r]everse
end

function h
    history merge
    echo history merged
end
# }}}

# {{{ ABBREVIATIONS
abbr -a -g +x chmod +x
abbr -a -g g git
abbr -a -g gst git status
abbr -a -g ga git add
abbr -a -g gc git commit
abbr -a -g gp git push
abbr -a -g gb git branch
abbr -a -g gd git diff
abbr -a -g gr git remote
abbr -a -g gco git checkout
abbr -a -g glog git log --format=fuller --first-parent --abbrev-commit
abbr -a -g rmf rm -rf
# }}}
