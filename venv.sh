#!/bin/bash
# It is simple version for manage projects env
#
# Add in your ~/.bashrc
#
# # set PATH so it includes user's private bin if it exists
# if [ -d "$HOME/bin" ] ; then
#     PATH="$HOME/bin:$PATH"
# fi
#
# Copy this script into ~/bin and set executable bit chmod +x ~/bin/venv.sh
# Add this script to your ~/.bashrc
# source ~/bin/venv.sh
#

# .workon
# LANGUAGE=go

VENV_LANGUAGE="unknown"
VENV_PROJECT_NAME=""
VENV_WORKING_DIR=""
VENV_PROJECTS_PATH="$HOME/venv"
VENV_VALID_LANGUAGE="python3 go"
PYTHON_ACTIVATE_FILE="bin/activate"
VENV_SOURCE_FILE_NAME=".workon"
VENV_DEFAULT_GOPATH="$HOME/.go"


function _DefineLanguage {
    # args:
    #   path: path to work directory
    local path=${1}
    test -f ${path}/.workon || return 128
    export VENV_LANGUAGE=$(cat ${path}/.workon | grep LANGUAGE|cut -f2 -d =)
    
    return $?
    # echo $(cat ${path}/.workon | grep LANGUAGE|cut -f2 -d =)
}


function _FindWorkProjectDir {
    # args:
    #   prj_name: project name
    local prj_name=${1}
    if [[ -z ${prj_name} ]]; then
        echo "Invalid project name ${prj_name}"
        return 2
    fi
    local project_path=${VENV_PROJECTS_PATH}/${prj_name}
    for x in ${project_path}/src ${project_path}; do
        if [[ -d ${x} ]]; then
            VENV_WORKING_DIR=${x}
            return 0
        fi
    done
    return 2
}

#  Validate language
function _Validate {
    local language=$(printf $1|cut -f 1 -d .)
    echo ${VENV_VALID_LANGUAGE} | grep -F -q -w "$language";
    return $?
}

#  Deactivate python environment
function _Deactivate {
    if [[ -z ${VENV_PROJECT_NAME} ]]; then
        return 0
    fi

    case ${VENV_LANGUAGE} in
    python|PYTHON)
        _PS1SetDefault
        deactivate
        ;;
    go|golang|GO|GOLANG)
        export GOPATH=${VENV_DEFAULT_GOPATH}
        _PS1SetDefault
        ;;
    *)
        _PS1SetDefault
        ;;
    esac
    unset VENV_LANGUAGE VENV_PROJECT_PATH VENV_WORKING_DIR VENV_PROJECT_NAME
}

#  Set default PS1
function _PS1SetDefault() {
    if [[ -n ${_OLD_PRJ_PS1:-} ]]
    then
        PS1=${_OLD_PRJ_PS1:-}
        export PS1
        unset _OLD_PRJ_PS1
    fi
}

#  Save origin PS1
function _PS1Switch() {
    _PS1SetDefault
    export _OLD_PRJ_PS1=${PS1:-}

    # PS1="($1) ${PS1:-}"
    PS1="\033[37;1;41m($1)\033[0m ${PS1:-}" 
    export PS1
}

function CloneGit {
    local gitsource=${1}
    if [[ -n "${gitsource}" ]]; then
        echo "Clonning ${gitsource}"
        git clone ${gitsource} src && cd src
    fi
}


function _ActivateVENV () {
    # args:
    #   prj_name: project name
    _Deactivate

    VENV_PROJECT_NAME=${1}

    if ! _FindWorkProjectDir ${VENV_PROJECT_NAME}; then
        echo "Project ${1} not found"
        return 1
    fi

    if ! _DefineLanguage ${VENV_PROJECTS_PATH}/${1}; then
        echo "File ${VENV_PROJECTS_PATH}/${1}/${VENV_SOURCE_FILE_NAME} must be exist"
        return 1
    fi
    _compose_down $VENV_WORKING_DIR

    alias gowork="cd $VENV_WORKING_DIR"
    cd ${VENV_WORKING_DIR}

    case $VENV_LANGUAGE in

    python|PYTHON)
        echo -e "Activate ${1} [Python]"
        source $VENV_PROJECTS_PATH/$1/$PYTHON_ACTIVATE_FILE
        PS1=$(echo $PS1 | cut -f 2-100 -d " ")
        export PS1
        _PS1Switch ${1}
        ;;

    go|golang|GO|GOLANG)
        echo -e "Activate ${1} [Golang]"
        export GOPATH=${VENV_WORKING_DIR}
        _PS1Switch ${1}
        ;;
    *)
        echo -e "Activate ${1}"
        _PS1Switch ${1}
        ;;
    esac
    _compose_up
}


function _workon_complate ()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(workon -l)" -- $cur) )
}

complete -F _workon_complate workon


#  Create new project
function _CreateProject {
    local PRJ_DIR=$VENV_PROJECTS_PATH/$1
    if [[ -d $PRJ_DIR ]]
    then
        echo "Project \"$1\" already exists"
        unset USE_LANGUAGE SOURCE_GIT
        return 1
    fi
    mkdir -p $PRJ_DIR

    if [[ ${USE_LANGUAGE} == python* ]]; then
        echo "Creating venv for ${USE_LANGUAGE}"
        ${USE_LANGUAGE} -m venv $PRJ_DIR
        cd $PRJ_DIR
        CloneGit ${SOURCE_GIT}
        # if [ -n "${SOURCE_GIT}" ]
        # then
        #     echo "Clonning ${SOURCE_GIT}" 
        #     git clone ${SOURCE_GIT} src && cd src
        # fi
        source $PRJ_DIR/$PYTHON_ACTIVATE_FILE
        echo "LANGUAGE=python" > ${PRJ_DIR}/${VENV_SOURCE_FILE_NAME}
    elif [[ ${USE_LANGUAGE} == go* ]]; then
        echo "LANGUAGE=golang" > ${PRJ_DIR}/${VENV_SOURCE_FILE_NAME}
        echo "Creating venv for ${USE_LANGUAGE}"
        mkdir $PRJ_DIR/src && cd $PRJ_DIR

        CloneGit ${SOURCE_GIT}

        # if [[ -n "${SOURCE_GIT}" ]]; then
        #     echo "Clonning ${SOURCE_GIT}"
        #     git clone ${SOURCE_GIT} src && cd src
        # fi
    elif [[ -n "${SOURCE_GIT}" ]]; then
        cd $PRJ_DIR
        touch ${PRJ_DIR}/${VENV_SOURCE_FILE_NAME}
        CloneGit ${SOURCE_GIT}
        # echo "Clonning source from ${SOURCE_GIT}"
        # git clone ${SOURCE_GIT} $PRJ_DIR
        
        
    else
        cd $PRJ_DIR
        touch ${PRJ_DIR}/${VENV_SOURCE_FILE_NAME}
    fi
    unset USE_LANGUAGE SOURCE_GIT

    echo "Created project '$PRJ_NAME'..."
    _ActivateVENV ${1}
}

#  Up docker-compose
function _compose_up() {
    if [ -f docker-compose.yaml ] && [ $(docker compose ps -q |wc -l) -eq 0 ]
    then
        read -p "Do you want run docker-compose ? " -t 30 yn
        if [ $yn == 'y' ] || [ $yn == 'yes' ]
        then
            result=$(systemctl is-active docker.service )
            if [ $result == 'inactive' ]
            then
                sudo systemctl start docker.socket && sleep 1
                sudo systemctl start docker.service && sleep 3
            fi
            docker compose up -d
            sleep 3
            docker compose ps
        fi
    fi
}

#  Down docker-compose
function _compose_down() {
    if [ "${1}" == "$(pwd)" ]
    then
        # skip down compose for the same project
        return
    fi

    if [ -f docker-compose.yml ] && [ $(docker compose ps -q |wc -l) -ne 0 ]
    then
        read -p "Do you want shutdown docker-compose ? " -t 30 yn
        if [ $yn == 'y' ] || [ $yn == 'yes' ]
        then
            docker compose down
        fi
    fi
}


function workon() {
    ### Manage projects ###
    local OPTIND
    
    case $1 in
        ?)
            printf "Usage: %s: [-c] [-l value] \n" $(basename $0) >&2
            return 2
        ;;    
        -c)
            local PRJ_NAME=$2
            shift 2
            while getopts "l:s:h" arg; do
                case $arg in
                    l)
                        USE_LANGUAGE=$OPTARG
                        if  ! _Validate $USE_LANGUAGE
                        then
                            echo "Unsupported language '$OPTARG'"
                            return 1
                        fi
                    ;;
                    s)
                        SOURCE_GIT=$OPTARG
                    ;;
                    h)
                        echo -e "-l set language\n-s set source to clone"
                        return 0
                    ;;
                esac
            done

            _CreateProject $PRJ_NAME 

        ;;
        -e)
            _Deactivate
            cd $HOME
        ;;
        -d)
            if [[ -d ${VENV_PROJECTS_PATH}/${2} ]]
            then
                _Deactivate
                rm -rf ${VENV_PROJECTS_PATH}/${2}
                cd ${VENV_PROJECTS_PATH}
            fi
        ;;
        -h)
            echo -e "\nUsage: workon [option] <envname>\n\n-h Show help
-c Create prj in $WORK_HOME\n-d Delete prj\n-l List available prj\n-e Exit from prj\n"
        ;;
        -l)
            local venvs=""
            for path in $(ls ${VENV_PROJECTS_PATH});
            do
                venvs+="$(basename ${path}) "
            done
            echo $venvs
        ;;
        *) 
            _ActivateVENV ${1}
        ;;
    esac

}
