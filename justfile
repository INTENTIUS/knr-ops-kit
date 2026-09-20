# Docs tooling. The kit itself is not implemented yet; see ROADMAP.md.

default:
    @just --list

# one-time: a virtualenv with mkdocs-material and the encryption plugin
docs-deps:
    python3 -m venv .venv
    .venv/bin/pip install -q -r requirements-docs.txt

# serve the site locally, unencrypted
docs-serve:
    .venv/bin/mkdocs serve

# the same strict build CI runs; set DOCS_PASSWORD to build the encrypted site
docs-build:
    .venv/bin/mkdocs build --strict

# score every markdown file with the sentences linter; `just lint-docs 3` for strict
lint-docs strictness="2" limit="8":
    npm install --silent
    node scripts/lint-docs.mjs {{strictness}} {{limit}}

check: docs-build lint-docs

# build the encrypted site and push it to INTENTIUS/knr-ops-kit-site with your own git credentials
publish:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${DOCS_PASSWORD:?set DOCS_PASSWORD to the shared site password}"
    out="$(mktemp -d)"
    .venv/bin/mkdocs build --strict -d "$out"
    scripts/publish-site.sh "$out" "https://github.com/INTENTIUS/knr-ops-kit-site.git" "$(git rev-parse --short HEAD)"
    rm -rf "$out" encryptcontent.cache
