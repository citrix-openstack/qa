set -eux

GITREPO="$1"
git clone "$GITREPO"
cd nova
cd plugins/xenserver/xenapi/contrib/
./build-rpm.sh
