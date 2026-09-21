# knr-ops-kit

**Checks, queries and recorded lifecycle runs for a knr-ops estate. Drop it any time and your knr-ops still works.**

[knr-ops](https://github.com/polarsquad/knr-ops) manages cloud infrastructure through the Kubernetes API. Git is the source, Flux reconciles it, and nothing keeps a state file. knr-ops-kit is an optional [chant](https://github.com/INTENTIUS/chant) project that sits in a `kit/` directory of your fork and reads the YAML you already have.

Flux never reads anything the kit writes, and the kit never applies anything to your clusters. `knr-bootstrap` and `bootstrap.toml` stay exactly as they are.

## Read these first

- [**Why it works this way**](design.md) is the argument. It covers what "no second toolchain" protects and why typed authoring adds no abstraction. It also gives the one rule every feature had to pass.
- [**Dropping the kit**](leaving.md) shows that leaving costs two `git rm` commands, and lists what the kit refuses to do so that stays true.
- [**Adopt it in levels**](adoption.md) lays out the four levels. It says what you change at each, what Flux sees, and what you get.

## Every page

| Section | Page | What it answers |
|---|---|---|
| The idea | [Why it works this way](design.md) | Why the kit sits beside knr-ops and changes nothing about the approach |
| The idea | [Dropping the kit](leaving.md) | What happens when you remove it |
| The idea | [Adopt it in levels](adoption.md) | How far in you have to go for each feature |
| Set up | [Add it to your fork](getting-started.md) | How to install it, and the one label it asks for |
| Use it | [Check the whole estate](checks.md) | How to catch a broken reference between two overlays before merge |
| Use it | [Ask the estate a question](search.md) | How to find every cluster without a pod identity association |
| Use it | [Read a live cluster](clusters.md) | Which live objects match Git, and which file declared one |
| Use it | [Bootstrap, pivot and teardown](lifecycle.md) | How to run the lifecycle with a record and an approval step |
| Use it | [Watch for drift](watch.md) | How to hear about drift that Flux has not reverted |
| Go further | [Typed authoring](typed.md) | How to write a workload cluster as one typed call, and how to go back |
| Go further | [The steward and the review agent](agents.md) | How to move lifecycle commands off your laptop, and how to let an agent propose pull requests safely |
| Go further | [CI pipelines](ci.md) | Which jobs fit beside `validate` and `konflate` |
| Reference | [What the kit is built on](underneath.md) | Which chant packages, kinds and steps are involved |

The same sections run across the top of every page.

## Install

```sh
cd your-knr-ops-fork
npx degit INTENTIUS/knr-ops-kit/kit kit
cd kit && npm install
just check
```

[Add it to your fork](getting-started.md) takes about ten minutes and ends with a clean `just check`.

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

Read https://intentius.io/knr-ops-kit/leaving/ before assuming the kit is required for anything.
```

## Status

The kit tracks knr-ops `main` and pins the commit it was last tested against in `kit/UPSTREAM`. The nightly workflow runs the whole `local-host` lifecycle and publishes the run record.
