# knr-ops-kit

**Checks, queries and recorded lifecycle runs for a knr-ops estate. Drop it any time and your knr-ops still works.**

[knr-ops](https://github.com/polarsquad/knr-ops) manages cloud infrastructure through the Kubernetes API. Git is the source, Flux reconciles it, and nothing keeps a state file. knr-ops-kit is an optional [chant](https://github.com/INTENTIUS/chant) project that sits in a `kit/` directory of your fork and reads the YAML you already have.

```sh
cd your-knr-ops-fork
npx degit INTENTIUS/knr-ops-kit/kit kit
cd kit && npm install
just check
```

Flux never reads anything the kit writes, and the kit never applies anything to your clusters. `knr-bootstrap` and `bootstrap.toml` stay exactly as they are.

## What you get

| You want to | Use | Page |
|---|---|---|
| Catch a broken reference between two overlays before merge | `just check` | [Check the whole estate](checks.md) |
| Find every cluster without a pod identity association | `chant search` | [Ask the estate a question](search.md) |
| See which live objects match Git, and trace one back to its file | `chant kube` | [Read a live cluster](clusters.md) |
| Run bootstrap, pivot or teardown with a history and an approval step | `chant run` | [Bootstrap, pivot and teardown](lifecycle.md) |
| Hear about drift that Flux has not reverted | `chant operator` | [Watch for drift](watch.md) |
| Write a new workload cluster as one typed call | `chant build` | [Typed authoring](typed.md) |

The first five rows need one change to your YAML, which is an ownership label on each kustomize root. The last row is opt-in per directory, and you can reverse it whenever you like.

## Give this to your agent

```
This repo is a knr-ops fork with knr-ops-kit in kit/. The kit is a chant project
that reads the kustomize roots under ../mgmt and ../workload. It never applies
anything to a cluster, and Flux never reads its output.

From kit/:
  just check                          lint and audit every overlay as one estate
  npx chant search "<query>"          query the estate graph; add --explain for near misses
  npx chant kube get <kind> --env aws read a cluster, pinned to that environment's context
  npx chant run <op> --env <env>      bootstrap | pivot | teardown | aws-watch

Follow the knr-ops golden rules: edit YAML in Git, never mutate a cluster, and
run `mise run validate` before pushing. A chant gate stops a run with exit code 3.
That is a pending approval and you must leave it for a person.

Read https://intentius.github.io/knr-ops-kit-site/leaving/ before assuming the kit is required for anything.
```

## Start here

[**Add it to your fork**](getting-started.md) takes about ten minutes and ends with a clean `just check`.

After that, take the pages in whatever order your questions arrive. [Why it works this way](design.md) explains the one rule behind every decision. [Dropping the kit](leaving.md) lists what to delete, which is short. [What the kit is built on](underneath.md) names the chant packages involved.

## Status

The kit tracks knr-ops `main` and pins the commit it was last tested against in `kit/UPSTREAM`. The nightly workflow runs the whole `local-host` lifecycle and publishes the run record.
