source ./colour.sh

_aws_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    local options=$(grep '^\[' ~/.aws/credentials | tr -d '[]')

    COMPREPLY=($(compgen -W "$options" -- "$cur"))
}

function get_aws_profile() {
    local profile=$(grep '^\[' ~/.aws/credentials | tr -d '[]' | grep -F -w "$AWS_PROFILE")
    if [[ -n ${profile} ]]; then
        printf "${BOLD}${YELLOW}(AWS:$profile)${RESET}"
    fi
}

function aws-switch() {
    if [[ -z ${1} ]]; then
        echo "Usage: aws-switch <profile_name>"
        return 1
    fi
    export AWS_PROFILE=${1}
}

complete -F _aws_completion aws-switch

