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
. "$JARUN_BASE_DIR/bin/lib/common.sh"
. "$JARUN_BASE_DIR/bin/lib/ini-file-parser.sh"
# current application
current_application=()

function print_help {
    echo
    echo 'Usage: jarun.sh COMMAND [service1] [service2]'
    echo
    echo 'Commands:'
    echo -e $(clr_str green "\tconfig") "\t\tShow the configuration of one or more services"
    echo -e $(clr_str green "\tstart") "\t\tStart one or more services"
    echo -e $(clr_str green "\tstop") "\t\tStop one or more services"
    echo -e $(clr_str green "\trestart") "\tRestart one or more services"
}

function print_brand {
    echo ""
    echo "   __   "
    echo "   \ \   __ _  _ __  _   _  _ __  "
    echo "    \ \ / _\` || '__|| | | || '_ \ "
    echo " /\_/ /| (_| || |   | |_| || | | |"
    echo -e " \___/  \__,_||_|    \__,_||_| |_|" $(clr_str green "$1")
    echo ""
}

#
function load_services_config {
    log_info 'load services configuration from:' $(clr_str blue "${1}")

    if [ ! -f "$1" ]; then
        log_error $(clr_str blue "${1}") $(clr_str red "does not exist!!!")
        exit 1
    fi

    case_sensitive_keys=false
    case_sensitive_sections=false
    if ! process_ini_file "${1}"; then
        exit 1
    fi

    if [ "${#sections[@]}" -le 1 ]; then
        log_error "no service configuration found!"
        exit 1
    else
        local sc=$((${#sections[@]} - 1))
        log_info "${sc} service(s) found: ${org_sections[@]:1}"
    fi

    local log_dir=$(get_value global log_dir "$JARUN_BASE_DIR/logs")
    local _absp=$(echo -n ${log_dir} | grep -nE "^/.+$")
    local _user=$(get_value global user)

    if [ -z "${_absp}" ]; then
        log_dir=$(realpath "$JARUN_BASE_DIR/$log_dir")
    fi

    if [ -n ${_user} ]; then
        _user="${_user}@"
    else
        _user="root@"
    fi

    if [ -z "${ENV}" ]; then
        export ENV=$(get_value global env dev)
    fi

    export RUN_MODE=$(get_value global mode nohup)
    export LOG_DIR=$log_dir
    export APP_USER=${_user}

    log_debug 'Running Mode:' $(clr_str blue $RUN_MODE)
    log_debug 'Running ENV :' $(clr_str yellow $ENV)
    log_debug 'Logger Path :' $(clr_str blue $LOG_DIR)
}

function show_app_config {
    for app in $@; do
        app=$(process_app_id $app)

        if ! in_array sections $app; then
            log_error "$app not found"
            continue
        fi
        get_app_config "$app"
        print_app_config "$app"
    done
}

# current_application=([id] [name] [path] [port] [profiles] [libs] [log_dir] [hosts] [args] [jar] [launcher])
function start_app {
    for app in $@; do
        app=$(process_app_id $app)

        if ! in_array sections $app; then
            log_error "$app not found"
            continue
        fi

        get_app_config "$app"
        if [ ! -d "$JARUN_BASE_DIR/${current_application[2]}" ]; then
            log_warn "$app: $JARUN_BASE_DIR/${current_application[2]} does not exists!!!"
            continue
        fi

        if [ -n "${current_application[7]//\'/}" ]; then
            log_info "${current_application[1]} will run on the hosts:" $(clr_str blue ${current_application[7]})
        else
            log_info "${current_application[1]} will run on the hosts:" $(clr_str blue localhost)
        fi

        bash "$JARUN_BASE_DIR/bin/lib/run_jar.sh" "${current_application[@]}"
    done
}

function stop_app {
    for app in $@; do
        app=$(process_app_id $app)

        if ! in_array sections $app; then
            log_error "$app not found"
            continue
        fi

        get_app_config "$app"
        if [ ! -d "$JARUN_BASE_DIR/${current_application[2]}" ]; then
            log_warn "$app: $JARUN_BASE_DIR/${current_application[2]} does not exists!!!"
            continue
        fi

        if [ -n "${current_application[7]//\'/}" ]; then
            log_info "${current_application[1]} will stop on the hosts:" $(clr_str blue ${current_application[7]})
        else
            log_info "${current_application[1]} will stop on the hosts:" $(clr_str blue localhost)
        fi

        bash "$JARUN_BASE_DIR/bin/lib/stop_jar.sh" "${current_application[@]}"
    done
}

function restart_app {
    for app in $@; do
        app=$(process_app_id $app)

        if ! in_array sections $app; then
            log_error "$app not found"
            continue
        fi

        get_app_config "$app"
        if [ ! -d "$JARUN_BASE_DIR/${current_application[2]}" ]; then
            log_warn "$app: $JARUN_BASE_DIR/${current_application[2]} does not exists!!!"
            continue
        fi

        if [ -n "${current_application[7]//\'/}" ]; then
            log_info "${current_application[1]} will restart on the hosts:" $(clr_str blue ${current_application[7]})
        else
            log_info "${current_application[1]} will restart on the hosts:" $(clr_str blue localhost)
        fi

        bash "$JARUN_BASE_DIR/bin/lib/stop_jar.sh" "${current_application[@]}"

        if [ $? -eq 0 ]; then
            bash "$JARUN_BASE_DIR/bin/lib/run_jar.sh" "${current_application[@]}"
        fi
    done
}

# current_application=([id] [name] [path] [port] [profiles] [libs] [log_dir] [hosts] [args] [jar] [launcher])
function get_app_config {
    local cur_app="$1"
    current_application[0]="${cur_app}" # id
    current_application[1]=$(get_value "$1" name "$1")
    current_application[2]=$(get_value "$1" path "${current_application[1]}")
    current_application[3]=$(get_value "$1" port 8080)
    current_application[4]=$(get_value "$1" profiles "''")
    current_application[5]=$(get_value "$1" libs_dir "''")
    current_application[6]=$(get_value "$1" log_dir "${LOG_DIR}")
    current_application[7]=$(get_value "$1" hosts "''")
    current_application[8]=$(get_value "$1" args "''")
    current_application[9]=$(get_value "$1" jar "${current_application[1]}")
    current_application[10]=$(get_value "$1" launcher "''")
}

function print_app_config() {
    log_info "${current_application[1]}: "
    log_info "\tid       : ${current_application[0]}"
    log_info "\tpath     : ${current_application[2]}"
    log_info "\tjar      : ${current_application[9]}"
    log_info "\tlauncher : ${current_application[10]}"
    log_info "\tport     : ${current_application[3]}"
    log_info "\tprofiles : ${current_application[4]}"
    log_info "\tlibs_dir : ${current_application[5]}"
    log_info "\tlog_dir  : ${current_application[6]}"
    log_info "\thosts    : ${current_application[7]}"
    log_info "\targs     : ${current_application[8]}"
}
