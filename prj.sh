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

set -e
# set -x

PROJECTS_DIR="$HOME/venv2"
VALID_LANGUAGE="python3.6 python3.8 go"
# WORK_HOME=~/venv
# ACTIVATE_FILE=bin/activate
# VIRT_ENV=/usr/bin/virtualenv
VIRTUAL_ENV=/home/alex/venv/devops

_workon_complate ()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=( $(compgen -W "$(workon2 -l)" -- $cur) )
}

complete -F _workon_complate workon2

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

    if [ -n $LANGUAGE ] && [[ $LANGUAGE == python* ]]
    then
        ${LANGUAGE} -m venv $PRJ_DIR
        cd $PRJ_DIR
        source $PRJ_DIR/$ACTIVATE_FILE
    else
        mkdir $PRJ_DIR && cd $PRJ_DIR
    fi
    PROJECT_PATH=$PRJ_DIR
    export $PROJECT_PATH
    ps1 $1
}


workon2() {
    ### Manage projects ###
    local OPTIND
    
    case $1 in
        ?)
            printf "Usage: %s: [-a] [-b value] args\n" $(basename $0) >&2
            # exit 2
        ;;    
        -c)
            PRJ_NAME=$2
            shift 2
            getopts 'l:' args
            LANGUAGE=$OPTARG
            echo $args
            if  [ $args == "l" ] && ! validate $LANGUAGE
            then
                echo "Unsupported language '$OPTARG'"
                return
            fi
            _create_prj $PRJ_NAME
            echo "Created project '$PRJ_NAME'..."
        ;;
        # -d)
        #     if [ -d $WORK_HOME/$2 ]
        #     then
        #         if [ "w$VIRTUAL_ENV" == "w$WORK_HOME/$2" ]
        #         then
        #             deactivate
        #         fi
        #         rm -rf $WORK_HOME/$2
        #     fi
        # ;;
#         -h)
#             echo -e "\nUsage: workon [option] <envname>\n\n-h Show help
# -c Create env in $WORK_HOME\n-d Delete env\n-l List available env\n-p Create enter point\n"
#         ;;
        -l)
            # find $PROJECTS_DIR -type d|xargs basename -a
            venvs=""
            for path in $(find $PROJECTS_DIR -type d 2>/dev/null);
            do
                venvs+="$(basename ${path}) "
            done
            echo $venvs
        ;;
        *) 
            if [ -d ${PROJECTS_DIR}/${1}/src ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}/src"
            elif [ -d ${PROJECTS_DIR}/${1} ]
            then
                PROJECT_PATH="${PROJECTS_DIR}/${1}"
            fi
            
            alias workgo="cd $PROJECT_PATH"
            cd ${PROJECT_PATH}
            ps1 ${1}

        #         source $WORK_HOME/$1/$ACTIVATE_FILE
        #         if [ -f $venv_path/docker-compose.yml ] && [ $(docker ps -q |wc -l) -eq 0 ]
        #         then
        #             read -p "Do you want run docker-compose ? " -t 30 yn
        #             if [ $yn == 'y' ] || [ $yn == 'yes' ]
        #             then
        #                 result=$(systemctl is-active docker.service )
        #                 if [ $result == 'inactive' ]
        #                 then
        #                     sudo systemctl start docker.socket && sleep 1
        #                     sudo systemctl start docker.service && sleep 3
        #                 fi
        #                 docker-compose up -d
        #                 sleep 3
        #                 docker-compose ps
        #             fi
        #         fi
        #     else
        #         echo -e "Venv $1 not found"
        #     fi
        ;;
    esac

}


# workon2 -c www