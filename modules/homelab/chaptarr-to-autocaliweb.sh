#!/bin/bash
set -euo pipefail

[[ ${chaptarr_eventtype:-} == Download ]] || exit 0
mapfile -td '|' files < <(printf '%s' "${chaptarr_addedbookpaths:?}")

export LC_ALL=C
library=/mnt/media/media/books/chaptarr
staged=
trap 'rm -f -- "$staged"' EXIT
for source in "${files[@]}"; do
  [[ $source == "$library"/* ]] || continue
  name=${source##*/}
  stem=${name%.*}
  extension=${name##*.}
  case ${extension,,} in
    epub | kepub | mobi | azw3 | pdf) ;;
    *) continue ;;
  esac
  [[ ${#stem} -le 230 ]] || stem=ebook

  staged=$(mktemp -- "$library/.autocaliweb.XXXXXXXXXX")
  cp -- "$source" "$staged"
  # Publish the completed copy with a rename in the same NAS mount.
  mv -T -- "$staged" "/mnt/media/book-ingest/$stem-${staged##*.}.${extension,,}"
  staged=
done
