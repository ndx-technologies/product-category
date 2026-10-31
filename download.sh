#!/bin/sh
# Download the taxonomy from GCS into this repo.
#
#   ./download.sh              # the live files of the latest version
#   ./download.sh v26300000    # that release, laid out under the live names
#
# The repo mirrors the bucket, so this is a one way sync: a file the bucket no
# longer has is removed here too. Keeping a local change is git's job. The copy
# lands in a temporary directory first, so a failed download never leaves a half
# replaced taxonomy behind.
#
# Master holds one version and never the snapshots: the versioned objects in the
# bucket are the released history and the git tags hold it. So the plain form
# fetches only the live files, while the version form takes one snapshot set and
# lays it out under the live names, which is how an old release is rebuilt on its
# way to a tag.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tag=${1:-}
bucket=${BUCKET:-meimei168-main-sg}
prefix=${PREFIX:-product}
url=gs://$bucket/$prefix

command -v gcloud >/dev/null 2>&1 || {
  echo "gcloud not found; install the Cloud SDK and run: gcloud auth login" >&2
  exit 1
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/product-category.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

if [ -z "$tag" ]; then
  echo "downloading live files from $url"
  # a wildcard matches the dots in a version, so 'categories_*.txt' would also
  # pull every snapshot: list, then keep only the names without '.v<version>'
  objects=$(gcloud storage ls "$url/categories*.txt" | grep -v '\.v[0-9.]*\.txt$')
  if [ -z "$objects" ]; then
    echo "$url holds no live taxonomy; repo left untouched" >&2
    exit 1
  fi
  gcloud storage cp $objects "$tmp/"
else
  echo "downloading $tag from $url"
  gcloud storage cp "$url/categories*.${tag}.txt" "$tmp/"

  for f in "$tmp"/*."$tag".txt; do
    name=${f##*/}
    mv "$f" "$tmp/${name%.$tag.txt}.txt"
  done

  # a snapshot named for a version that holds another is a wrong tag, and it is
  # cheaper to say so here than to find out after it is tagged
  version=$(sed -n '1,5s/^# Version: //p' "$tmp/categories.txt" | head -1)
  if [ "$version" != "$tag" ]; then
    echo "$url holds $version under the name $tag; check the tag" >&2
    exit 1
  fi
fi

# the canonical file is what every service and the psql sync job read; a
# download without it is not a taxonomy
if [ ! -f "$tmp/categories.txt" ]; then
  echo "$url holds no categories.txt; repo left untouched" >&2
  exit 1
fi

for f in "$here"/categories*.txt; do
  [ -f "$f" ] || continue
  name=${f##*/}
  if [ ! -f "$tmp/$name" ]; then
    rm -f "$f"
    echo "removed $name (absent from $url)"
  fi
done

cp -f "$tmp"/*.txt "$here"/

version=$(sed -n '1,5s/^# Version: //p' "$here/categories.txt" | head -1)
set -- "$here"/categories*.txt
echo "version: $version"
echo "files:   $#"

if [ -d "$here/.git" ]; then
  changed=$(git -C "$here" status --porcelain -- 'categories*.txt')
  if [ -n "$changed" ]; then
    echo
    echo "uncommitted changes:"
    printf '%s\n' "$changed"
    echo "review and commit them, so git stays the source of the taxonomy"
  fi
fi
