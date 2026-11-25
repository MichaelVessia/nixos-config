#!/bin/bash
set -euo pipefail

[[ ${chaptarr_eventtype:-} == Download ]] || exit 0
mapfile -td '|' files < <(printf '%s' "${chaptarr_addedbookpaths:?}")

staged=
trap 'rm -f -- "$staged"' EXIT
for source in "${files[@]}"; do
  [[ $source == /mnt/media/media/books/chaptarr/* ]] || continue
  case ${source,,} in
    *.epub | *.kepub | *.mobi | *.azw3 | *.pdf) ;;
    *) continue ;;
  esac

  staged=$(mktemp -- "${source%/*}/.autocaliweb.XXXXXXXX")
  cp -- "$source" "$staged"
  # Publish the completed copy with a rename in the same NAS mount.
  mv -T -- "$staged" "/mnt/media/book-ingest/${source##*/}"
  staged=
done
