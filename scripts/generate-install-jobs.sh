#!/bin/bash

set -x
set -e
set -u

JENKINS_URL="http://bronze.eng.hq.xensource.com:8080"
TEMPLATE_SERVER="cottington"
SERVERS="zarss epun stepney ysdllodins megadodo broop ciceronicus"

[ -e jenkins-cli.jar ] || wget "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

function cli
{
    java -jar jenkins-cli.jar  -s "$JENKINS_URL" "$@"
}

function jobname
{
    echo "install-$1"
}

function check_template
{
[ "1" == `grep "$TEMPLATE_SERVER" $TEMPLATE | wc -l` ] || (
    echo "Multiple lines found"
    exit 1
)
}

TEMPLATE=`tempfile`

cli get-job `jobname $TEMPLATE_SERVER` > "$TEMPLATE"
check_template

for SERVER in $SERVERS;
do
    JOBNAME=`jobname $SERVER`
    cli delete-job "$JOBNAME" || true
    cat $TEMPLATE | sed -e "s/$TEMPLATE_SERVER/$SERVER/g" | cli create-job "$JOBNAME"
done

rm -f $TEMPLATE
