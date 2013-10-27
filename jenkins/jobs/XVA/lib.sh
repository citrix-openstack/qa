function novaplugins_name() {
    local name
    name="$1"

    echo "novaplugins-${name}.iso"
}

function xva_name() {
    local name
    name="$1"

    echo "devstack-${name}.xva"
}

function internal_novaplugins_path() {
    local name
    name="$1"

    echo "/usr/share/nginx/www/builds/$(novaplugins_name $name)"
}

function internal_xva_path() {
    local name
    name="$1"

    echo "/usr/share/nginx/www/builds/$(xva_name $name)"
}

function internal_novaplugins_url() {
    local name
    name="$1"

    echo "http://copper.eng.hq.xensource.com/builds/$(novaplugins_name $name)"
}

function internal_xva_url() {
    local name
    name="$1"

    echo "http://copper.eng.hq.xensource.com/builds/$(xva_name $name)"
}

INTERNAL_HTTP_USER_HOST="jenkinsoutput@copper.eng.hq.xensource.com"
