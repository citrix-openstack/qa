#!/bin/bash

set -eux

SSH_KEY_TO_USE="$1"
BASE_REPO="$2"
BASE_BRANCH="$3"
SOURCE_REPO="$4"
SOURCE_BRANCH="$5"
TARGET_REPO="$6"
TARGET_BRANCH="$7"

RETRIES=5

export SSH_AUTH_SOCK=''
export GIT_SSH=`mktemp`

cat > "$GIT_SSH" << EOF
#!/bin/bash
ssh -a -i $SSH_KEY_TO_USE \$1 \$2
EOF

chmod +x "$GIT_SSH"

(
[ -e ws ] || (
for COUNTER in `seq $RETRIES`;
do
echo "$COUNTER / $RETRIES attempt to clone $BASE_REPO/$BASE_BRANCH"
git clone $BASE_REPO ws && exit 0 || true
sleep 5
done

echo "Failed."
exit 1
)
)

cd ws

git remote rm m_src_repo || true
git remote rm m_tgt_repo || true

git remote add m_src_repo "$SOURCE_REPO" || true
git remote update m_src_repo

git remote add m_tgt_repo "$TARGET_REPO" || true
git remote update m_tgt_repo

git checkout -B build-temp "origin/$BASE_BRANCH"
git merge "m_src_repo/$SOURCE_BRANCH"


for COUNTER in `seq $RETRIES`;
do
echo "$COUNTER / $RETRIES attempt to push $TARGET_REPO/$TARGET_BRANCH"
git push m_tgt_repo "build-temp:$TARGET_BRANCH" -f && exit 0 || true
sleep 5
done

echo "Failed to push changes"
rm -f "$GIT_SSH"
exit 1
