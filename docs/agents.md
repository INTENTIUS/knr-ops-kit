# The steward and the review agent

knr-ops moves your control plane off the laptop. Your lifecycle commands still run from one, inside the toolbox container, with a `.env` file beside it. A steward is the same move for those commands. It is a declared machine that operates an environment, and its thread is the record of everything done there.

This page needs a [fountain](https://github.com/BinaryBourbon/fountain) instance. Nothing else in the kit does.

## Two seats, split by who holds credentials

| Seat | Has | Does not have | Output |
|---|---|---|---|
| Steward | Cluster and AWS credentials, the repo, chant | A model, a shell | Runs of your Ops |
| Review agent | A model, the repo, read-only chant tools | Any credential | Pull requests against your YAML |

The split is deliberate. Whatever holds credentials must not be steerable by a prompt. Whatever reads prompts must not be able to reach a cluster.

## The steward

```ts
export const toolchain = new Environment({
  name: "knr-aws-toolchain",
  repositories: [new Repository({ url: "https://github.com/<you>/knr-ops", mount_path: "/workspace/knr-ops", ref: "main" })],
  setup_script: "cd kit && npm ci && npm install -g @intentius/chant && mise install",
  networking_type: "limited",
  networking_config: { allowed_hosts: ["github.com", "registry.npmjs.org", "<your EKS endpoints>", "<AWS API hosts>"] },
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

| What you have today | What it becomes |
|---|---|
| The toolbox image | The `Environment` |
| `.env` with the GitHub token, AWS credentials and the age key path | The `Vault` |
| "Who ran teardown last, and when" | The teammate's thread |
| The convention that two teardowns never run at once | One turn at a time, enforced by fountain |
| A message saying a run has finished | The `Webhook` |

The steward runs `chant acp`, and every prompt it accepts is one chant command line. The text is matched against chant's own command list. It has no variables, no pipes and no shell behind it, so a prompt that is not a chant command is refused before anything runs. That is why the steward can run unattended.

Send it work the same way you run an Op locally.

```sh
npx chant run teardown --env aws --on fountain
npx chant run status teardown --on fountain
```

The thread then reads like shell history for the environment, one command per turn. A gate works as it does locally. The run ends its turn at the gate, you approve, and the next run walks through.

Each environment gets one steward. The composite refuses a second one on the same `Environment` and `Vault`, because two writers on one checkout would interleave.

### What stays on your machine

Bootstrap and the first half of the pivot need a container engine socket, since kind creates its nodes through it. A sandbox has none. Run those from your laptop or from the [nightly workflow](ci.md#the-nightly-lifecycle-run). After the pivot, every operation is an API call, and the steward takes all of it.

## The review agent

```ts
export const { environment, agent } = ConciergeStack({
  name: "knr-triage",
  model: "anthropic/claude-sonnet-4-6",
  allowedHosts: ["github.com"],
});
```

Its sandbox denies all egress except GitHub, and no vault can attach to it. It reads your `AGENTS.md` and the kit's `SKILL.md`. chant's MCP server lets it search the estate and read drift findings.

It cannot mutate a cluster, because nothing in its sandbox can reach one. The first golden rule holds by construction. Its only output is a pull request, and konflate reviews that pull request like any other.

### How the two hand off

1. A steward tick finds drift and writes it to the sticky issue.
2. The webhook on the finished turn prompts the review agent.
3. The agent reads the finding and queries the estate with `chant search`.
4. It opens a pull request against the YAML, or it comments that a person is needed.

The seats share no credential. One more rule keeps approvals honest. An agent cannot approve a gate that its own run reached, so the request and the approval always come from different hands.

## Where fountain runs

| Option | Pick it when |
|---|---|
| Hosted fountain | You want the least setup, and your EKS endpoints are reachable from outside |
| Self-hosted on the management cluster | You run air-gapped, or you want everything in the estate. `kit/cluster/fountain/` is a knr-ops component with a `flux-ks.yaml` that depends on `cert-manager`, built from [fountain-ops](https://github.com/INTENTIUS/fountain-ops) |

## Removing either seat

Delete the declaration and run `npx chant run fountain-apply`. The thread stays in fountain as history. Nothing in your estate referred to either seat.
