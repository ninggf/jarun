# #######################################################################
# this script aims to run jar file which is built on spring boot 2.3.12+.
# it supports many modes. see config/services.ini for detail.
#
# author: Leo ning <windywany@gmail.com>
# date: 2022-08-06
# version: 1.0.0
#
### do not edit this file unless you known what you are doing.###########
#########################################################################
. /etc/profile
# 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
support_color=$(echo $TERM | grep -nE "^xterm")
function clr_str {
    str=($@)

    if [ -n "$support_color" ]; then
        case $1 in
        'red')
            echo "\033[31m${str[*]:1}\033[0m"
            ;;
        'green')
            echo "\033[32m${str[@]:1}\033[0m"
            ;;
        'yellow')
            echo "\033[33m${str[@]:1}\033[0m"
            ;;
        'blue')
            echo "\033[34m${str[@]:1}\033[0m"
            ;;
        'magenta')
            echo "\033[35m${str[@]:1}\033[0m"
            ;;
        'cyan')
            echo "\033[36m${str[@]:1}\033[0m"
            ;;
        'white')
            echo "\033[37m${str[@]:1}\033[0m"
            ;;
        *)
            echo "${str[*]:1}"
            ;;
        esac
    else
        echo "${str[*]:1}"
    fi
}

function log_debug {
    if [ -n "$XDEBUG" ] && [ "$XDEBUG" = "true" ]; then
        echo -e $(date '+%Y-%m-%d %H:%M:%S ') "[${APP_NAME:-global}]" $(clr_str magenta '[DEBUG]') "$@"
    fi
}

function log_warn {
    echo -e $(date '+%Y-%m-%d %H:%M:%S ') "[${APP_NAME:-global}]" $(clr_str yellow '[WARN ]') "$@"
}

function log_info {
    echo -e $(date '+%Y-%m-%d %H:%M:%S ') "[${APP_NAME:-global}]" $(clr_str cyan '[INFO ]') "$@"
}

function log_error {
    echo -e $(date '+%Y-%m-%d %H:%M:%S ') "[${APP_NAME:-global}]" $(clr_str red '[ERROR]') "$@"
}

function log_msg_n {
    echo -n -e "$@"
}

function str_trim_quote {
    local value=$1

    value="${value##\'}"
    value="${value##\"}"
    value="${value%%\'}"
    value="${value%%\"}"

    echo "$value"
}

function in_array {
    local haystack="${1}[@]"
    local needle=${2}

    for i in ${!haystack}; do
        if [[ ${i} == "${needle}" ]]; then
            return 0
        fi
    done
    return 1
}

function process_app_id {
    local section=$1

    section="${section##*( )}"                                        # Remove leading spaces
    section="${section%%*( )}"                                        # Remove trailing spaces
    section=$(echo -e "${section}" | tr -s '[:punct:] [:blank:]' '_') # Replace all :punct: and :blank: with underscore and squish
    section=$(echo -e "${section}" | sed 's/[^a-zA-Z0-9_]//g')        # Remove non-alphanumberics (except underscore)

    if [[ "${local_case_sensitive_sections}" = false ]]; then
        section=$(echo -e "${section}" | tr '[:upper:]' '[:lower:]') # Lowercase the section name
    fi
    echo "${section}"
}

# detect java installation
function detect_java_installation {
    if [ -n "$JAVA_HOME" ] && [ ! -x "$JAVA_HOME/bin/java" ]; then
        log_error "Unable to find Java in " $JAVA_HOME
        exit 1
    fi
    local windows="0"
    if [ "$(uname)" == "Darwin" ]; then
        windows="0"
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        windows="0"
    elif [ "$(expr substr $(uname -s) 1 5)" == "MINGW" ]; then
        windows="1"
    fi
    # for Windows
    if [ "$windows" == "1" ] && [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
        local tmp_java_home=$(cygpath -sw "$JAVA_HOME")
        export JAVA_HOME=$(cygpath -u $tmp_java_home)
        log_info "Windows new JAVA_HOME is:" $(clr_str blue "$JAVA_HOME")
    fi

    # Find Java
    local javaexe
    if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
        javaexe="$JAVA_HOME/bin/java"
    elif type -p java >/dev/null 2>&1; then
        javaexe=$(type -p java)
    elif [[ -x "/usr/bin/java" ]]; then
        javaexe="/usr/bin/java"
    else
        log_error "Unable to find Java"
        exit 1
    fi

    if [[ "$javaexe" ]]; then
        local version=$("$javaexe" -version 2>&1 | awk -F '"' '/version/ {print $2}')
        export JAVA_VERSION=$(echo "$version" | awk -F. '{printf("%03d%03d",$1,$2);}')
    fi

    export JAVA_EXE=$javaexe
}

##########################################################
# 准备运行时环境
##########################################################
function prepare_args {
    export SERVICE_NAME=$APP_NAME
    # Detect service name
    unset JVM_GC_OPTS JAVA_OPTS JVM_OOM_OPTS LOGBACK_CONFIG PROMETHEUS_AGENT SKYWALKING_AGENT

    if [[ -z $SERVICE_NAME ]]; then
        log_error "$SERVICE_NAME is undefined"
        exit 1
    fi

    if [ -n "$APP_LIBS" ] && [ ! -d "$APP_PATH/$APP_LIBS" ]; then
        log_error "libs dir: $APP_PATH/$APP_LIBS does not exist!"
        exit 1
    fi

    if [ -n "$APP_LIBS" ]; then
        APP_LIBS="-Dloader.path=$APP_PATH/$APP_LIBS"
    fi

    ## Docker profile
    if [[ "$RUN_MODE" = "docker" ]]; then
        if [[ -n "$ACTIVE_PROFILES" ]]; then
            if [[ ! "$ACTIVE_PROFILES" =~ docker ]]; then
                export ACTIVE_PROFILES="${ACTIVE_PROFILES},docker"
            fi
        else
            export ACTIVE_PROFILES="docker"
        fi
    fi

    RUN_JAR_FILE=$APP_PATH/$SERVICE_NAME".jar"

    export SERVER_PORT=${APP_PORT:-8080}
    local service_hash=$(echo -n "${RUN_JAR_FILE}:${SERVER_PORT}" | md5sum)
    SERVICE_HASH="J${service_hash:0:32}J"
    PROMETHEUS_AGENT_PORT="5${SERVER_PORT}"

    ## Create log directory if not existed because JDK 8+ won't do that
    if [[ ! -d $LOG_DIR ]]; then
        mkdir -p $LOG_DIR
    fi

    if [ -f "$JARUN_BASE_DIR/config/common.sh" ]; then
        source "$JARUN_BASE_DIR/config/common.sh"
    fi

    # all sh files in common dir.
    if [ -d "${JARUN_BASE_DIR}/common/" ]; then
        for envf in $(ls "${JARUN_BASE_DIR}/common/"); do
            if [ "${envf%.sh}" != "${envf}" ]; then
                source "${JARUN_BASE_DIR}/common/${envf}"
            fi
        done
    fi

    if [ -f "${APP_PATH}/config/env.sh" ]; then
        source ${APP_PATH}/config/env.sh
    fi

    if [ -n "${JAVA_HOME}" ]; then
        log_debug "use new java home:" $JAVA_HOME
        if ! detect_java_installation; then
            exit 1
        fi
    fi

    # logback config
    # -Dlogging.config=./config/logback-spring.xml
    LOGBACK_CONFIG="${LOGBACK_CONFIG:-}"

    # prometheus agent, 如果一台服务器上有多个java程序要监控，需要修改端口号
    # -javaagent:prometheus_javaagent.jar=18080:config.yaml
    PROMETHEUS_AGENT="${PROMETHEUS_AGENT:-}"

    # SKYWALKING AGENT
    # -javaagent:skywalking-agent.jar
    # -Dskywalking.agent.service_name=service_name
    SKYWALKING_AGENT="${SKYWALKING_AGENT:-}"

    export JAVA_OPTS="$JAVA_OPTS -XX:+DisableExplicitGC -Dclient.encoding.override=UTF-8 -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
    export JAVA_OPTS="$JAVA_OPTS -Djarun.hash=$SERVICE_HASH $JVM_GC_OPTS $JVM_OOM_OPTS $PROMETHEUS_AGENT $SKYWALKING_AGENT"
    export JAVA_OPTS="$JAVA_OPTS $APP_LIBS $LOGBACK_CONFIG -Dspring.profiles.active=$ACTIVE_PROFILES -Dserver.port=$SERVER_PORT"
    if [ -d "${APP_PATH}/conf/" ]; then
        export JAVA_OPTS="$JAVA_OPTS -Dspring.config.location=classpath:/,file:${APP_PATH}/config/,file:${APP_PATH}/conf/"
    else
        export JAVA_OPTS="$JAVA_OPTS -Dspring.config.location=classpath:/,file:${APP_PATH}/config/"
    fi
    export SERVER_URL="http://localhost:$SERVER_PORT"

    return 0
}

# 打印当前运行环境
function print_envs() {
    log_debug "==============================================================="
    log_debug "MODE     :" $(clr_str magenta "${RUN_MODE}_${APP_LAUNCHER}")
    log_debug "ENV      :" $(clr_str magenta $ENV)
    log_debug "APP ID   :" $(clr_str blue $APP_ID)
    log_debug "APP NAME :" $(clr_str blue $APP_NAME)
    log_debug "APP PORT :" $(clr_str blue $APP_PORT)
    log_debug "APP PATH :" $(clr_str blue $APP_PATH)
    log_debug "APP JAR  :" $(clr_str blue $APP_JAR)
    log_debug "APP LIBS :" $(clr_str blue $APP_LIBS)
    log_debug "APP LOG  :" $(clr_str blue $LOG_DIR)
    log_debug "APP ARGS :" $(clr_str blue $APP_ARGS)
    log_debug "PROFILES :" $(clr_str blue $ACTIVE_PROFILES)
    log_debug "JAVA_OPTS:" $(clr_str yellow $JAVA_OPTS)
}
