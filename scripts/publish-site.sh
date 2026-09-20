#!/usr/bin/env bash
# Pushes an already-built, encrypted site directory to the public site repo.
#   scripts/publish-site.sh <site-dir> <remote-url> <label>
# CI calls it with a token URL. `just publish` calls it with your own git credentials.
set -euo pipefail

site_dir="$1"
remote="$2"
label="$3"

# Refuse to publish a build whose page bodies are readable.
if grep -rl -e "knr-bootstrap" "$site_dir" --include="*.html" --include="*.json" >/dev/null; then
  echo "error: found unencrypted page content in $site_dir; is DOCS_PASSWORD set?" >&2
  exit 1
fi

cd "$site_dir"
rm -rf .git
touch .nojekyll
printf '%s\n' "# knr-ops-kit-site" "" \
  "Built, encrypted output of the knr-ops-kit documentation. Generated; do not edit." \
  > README.md
git init -q -b main
git config user.name "knr-ops-kit docs"
git config user.email "docs@users.noreply.github.com"
git add -A
git commit -q -m "Publish docs from $label"
git push --force --quiet "$remote" main
echo "published $label"
