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
