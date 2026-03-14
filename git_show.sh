# =============================================================================
# Git console
# =============================================================================
source ./colour.sh

function git-branch-name {
    git symbolic-ref HEAD 2>/dev/null | cut -d"/" -f 3
}

function git-files-count {
    git st -s 2>/dev/null| wc -l
}

function git-branch-prompt {
    local branch=`git-branch-name`
    local count=$(git-files-count)
    if [ $branch ]; then printf "[${GREEN}%s${RESET}|${RED}%s${RESET}]" $branch $count; fi
}

