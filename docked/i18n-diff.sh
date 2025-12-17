#!/bin/bash
#| Check translation strings.
#| Script must be run from within git repo.
#|
#| Program usage:
#|    check-strings [<sha-then>] [<sha-now>]
#|
#| Examples:
#|    * Last commit checked.
#|    $~ check-strings $(git rev-parse HEAD^) $(git rev-parse HEAD)
#|
#|    * Any commit checked, by revrapsing it's parent.
#|    $~ check-strings $(git rev-parse <sha>^) <sha>
#|
#|    * Changes in this branch
#|    $~ check-strings $(git rev-parse <sha>^) <sha>
#|
#|    * Auto-detect merge point (if no args provided on a branch)
#|    $~ check-strings
#|
#| Known issues:
#|    * If you have merged an "updated to latest from .." you will get inherited changes.
#|    * Correct output is possible by providing most recent merge right sha as first argument like so:
#|    * ~$ check-strings $(git log --merges -n 1 | grep -e "^Merge" | awk '{print $3}') HEAD
#|    * See translation strings that have newlines are missed, because of egrep in last line of script. For now I think about rewriting egrep into sed or awk, because I did not find any gettext flags to do "\n| normalization .. see: https://www.gnu.org/software/gettext/manual/gettext.html
[[ $1 == -h ]] && grep '^#|' $0 | sed 's/^#//' && exit 0

# Auto-detect comparison refs if not provided
if [[ $# -eq 0 ]]; then
    echo "Auto-detecting comparison refs..."

    # Get current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    if [[ $current_branch == "HEAD" ]]; then
        echo "Error: Detached HEAD state. Please provide refs manually." >&2
        exit 1
    fi

    # Try to find the most recent merge commit
    merge_commit=$(git log --merges -n 1 --format="%H" 2>/dev/null)

    if [[ -n $merge_commit ]]; then
        # Get the merge base (the point where branch diverged)
        # The second parent of a merge commit is typically the merged branch
        merge_parent=$(git log --merges -n 1 --format="%P" | awk '{print $2}')

        if [[ -n $merge_parent ]]; then
            echo "Found recent merge. Using merge point as comparison base."
            then_ref=$merge_parent
            now_ref="HEAD"
        else
            # Fallback: use merge-base with upstream
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
            if [[ -z $default_branch ]]; then
                default_branch="main"
            fi

            merge_base=$(git merge-base HEAD origin/$default_branch 2>/dev/null)
            if [[ -n $merge_base ]]; then
                echo "Using merge-base with origin/$default_branch"
                then_ref=$merge_base
                now_ref="HEAD"
            else
                echo "Error: Could not auto-detect refs. Please provide them manually." >&2
                exit 1
            fi
        fi
    else
        # No merges found, try merge-base with upstream
        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        if [[ -z $default_branch ]]; then
            # Try common default branch names
            for branch in main master develop; do
                if git rev-parse origin/$branch >/dev/null 2>&1; then
                    default_branch=$branch
                    break
                fi
            done
        fi

        if [[ -n $default_branch ]]; then
            merge_base=$(git merge-base HEAD origin/$default_branch 2>/dev/null)
            if [[ -n $merge_base ]]; then
                echo "Using merge-base with origin/$default_branch"
                then_ref=$merge_base
                now_ref="HEAD"
            else
                echo "Error: Could not find merge-base. Please provide refs manually." >&2
                exit 1
            fi
        else
            echo "Error: Could not detect default branch. Please provide refs manually." >&2
            exit 1
        fi
    fi

    echo "Comparing: $then_ref (base) -> $now_ref (current)"
    echo
elif [[ $# -ne 2 ]]; then
    grep '^#|' $0 | sed 's/^#//'
    exit 1
else
    then_ref=$1
    now_ref=$2
fi

git rev-parse $then_ref $now_ref 1> /dev/null || exit 2

rm -rf /tmp/_chstr
mkdir /tmp/_chstr

# $1 <commit-ish>
# $? stdout
mk_pot() {
    git archive $1 > /tmp/_chstr/$1.tar
    tar -xf /tmp/_chstr/$1.tar --one-top-level=/tmp/_chstr/$1
    cd /tmp/_chstr/$1
    find /tmp/_chstr/$1 -type f -name "*.php" > /tmp/_chstr/$1/_phpfiles
    xgettext \
        --files-from=_phpfiles \
        --output=- \
        --keyword=_n:1,2 \
        --keyword=_s \
        --keyword=_x:1,2c \
        --keyword=_xs:1,2c \
        --keyword=_xn:1,2,4c \
        --from-code=UTF-8 \
        --language=php \
        --no-wrap \
        --sort-output \
        --no-location \
        --omit-header
}

jira_fmt() {
    exec 8<>/tmp/_chstr/$then_ref-$now_ref-removed
    exec 9<>/tmp/_chstr/$then_ref-$now_ref-added

    echo "Strings added:" >&9;
    echo "Strings deleted:" >&8;

    while IFS= read line; do
        fd=8 && [[ $line =~ ^\< ]] || fd=9

        echo "${line}" |
        sed -r '/[<>] msgctxt/ {:a;N;s/[<>] msgctxt "(.+)"\n[<>] msgid "(.+)"/- _\2_ *context:* _\1_/g}' | \
        sed -r 's/^(<|>) msgid(_plural){0,1} "/- _/g' | \
        sed -r 's/"$/_/g' | \
        sed -r 's/\\"/"/g' \
            >&$fd
    done

    diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/8 /dev/fd/9
    echo
    diff --changed-group-format="%>" --unchanged-group-format="" /dev/fd/9 /dev/fd/8

    exec 9>&-
    exec 8>&-
}

diff <(mk_pot $then_ref) <(mk_pot $now_ref) | \
    egrep '[<>] (msgid|msgctxt)' | jira_fmt
