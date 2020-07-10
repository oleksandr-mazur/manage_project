#!/bin/bash
# It is simple version for manage virtual python env
#
# Add in your ~/.profile
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

ps1() {
    ###  Save origin PS1 ###

    if [ -n "${_OLD_PRJ_PS1:-}" ] ; then
        PS1="${_OLD_PRJ_PS1:-}"
        export PS1
        unset _OLD_PRJ_PS1
    fi

    # if [ -z _OLD_PRJ_PS1 ]
    # then
    _OLD_PRJ_PS1="${PS1:-}"
    # fi

    PS1="($1) ${PS1:-}"
    export PS1
}



_create_prj() {
    ### Create new project ###
    mkdir -p $PROJECTS_DIR
    PRJ_DIR=$PROJECTS_DIR/$1
    if [ -d $PRJ_DIR ]
    then
        echo "Project $1 already exists"
        return
    fi

    if [[ x$LANGUAGE == xpython* ]]
    then
        ${LANGUAGE} -m venv $PRJ_DIR
        cd $PRJ_DIR
        source $PRJ_DIR/$PYTHON_ACTIVATE_FILE
    else
        mkdir $PRJ_DIR && cd $PRJ_DIR
        ps1 $1
    fi
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
            # exit 2
        ;;    
        -c)
            PRJ_NAME=$2
            shift 2
            getopts 'l:' args
            LANGUAGE=$OPTARG
            if  [ $args == "l" ] && ! validate $LANGUAGE
            then
                echo "Unsupported language '$OPTARG'"
                return
            fi
            _create_prj $PRJ_NAME
            echo "Created project '$PRJ_NAME'..."
        ;;
        -d)
            if [ -d $PROJECTS_DIR/$1 ]
            then
                if [ -n deactivate  ]
                then
                    deactivate
                fi
                rm -rf $PROJECTS_DIR/$1
            fi
        ;;
        -h)
            echo -e "\nUsage: workon [option] <envname>\n\n-h Show help
-c Create env in $WORK_HOME\n-d Delete env\n-l List available env\n-p Create enter point\n"
        ;;
        -l)
            venvs=""
            # for path in $(find $PROJECTS_DIR -type d 2>/dev/null);
            for path in $(ls $PROJECTS_DIR);
            do
                venvs+="$(basename ${path}) "
            done
            echo $venvs
        ;;
        *) 
            # deactivate old env
	    # or use #declare -F deactivate > /dev/null
            if type deactivate > /dev/null 2>&1
            then
                deactivate
            fi

            _compose_down

            if [ -d ${PROJECTS_DIR}/${1}/src ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}/src"
            elif [ -d ${PROJECTS_DIR}/${1} ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}"
            else
                echo -e "Venv $1 not found"
                exit 2
            fi
            
            alias gowork="cd $PROJECT_PATH"
            cd ${PROJECT_PATH}
            
            # check if we use python env
            if [ -f $PROJECTS_DIR/$1/$PYTHON_ACTIVATE_FILE ]
            then
                source $PROJECTS_DIR/$1/$PYTHON_ACTIVATE_FILE
            else
                ps1 ${1}
            fi

            _compose_up

        ;;
    esac

}
