#!/bin/sh
# Publish the taxonomy in this repo to gs://meimei168-main-sg/product/.
#
#   ./push.sh              # the latest tag
#   ./push.sh v26370000
#
# Pushed like an image: the same files go up under their live names, which is
# what services read, and under the version, which is what that release was.
# The versioned objects are never rewritten, so a release stays what it was.
# Git tags carry that same history and master carries one version.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TAG=${1:-$(git -C "$here" describe --tags --abbrev=0)}
bucket=${BUCKET:-meimei168-main-sg}
prefix=${PREFIX:-product}
url=gs://$bucket/$prefix

command -v gcloud >/dev/null 2>&1 || {
  echo "gcloud not found; install the Cloud SDK and run: gcloud auth login" >&2
  exit 1
}

cd "$here"

if ! git rev-parse --verify --quiet "$TAG:categories.txt" >/dev/null; then
  echo "$TAG does not hold categories.txt; is that a taxonomy tag?" >&2
  exit 1
fi

# what goes up has to be what the tag says, else the bucket and the tag disagree
# with nothing recording which of them is late
if [ -n "$(git status --porcelain -- 'categories*.txt')" ]; then
  echo "categories*.txt differs from what is committed; commit or discard it first" >&2
  exit 1
fi
if ! git diff --quiet "$TAG" -- 'categories*.txt'; then
  echo "HEAD is not at $TAG for the taxonomy; check out $TAG before pushing it" >&2
  exit 1
fi

for f in categories*.txt; do
  headerVersion=$(sed -n '1,5s/^# Version: //p' "$f" | head -1)
  if [ "$headerVersion" != "$TAG" ]; then
    echo "$f says $headerVersion, tag is $TAG" >&2
    exit 1
  fi
done

echo "pushing $TAG to $url"
gcloud storage cp 'categories.txt' 'categories_*.txt' "$url/"

# one at a time because each goes to its own versioned name; --no-clobber is the
# point: a version that is already up is never replaced by a later edit
for f in categories*.txt; do
  gcloud storage cp --no-clobber "$f" "$url/${f%.txt}.$TAG.txt"
done

echo
echo "now in $url:"
gcloud storage ls "$url/categories*.txt"
