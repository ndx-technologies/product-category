# Product Category

`categories.txt` is the canonical taxonomy and `categories_<lang>.txt` are its
translations, 11 languages, about 3800 categories. Every file carries the release
version in its header.

Master holds one version. A release is a git tag `v<version>` whose tree is that
version, so the history of what clients and jobs key on is a `git log`, and a
change is reviewed as a diff before it is published.

The file format and the release procedure are owned by the `product-category`
toolkit in `mm-product/product/cmd/product-category`.

Services do not read this repo. They read `gs://meimei168-main-sg/product/`:

```
categories.txt                      live canonical taxonomy
categories_<lang>.txt               live translation, what clients fetch
categories.v<version>.txt           that release, never rewritten
categories_<lang>.v<version>.txt    that release of a translation
```

`push.sh` writes the live names and the versioned names in the same run, like an
image tag and its digest. The daily `product-category-psql-sync` job reads
`categories.txt` and writes a version postgres does not have yet.

## Scripts

```sh
./download.sh              # live files of the latest version
./download.sh v26390000    # that release, laid out under the live names
./push.sh                  # publish the latest tag
./push.sh v26390000        # publish that tag
```

`download.sh` mirrors the bucket one way: a file the bucket no longer has is
removed here too, and the copy lands in a temporary directory first so a failed
run leaves the repo untouched. The version form is how a tag is rebuilt from the
bucket, and it refuses a snapshot whose header disagrees with its name. Prints the version and any uncommitted diff. 

`push.sh` refuses to publish a tree that is not the tag: the taxonomy files must
be committed, identical to `v<version>`, and every header must say `v<version>`.
Versioned objects go up with `--no-clobber`, so a published release is never
replaced by a later edit.

Both default to `meimei168-main-sg` and prefix `product`:

```sh
BUCKET=other-bucket PREFIX=prefix ./push.sh
```

## Releasing

1. On master, run the toolkit (`-dir .`): `assign-ids`, the edit, `normalize`,
   `validate`, `stats`, `bump-version`.
2. Commit and `git tag v<version>` — the tag is the `# Version:` header.
3. `./push.sh`.
4. `git push && git push --tags`.

Ids are renumbered by `normalize` and differ between versions: join on category
path, never on id.

This repositroy contains versioned Product Category taxonomy.

## ADR

- 2026-10-31 only data, no sdk. so that tags are releases of taxonomy data and not clients to use it.
- 2026-10-31 master holds one version and releases are tags; the bucket keeps
  the versioned copies a client may pin. The tags were backfilled once from the
  bucket: `v26180001`, `v26190000`, `v26280001`, `v26370000`, `v26390000`,
  `v26390002`. `v26180000`, `v26280000` (canonical only) and `v26300000`
  (translations only) are not tagged, because a version needs its full file set.
