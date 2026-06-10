#!/usr/bin/env bash
# Re-apply the Vercel asset fix after a fresh Expo web export.
#
# Why: `expo export -p web` nests fonts + nav-icon assets under
#   assets/__node_modules/.pnpm/<pkg>/node_modules/<...>
# and Vercel excludes BOTH `node_modules` dirs and dot-directories (.pnpm)
# from deployments, so those files 404 and the SPA catch-all returns
# index.html -> "Failed to decode font" / boxed icons.
#
# Fix: flatten every asset under assets/__node_modules into a clean top-level
# /media/<basename> dir, drop the dead tree, and rewrite requests to /media.
# The JS bundle is left untouched (it still requests the old URLs).
#
# Usage (from this repo root, after copying a fresh dist/* in):
#   ./fix-web-export.sh
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d assets/__node_modules ]; then
  echo "No assets/__node_modules found — already flattened or nothing to do."
else
  mkdir -p media
  # Basenames are content-hashed and unique across the tree.
  find assets/__node_modules -type f -exec sh -c 'cp "$1" "media/$(basename "$1")"' _ {} \;
  rm -rf assets/__node_modules
  echo "Flattened $(ls media | wc -l | tr -d ' ') assets into /media/."
fi

cat > vercel.json <<'JSON'
{
  "rewrites": [
    { "source": "/assets/__node_modules/:rest*/:file", "destination": "/media/:file" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
JSON
echo "Wrote vercel.json (font rewrite + SPA catch-all). Ready to commit + push."
