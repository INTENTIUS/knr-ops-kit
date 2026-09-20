# knr-ops-kit

**Checks, queries and recorded lifecycle runs for a knr-ops estate. Drop it any time and your knr-ops still works.**

[knr-ops](https://github.com/polarsquad/knr-ops) manages cloud infrastructure through the Kubernetes API. Git is the source, Flux reconciles it, and nothing keeps a state file. knr-ops-kit is an optional [chant](https://github.com/INTENTIUS/chant) project that sits in a `kit/` directory of your fork and reads the YAML you already have.

Flux never reads anything the kit writes, and the kit never applies anything to your clusters. `knr-bootstrap` and `bootstrap.toml` stay exactly as they are.

[The documentation site](https://intentius.github.io/knr-ops-kit-site/) is published on GitHub Pages and asks for a password.

## Read this first

**This repo is documentation ahead of code.** The site under `docs/` is written as finished documentation, so that the design can be read the way a user would meet it. The `kit/` directory it describes does not exist yet.

[`ROADMAP.md`](ROADMAP.md) is the other half. It lists every claim in the docs that is not true today, what has to be built to make it true, and every decision the docs made that belongs to the knr-ops author. When that file is empty, the docs are accurate.

## What is here

| Path | Contents |
|---|---|
| `docs/` | The published site, written for someone who runs knr-ops |
| `ROADMAP.md` | Roadmap items and open questions, each tied to the docs page it affects |
| `research/` | The study behind the design, with the evidence for each claim |
| `mkdocs.yml`, `.github/workflows/docs.yml` | The site build, and the push of the encrypted output to the public site repo |
| `NOTICE` | Credit to knr-ops |

## Working on the docs

```sh
just docs-deps     # one-time: a virtualenv with mkdocs-material
just docs-serve    # http://127.0.0.1:8000, unencrypted
just check         # the strict build CI runs, plus the prose linter
```

`just lint-docs` scores every markdown file with [`sentences`](https://www.npmjs.com/package/sentences). A file that scores above 8 at the default strictness fails.

## The password

This repository is private, and the organisation's plan serves GitHub Pages from public repositories only. The workflow therefore builds the site here and pushes the built output to a second, public repository named `knr-ops-kit-site`, which Pages serves. The markdown source stays private.

The built pages are encrypted with one shared password, using [mkdocs-encryptcontent-plugin](https://github.com/unverbuggt/mkdocs-encryptcontent-plugin). Two repository secrets drive this. `DOCS_PASSWORD` is the password. `SITE_PUSH_TOKEN` is a fine-grained personal access token with `contents: write` on `knr-ops-kit-site` and no other access. The organisation disables deploy keys, which is why a token is used. Without the token the workflow still builds and verifies the site, and `just publish` pushes it from your machine with your own credentials.

```sh
gh secret set DOCS_PASSWORD
gh secret set SITE_PUSH_TOKEN
```

The workflow refuses to publish without that secret, so the site cannot go out in the clear by accident. Locally the variable is unset, and the site builds unencrypted.

The plugin warns when a password has less than 100 bits of entropy, and `--strict` turns that warning into a failed build. `mkdocs.yml` lowers the bar to 40 bits with `threshold_warning_min_entropy`, because the shared password is short on purpose. Raise it again if you switch to a long passphrase.

Know what this protects. Each page body and the search index are encrypted at build time and decrypted in the reader's browser. The ciphertext is public, and so are the page titles in the navigation and the one-line site description. A short password only keeps out casual readers, since anyone with the ciphertext can try guesses offline. A long passphrase is safe enough for sharing a draft with a few people. Neither is access control. If this repository ever becomes public, the markdown under `docs/` is readable no matter what the site does. At that point drop the plugin, publish Pages from this repository directly as m80 does, and delete `knr-ops-kit-site`.

## License

This project is licensed under Apache 2.0, and [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) hold the terms. knr-ops is the work of its own contributors under the same license, and this project is independent of it.
