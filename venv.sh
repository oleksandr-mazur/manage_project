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


PROJECTS_DIR="$HOME/venv"
VALID_LANGUAGE="python3.6 python3.7 python3.8 go"
PYTHON_ACTIVATE_FILE="bin/activate"

_workon_complate ()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(workon -l)" -- $cur) )
}

complete -F _workon_complate workon

validate() {
    ### Validate language ###
    echo ${VALID_LANGUAGE} | grep -F -q -w "$1";
    return $?
}

_is_python_env() {
    if [ -n "${VIRTUAL_ENV}" ]
    then
        return 0
    else
        return 1
    fi
}

_ps1_set_default() {
    ### Set default ps1 ###
    if [[ -n ${_OLD_PRJ_PS1:-} ]]
    then
        PS1=${_OLD_PRJ_PS1:-}
        export PS1
        unset _OLD_PRJ_PS1
    fi

}

_ps1_switch() {
    ###  Save origin PS1 ###
    _ps1_set_default
    export _OLD_PRJ_PS1=${PS1:-}

    PS1="($1) ${PS1:-}"
    export PS1
}

_deactivate() {
    if _is_python_env
    then 
        _ps1_set_default
        deactivate
    else
        if [ -n "${_OLD_PRJ_PS1:-}" ]
        then
            PS1="${_OLD_PRJ_PS1:-}"
            export PS1
            unset _OLD_PRJ_PS1
        fi
    fi
}


_create_prj() {
    ### Create new project ###
    mkdir -p $PROJECTS_DIR
    PRJ_DIR=$PROJECTS_DIR/$1
    if [ -d $PRJ_DIR ]
    then
        echo "Project $1 already exists"
        unset USE_LANGUAGE
        unset SOURCE_GIT
        return 1
    fi

    if [[ x${USE_LANGUAGE} == xpython* ]]
    then
        echo "Creating venv for ${USE_LANGUAGE}}"
        ${USE_LANGUAGE} -m venv $PRJ_DIR
        cd $PRJ_DIR
        if [ -n "${SOURCE_GIT}" ]
        then
            echo "Clonning ${SOURCE_GIT}" 
            git clone ${SOURCE_GIT} src && cd src
        fi
        source $PRJ_DIR/$PYTHON_ACTIVATE_FILE
    elif [ -n "${SOURCE_GIT}" ]
    then
        echo "Clonning source from ${SOURCE_GIT}"
        git clone ${SOURCE_GIT} $PRJ_DIR
        cd $PRJ_DIR
        _ps1_switch $1
    else
        mkdir $PRJ_DIR && cd $PRJ_DIR
        _ps1_switch $1
    fi
    unset USE_LANGUAGE
    unset SOURCE_GIT

    alias gowork="cd $PRJ_DIR"
}

_compose_up() {
    if [ -f docker-compose.yml ] && [ $(docker-compose ps -q |wc -l) -eq 0 ]
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
            docker-compose up -d
            sleep 3
            docker-compose ps
        fi
    fi
}

_compose_down() {
    if [ "${1}" == "$(pwd)" ]
    then
        # skip down compose for the same project
        return
    fi

    if [ -f docker-compose.yml ] && [ $(docker-compose ps -q |wc -l) -ne 0 ]
    then
        read -p "Do you want shutdown docker-compose ? " -t 30 yn
        if [ $yn == 'y' ] || [ $yn == 'yes' ]
        then
            docker-compose down
        fi
    fi
}


workon() {
    ### Manage projects ###
    local OPTIND
    
    case $1 in
        ?)
            printf "Usage: %s: [-c] [-l value] \n" $(basename $0) >&2
            return 2
        ;;    
        -c)
            PRJ_NAME=$2
            shift 2
            while getopts "l:s:h" arg; do
                case $arg in
                    l)
                        USE_LANGUAGE=$OPTARG
                        if  ! validate $USE_LANGUAGE
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

            _create_prj $PRJ_NAME 

            echo "Created project '$PRJ_NAME'..."
        ;;
        -e)
            _deactivate
            cd $HOME
        ;;
        -d)
            if [ -d $PROJECTS_DIR/$2 ]
            then
                _deactivate
                rm -rf $PROJECTS_DIR/$2
                cd $HOME
            fi
        ;;
        -h)
            echo -e "\nUsage: workon [option] <envname>\n\n-h Show help
-c Create prj in $WORK_HOME\n-d Delete prj\n-l List available prj\n-e Exit from prj\n"
        ;;
        -l)
            venvs=""
            for path in $(ls $PROJECTS_DIR);
            do
                venvs+="$(basename ${path}) "
            done
            echo $venvs
        ;;
        *) 
            _deactivate

            if [ -d ${PROJECTS_DIR}/${1}/src ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}/src"
            elif [ -d ${PROJECTS_DIR}/${1} ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}"
            else
                echo -e "Project $1 not found"
                return 2
            fi
            _compose_down $PROJECT_PATH
            
            alias gowork="cd $PROJECT_PATH"
            cd ${PROJECT_PATH}
            
            # check if we use python env
            if [ -f $PROJECTS_DIR/$1/$PYTHON_ACTIVATE_FILE ]
            then
		        _ps1_set_default
                source $PROJECTS_DIR/$1/$PYTHON_ACTIVATE_FILE
            else
                _ps1_switch ${1}
            fi

            _compose_up

        ;;
    esac

}
