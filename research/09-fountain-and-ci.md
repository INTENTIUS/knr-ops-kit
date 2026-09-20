# Hosted operations, agents and CI pipelines

This file covers three optional parts of the kit. The first is a declared machine that runs lifecycle Ops. The second is a pair of agent seats. The third is a set of CI pipelines that would sit beside the five workflows knr-ops already has.

Everything here passes the drop test in `00-principles.md`. Each piece can be deleted without any effect on reconciliation. The converge loop only reports, so no chant process writes to a knr-ops cluster.

The sources are the fountain lexicon docs under `chant/lexicons/fountain/docs/pages/`, five chant guides, and the knr-ops workflows. The guides are `durable-workflows`, `converging-lifecycle`, `operator`, `agent-integration` and `components/orchestration`.

## What fountain is

[fountain](https://github.com/BinaryBourbon/fountain) runs agents in sandboxes. chant's fountain lexicon generates six typed kinds out of the OpenAPI spec that ships with fountain `v0.16.0`.

| Kind | What it is |
|---|---|
| Environment | A sandbox baseline with packages, repos, a setup script and a network policy. A `limited` policy with no hosts denies all egress |
| Vault | Environment variable overrides chosen when a conversation starts. An agent can restrict which vaults may attach to it |
| Agent | A model, a runtime, skills, MCP servers and a typed reference to an Environment |
| Teammate | An Agent with a standing conversation |
| Schedule | A cron prompt sent to a Teammate. A fire that arrives while the teammate is busy is skipped |
| Webhook | An https URL that fountain calls on lifecycle events |

A conversation is a run and the lexicon has no resource kind for it. `fountainRun` starts one, and so does `chant run --on fountain`. `fountainApply` reconciles the six kinds.

The lexicon ships two composites.

| Composite | What it builds |
|---|---|
| `ConciergeStack` | An Environment and an Agent with closed defaults. Egress is denied, no vault may attach, and both carry the ownership marker. The docs say such a sandbox should hold no cloud credentials, because a prompt injection could read anything inside it |
| `Steward` | One Agent that runs `chant acp` on a persistent sandbox. It is seated as a Teammate, with a Schedule for every Op that has a cadence |

## How a steward works

`chant acp` speaks the Agent Client Protocol over stdio, and every prompt it accepts is one chant command line. The text is split with quote awareness and then matched against chant's own command registry. It supports no variables, pipes or redirection. A prompt that does not parse to a chant verb is refused before anything runs, and the process never starts a shell.

A steward therefore has no model and no skills. The project's Op definitions are its whole competence.

The teammate's thread becomes the environment's operational history. Each turn is a command that someone could have typed.

| What chant needs | The fountain kind that provides it |
|---|---|
| A place to run | An Environment and a Vault on a persistent sandbox |
| A record | The conversation |
| A cadence | A Schedule on the teammate |
| A wait for a person | A gate recorded on chant's ledger, resolved by `chant approve` or a merged pull request |
| A way to tell someone | A Webhook |
| One writer per environment | The thread, which runs one turn at a time |

Two stores hold the facts, and nothing is stored twice. fountain's database holds each run as a conversation. chant's ledger branch in Git holds each gate resolution.

The composite refuses three configurations when it is constructed.

- Two stewards on one environment and vault
- An Op whose schedule overlap is anything other than `skip`
- A webhook URL that the lint rule would reject

## The unattended machinery

### ConvergeOp

A `ConvergeOp` holds a typed table of rules. Each rule joins a symptom to an action and must state a reason.

| Property | Behaviour |
|---|---|
| Rule form | `when(predicate, action, { id, why })`. A rule with no `why` fails the build |
| Predicates | Data such as `eq("status", "drifted")`. Closures are excluded, because the table has to survive into the build output |
| Actions | `run(opName)` starts a declared Op, and `report(reason)` writes a log line and a ledger record |
| Dial | `observe` is the default. At that setting a rule that would change something reports it, and a destructive rule is refused |
| Budget | A cap on dispatches per tick |
| Overlap | A tick that would overlap a running one is dropped |
| Damping | A rule that fires three ticks in a row without clearing stops dispatching |
| Unknown state | A tick that could not observe everything only reports |

### chant operator

`chant operator` is a timer with a lease around the local executor. The lease is a Git ref updated by compare-and-swap, and it carries a fencing token. All of its state lives in Git. `chant operator --once` runs one round and exits, which suits cron and a Kubernetes CronJob. After a crash, the next tick re-observes everything, and no separate recovery step is needed.

### Three readers of one schedule

An Op's `schedule` is data. A CI generator can turn it into a workflow trigger. `chant operator` can tick it, and a Steward can turn it into a Schedule. The Op declaration stays the same whichever reader a team chooses.

### Agent surfaces

chant offers agents two surfaces beside Ops. Lexicons install skills under `skills/`. `chant serve mcp` exposes tools for building, linting and searching, and for reading or starting Op runs. One rule matters for approvals. A gate that an agent's own `op-run` reached cannot be approved over the same MCP channel, so the request and the approval stay in different hands.

## How this fits knr-ops

knr-ops moves the control plane off the laptop. The management cluster starts as a local kind instance, and after the pivot it manages itself.

The lifecycle commands still run from an operator's machine, inside the toolbox container, with a `.env` file beside it. A steward offers the same move for those commands. It is a declared machine from which an environment is operated.

| knr-ops today | fountain kind |
|---|---|
| The toolbox image with kubectl, flux, clusterctl, helm and the AWS CLI | Environment |
| `.env` with the GitHub token, AWS credentials and the age key path | Vault |
| The record of who ran a teardown and when | The teammate's thread |
| The convention that two teardowns never run at once | One turn at a time, enforced by the server |
| A message that a run has finished | Webhook |
| A scheduled check | Schedule |

Git records every declarative change in knr-ops, and the API server audits every apply. A lifecycle run leaves no record in either place. The steward's thread provides one, and the gate ledger keeps approvals in Git beside the other history.

A gate that a merged pull request resolves fits the second golden rule, under which nothing takes effect until it is merged.

### What stays off the steward

Bootstrap and the first half of the pivot need a container engine socket, because kind creates its nodes through it. A fountain sandbox does not provide one. Those phases stay on a laptop or a CI runner. The knr-ops `air-gapped` workflow already creates kind instances on a GitHub runner.

After the pivot, every operation is an API call to a cluster or to AWS. That part suits a steward. It covers the watch and converge ticks, workload cluster teardown and the AWS sweep.

## Two seats, divided by credentials

### The steward holds credentials and has no model

```ts
export const toolchain = new Environment({
  name: "knr-aws-toolchain",
  repositories: [new Repository({ url: "https://github.com/<fork>/knr-ops", mount_path: "/workspace/knr-ops", ref: "main" })],
  setup_script: "npm ci && npm install -g @intentius/chant && <install aws-cli, clusterctl>",
  networking_type: "limited",
  networking_config: { allowed_hosts: ["github.com", "registry.npmjs.org", "<EKS endpoints>", "<AWS API hosts>"] },
  metadata: { "managed-by": "chant" },
});

export const { agent, teammate, schedules, webhook } = Steward({
  name: "knr-aws-steward",
  environment: toolchain,
  vault: awsCreds,
  ops: [awsWatch, awsConverge, teardown],
  webhook: { url: "https://hooks.example.com/knr", event_types: ["conversation.turn.done", "conversation.turn.failed"] },
});
```

The steward accepts chant command lines and nothing else. It has no shell and no model, so a prompt cannot steer it outside chant's verbs. That is why its permission policy can allow every tool call, and why chant's gates are the place for human decisions.

`aws eks get-token` is on the Kubernetes client's default allowlist, so EKS authentication works once the AWS CLI is installed in the Environment. Each knr environment gets one steward.

### The review agent has a model and holds no credentials

```ts
export const { environment, agent } = ConciergeStack({
  name: "knr-triage",
  model: "anthropic/claude-sonnet-4-6",
  allowedHosts: ["github.com"],
});
```

This agent reads and proposes. Its sandbox holds the repo with the knr-ops `AGENTS.md` and the kit's `SKILL.md`. chant's MCP tools give it search and drift reads. The sandbox holds no cluster or AWS credentials, and the agent's only output is a pull request against the YAML.

That design enforces the first golden rule by construction. The agent cannot mutate a cluster, because nothing in its sandbox can reach one. Its pull request gets the same konflate review as any other.

The two seats share no credential. The steward's watch tick writes a finding as a sticky issue. A webhook on the finished turn prompts the review agent. The agent reads the finding and queries the estate. It then opens a pull request, or it comments that a person is needed.

knr-ops already ships an `AGENTS.md`. `chant audit --agents` can read local agent configuration, and the fountain lexicon can express it as a declared Agent and Environment. That would be a small first step.

## A converge table for a Flux estate

Flux is the remediator in knr-ops, so the converge loop should report and leave changes to Flux. The dial stays at `observe`.

```ts
export const { op: awsConverge } = ConvergeOp({
  name: "aws-converge",
  env: "aws",
  dial: "observe",
  schedule: "*/15 * * * *",
  rules: [
    when(eq("status", "drifted"), report("live differs from Git and Flux has not reverted it"), {
      id: "drift-report",
      why: "Flux reverts drift within its interval. Drift that survives a tick means a Kustomization is suspended or stalled.",
    }),
    when(gt("adoptCount", 0), report("AWS resources exist that nothing declares"), {
      id: "orphan-report",
      why: "A failed delete in ACK or CAPA can leave a resource behind. A scheduled read names it while the clusters are up.",
    }),
    when(eq("status", "unknown"), report("an environment could not be fully observed"), {
      id: "unknown-report",
      why: "A partial read is reported and never acted on.",
    }),
  ],
});
```

The first rule is more informative in a Flux estate than it would be elsewhere. Flux should already have reverted any drift, so drift that survives a tick points at a suspended or stalled `Kustomization`.

A later version could add a symptom for Flux health, such as a `Kustomization` that stays unready past its interval. That would need new work in the Kubernetes lexicon.

## Where fountain would run

| Option | Notes |
|---|---|
| Hosted fountain | The least work. The steward's sandbox needs network access to the EKS endpoints and the AWS APIs. It does not suit an air-gapped fork |
| Self-hosted on the management cluster | `fountain-ops` already builds fountain's manifests for a real cluster with a CNPG Postgres, and the Kubernetes lexicon already types the CNPG kinds. In the knr-ops layout it would be one more component under `mgmt/aws/infrastructure/`. This is the only option for an air-gapped fork |
| No fountain | `chant operator --once` as a CronJob covers the cadence and the lease with Git alone. It gives up the thread, the webhook and the review agent. It depends on no unshipped work, so it is the natural first step |

The study did not check where fountain's sandboxes run when fountain is self-hosted. `fountain-ops` has a `dataPlane` parameter, which suggests that the sandbox plane is separate from the app.

## Upstream work that has not landed

The lexicon's own docs record the items below as absent from the fountain release it targets.

| Item | Status | Effect |
|---|---|---|
| `runtime: "acp"` with `runtime_command` on an Agent | [fountain#1634](https://github.com/BinaryBourbon/fountain/pull/1634) is open | An instance rejects the pair at apply, so a Steward cannot be applied to a stock fountain yet |
| Requests that outlive a turn | [fountain#1635](https://github.com/BinaryBourbon/fountain/issues/1635) is open | `--durable-requests` has no client on fountain. Gates still work as ledger facts |
| Bulk apply for Teammate, Schedule and Webhook | [fountain#1636](https://github.com/BinaryBourbon/fountain/issues/1636) is open | `fountainApply` reconciles them through their own routes today |

Gap 3 in `06-gaps-and-open-questions.md` applies here too, since watch and converge observe owned resources.

The order of work follows from this. `chant operator` as a CronJob comes first. The review agent can follow, since it needs no upstream change. The steward comes after fountain#1634 lands.

## CI pipelines

### The workflows knr-ops has

| Workflow | Trigger | What it does |
|---|---|---|
| `validate` | push and pull request | Builds every overlay with kustomize, runs a Renovate digest-pinning test, and runs yamllint |
| `konflate` | pull request | Renders the Flux diff for the pull request as a merge gate. An in-cluster instance posts the summary |
| `bootstrap-rs` | push and pull request | Runs fmt, clippy, build and test, and builds the toolbox image |
| `toolbox-release` | a pushed `v*` tag | Builds the image for two architectures, signs it with cosign, and attaches an SBOM |
| `air-gapped` | nightly and manual | Builds the Zarf bundle, then deploys it once with traffic monitored and once with egress blocked |

### Pipelines that would fit beside them

Each pipeline below is additive. They are listed by how much they add to the five workflows above.

#### 1. A convergence report after merge

konflate shows what a pull request will change. This job reports whether the change arrived. The knr-ops `AGENTS.md` asks agents to wait for a merge before calling a fix live, and this job supplies the confirmation.

The trigger is a push to `main`. `chant lifecycle affected` compares the two refs and names the stacks that moved. The `flux-reconcile` wait then watches the matching Kustomizations until they are Ready or stalled. chant's GitHub generator can find the pull request behind a push commit and post a sticky comment there. It already does that for gate notices.

The job needs read access to the cluster. It can run on a runner with that access, or it can run in the cluster and post out, as the konflate instance does.

#### 2. Scheduled watch and converge

`generateOpsPipeline` writes one workflow per scheduled Op. Each workflow runs `chant run <name>` with only the permissions its finding mode needs. The `issue` mode keeps one sticky issue per Op and edits it in place. The `setup` option can add `aws-actions/configure-aws-credentials`, and `permissions` can add `id-token: write`, so a runner can reach EKS through OIDC.

`chant operator --once` as a CronJob is the alternative inside the cluster. That route needs no inbound credentials, and a private EKS endpoint allows no other.

#### 3. Estate checks on the pull request

This job runs `chant build` with lint and audit over the rendered roots. It posts the result as one sticky comment beside konflate's, using `contents: read` and `pull-requests: write`. It covers references between overlays, which a build of each overlay alone cannot see. `07-features.md` lists the checks.

#### 4. A gated teardown

A dispatched workflow would run the AWS teardown Op behind two gates that act at different moments. A GitHub environment with required reviewers holds the job before any credentials exist. chant's own gate holds the run after it has listed what the sweep would delete. That gate binds to the list, so the approver reads the exact plan.

#### 5. A nightly lifecycle run for local-host

This job runs the full `local-host` lifecycle as Ops on a runner, with a Podinfo check before teardown. The `air-gapped` workflow shows that kind works there. knr-ops gates the retirement of its shell scripts on parity runs, and a nightly ledger record would make that evidence continuous. The job would also show the kit's maintainers when an upstream change affects an Op phase.

#### 6. A workflow reference audit

`WorkflowAuditOp` checks facts that change outside the repo. It checks whether a pinned action reference still resolves to the same commit. It also checks whether an upstream repo was archived or gained a security advisory. Its `report` mode needs no services.

Renovate updates versions, and this audit checks that existing references still hold, so the two are complementary. The study did not read what the `renovate-digest-pinning` job covers, so the overlap is unknown.

#### 7. A predicted cost change on the pull request

`BehaviourOp` posts what a change does to predicted cost per hour. A pull request that adds a GPU node pool is a natural case. The feature depends on `behaviourKinds` rows that map CAPA pool kinds to a pricing engine. The Kubernetes lexicon most likely has no such rows today, so this is an idea for later.

### Pipelines to leave out

| Pipeline | Reason |
|---|---|
| An apply on push | Flux applies. A chant apply would be a second writer to the clusters |
| A replacement for `toolbox-release` | knr-ops already builds, signs and attests the image |
| A replacement for `air-gapped` | knr-ops already builds and verifies the bundle. A Zarf lexicon could express it as a component later, if that is wanted |

### Why generate the pipelines

knr-ops lives on GitHub, where a hand-written job serves as well as a generated one. Generation matters for forks. The README invites readers to fork the pattern. A fork that needs an air-gapped install may well run self-hosted GitLab or Forgejo, and the five workflows above are GitHub Actions.

The same Op declarations generate for all three forges, with documented differences.

| Forge | Differences |
|---|---|
| GitHub | Supports every trigger and option |
| GitLab | Supports cron triggers for Ops. It refuses `uses:` steps and the `permissions` map |
| Forgejo | Accepts `setup` steps and drops `permissions`. It has no environments, so the generator writes a header comment that names the one requested. It refuses `comment` mode |

Pipelines 1, 2 and 3 should therefore be written as Ops with triggers, even while GitHub is the only target.

## Order of work

1. Pipelines 3 and 5 come first. They need no cluster credentials in CI. Pipeline 5 depends on the kind lexicon.
2. `chant operator --once` runs as a CronJob on the management cluster with the dial at `observe`. It needs the ownership label on each root.
3. Pipeline 1 follows, running in the cluster and posting out.
4. Pipeline 4 follows once the teardown Op uses typed steps.
5. The review agent comes next. It needs a fountain instance and no upstream change.
6. The steward is the final piece, because it waits on the upstream change.
