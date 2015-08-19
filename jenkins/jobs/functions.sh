# Utility functions
# These functions MUST NOT rely on environment variables

function log_info() {
    echo -ne "\e[0;32m"
    cat
    echo -ne "\e[0m"
}


function log_error() {
    echo -ne "\e[0;31m"
    cat
    echo -ne "\e[0m"
}


function remote_bash() {
    local server
    server="$1"

    shift

    # Test connection before running the script
    ssh -q -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$server" bash -s exit 0 < /dev/null

    ssh -q \
        -o Batchmode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$server" bash -s -- "$@"
}

function run_bash_script_on() {
    local server
    local script

    server="$1"
    script="$2"
    shift 2

    cat "$script" | remote_bash "$server" $@
}
