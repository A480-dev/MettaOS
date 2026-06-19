#!/bin/bash
# ImageMagick helper — IMv6 (convert) vs IMv7 (magick)
im() {
  if command -v magick >/dev/null 2>&1; then
    magick "$@"
  elif command -v convert >/dev/null 2>&1; then
    convert "$@"
  else
    return 127
  fi
}

im_available() {
  command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1
}
