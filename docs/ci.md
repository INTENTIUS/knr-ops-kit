# CI pipelines

knr-ops ships five workflows, and the kit leaves all five alone. Each pipeline below is a separate file that you can add or delete on its own.

| Yours already | Keeps doing |
|---|---|
| `validate` | Builds every overlay, runs the Renovate tests and yamllint |
| `konflate` | Shows the rendered Flux diff on each pull request, as a merge gate |
| `bootstrap-rs` | Tests and builds `knr-bootstrap` and the toolbox image |
| `toolbox-release` | Publishes, signs and attests the toolbox image |
| `air-gapped` | Builds the Zarf bundle nightly and deploys it with egress blocked |

Every kit pipeline is an Op with a trigger. `just pipelines` generates the workflow files from those Ops, so you never edit the YAML by hand.

```sh
cd kit
just pipelines          # writes ../.github/workflows/kit-*.yml
just pipelines-check    # fails if the committed files are stale
```

## Estate checks on the pull request

| | |
|---|---|
| Trigger | `pull_request` |
| Runs | `just check` |
| Posts | One sticky comment, edited in place on every push |
| Permissions | `contents: read`, `pull-requests: write` |
| Cluster access | None |

konflate tells the reviewer what will change. This comment tells them what is inconsistent, such as a `dependsOn` that names nothing. Make it a required check if you like, but keep `validate` and `konflate` required as well.

## Did the merge converge

| | |
|---|---|
| Trigger | `push` to `main` |
| Runs | `chant lifecycle affected` between the two commits, then a wait on the matching Kustomizations |
| Posts | A sticky comment on the pull request the commit came from |
| Cluster access | Read-only |

The knr-ops `AGENTS.md` asks agents to wait for a merge before calling a fix live. This job supplies the missing half of that sentence, which is when the fix went live.

```
Merged a41c9e2 -> eu-west-1 (Kustomization) Ready after 2m14s
                 rds-instances (Kustomization) Ready after 5m02s
```

A `Kustomization` that stalls turns the comment red and names the reason Flux gave.

Run the job on a runner with OIDC access to the cluster, or in the cluster as a CronJob that posts out. The in-cluster form works the way your konflate instance already works, and a private EKS endpoint allows no other.

## Scheduled watch and converge

| | |
|---|---|
| Trigger | `schedule` |
| Runs | `chant run aws-watch` and `chant run aws-converge` |
| Posts | One sticky issue per Op |
| Permissions | `contents: read`, `issues: write`, `id-token: write` |

This is the CI form of [Watch for drift](watch.md). The generated workflow assumes an AWS role through `aws-actions/configure-aws-credentials` and OIDC, so the repo stores no key. Use this pipeline or the CronJob, and never both.

## A gated teardown

| | |
|---|---|
| Trigger | `workflow_dispatch` |
| Runs | `chant run teardown --env aws` |
| Environment | `production`, with required reviewers |

Two gates act at different moments here. The GitHub environment holds the job before any credentials exist, and its reviewers decide whether a teardown may start at all. chant's gate holds the run after it has listed every resource the sweep would delete. The person who approves it is reading that exact list.

The first run ends green with "waiting on approval". Approve with `chant approve teardown approve-aws-sweep`, and dispatch again.

## The nightly lifecycle run

| | |
|---|---|
| Trigger | `schedule`, nightly |
| Runs | `bootstrap`, `pivot`, a Podinfo check and `teardown` for `local-host` |
| Cluster access | None. kind runs on the runner |

This is the complete `local-host` chain, run every night, with the run record published as an artifact. A change that breaks the lifecycle shows up the next morning.

## Workflow reference audit

| | |
|---|---|
| Trigger | `schedule`, daily |
| Runs | `chant run actions-audit` |
| Posts | A report, an issue, or a pull request that bumps a stale pin |

Renovate raises versions. This audit asks a different question about the references you already have. It checks whether each one still points at the commit it pointed at when you pinned it. It also checks whether the upstream has been archived, and whether an advisory now covers it.

## Predicted cost on the pull request

| | |
|---|---|
| Trigger | `pull_request` |
| Runs | `chant run pr-behaviour` |
| Posts | A sticky comment with the cost per hour before and after |

A pull request that adds a GPU node pool gets a number next to it.

```
AWSManagedMachinePool eu-west-1-workload-gpu   max 2 -> 6   +$4.02/h at max   (modeled)
```

Every figure states its engine and whether it is modeled or validated. A kind the engine cannot price shows as a row that says so, and never as zero.

## On GitLab or Forgejo

A fork on another forge generates the same pipelines from the same Ops.

| Forge | What differs |
|---|---|
| GitHub | Nothing |
| GitLab | Scheduled pipelines only. `setup` actions and the `permissions` map have no equivalent there, so the generator refuses them by name |
| Forgejo | No environments, so the gated teardown relies on chant's gate alone, and the generated file says so in its header. Sticky pull request comments are unavailable |

```sh
just pipelines gitlab
just pipelines forgejo
```

## What the kit will never add

The kit adds no apply on push. Flux applies, and a second writer to your clusters would break the first golden rule.
