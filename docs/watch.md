# Watch for drift

Flux watches the objects it applies. ACK and CAPA then create AWS resources from those objects, and Flux cannot see those. The kit reads both sides on a schedule and tells you when they disagree with Git.

It only tells you. Flux is the remediator in a knr-ops estate, so every rule below reports and none of them changes anything.

## Two Ops

`aws-watch` takes a snapshot and compares it with what Git declares. `aws-converge` turns that comparison into findings, using a small table of rules in `ops/converge.op.ts`.

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
      why: "A failed delete in ACK or CAPA can leave a resource behind. Naming it now beats finding it at teardown.",
    }),
    when(eq("status", "unknown"), report("an environment could not be fully observed"), {
      id: "unknown-report",
      why: "A partial read is reported and never acted on.",
    }),
  ],
});
```

Every rule has to say why it exists, and the build fails on a rule without a `why`. `dial: "observe"` means a rule can only report. The build refuses a table that tries to do more at that setting.

Run one tick by hand to see what it finds.

```sh
cd kit
npx chant run aws-converge --env aws
```

```
converge(aws): drifted=1 remediated=0 reported=1 skipped-budget=0 skipped-flap=0 gated=0 unobserved=0 adopted=0
  drift-report   K8s::Infrastructure::AWSManagedMachinePool eu-north-1-workload-gpu
                 spec.scaling.maxSize declared 2, live 6
```

## Why surviving drift matters here

In most estates drift only means that someone changed something. In yours, Flux should already have put it back. Drift that is still there on the next tick points at one of three causes. A `Kustomization` is suspended, or it has stalled, or a controller is writing to a field that Git also sets. The finding names the field manager, which tells you which of those it is.

## AWS resources nothing declares

```sh
npx chant search "kind:AWS" --live --env aws --ambient
```

`--ambient` lists resources of a managed kind that exist without a declaration or a reference behind them. The `orphan-report` rule runs the same read on every tick. ACK and CAPA stamp the kit's ownership tag onto what they create, because the kit's CRs set it under `spec.tags` and `additionalTags`.

## Choosing what runs the schedule

The schedule is data on the Op. Pick one reader.

| Reader | Where it runs | Pick it when |
|---|---|---|
| `chant operator` as a CronJob | On the management cluster | You want no inbound credentials, or your EKS endpoint is private. This is the default |
| A generated GitHub workflow | On a runner, with OIDC into AWS | You would rather keep scheduled work in CI. See [CI pipelines](ci.md#scheduled-watch-and-converge) |
| A steward | On a hosted sandbox | You also want a readable thread of every run. See [The steward and the review agent](agents.md) |

### The CronJob

`kit/cluster/operator/` holds a kustomize root with a `flux-ks.yaml`, in the same layout as every other knr-ops component. Register it in `mgmt/aws/infrastructure/kustomization.yaml` and Flux installs it.

The job runs `chant operator --once` every five minutes. Two replicas can never tick the same Op, because a lease on a Git ref arbitrates between them. All of its state is on the `chant/lifecycle` branch, so a crashed job loses nothing and the next run carries on.

```sh
npx chant operator status
```

```
aws-converge   last tick 2026-09-20T09:45:03Z   drifted=1 reported=1
aws-watch      last tick 2026-09-20T09:45:01Z   ok
```

## Where findings go

Each Op has a finding mode. The default is `issue`, which keeps one sticky issue per Op in your fork and edits it in place. The kit never closes that issue. You close it once the finding is fixed, and that tells the next tick to open a fresh one.

Removing the CronJob stops the reports and affects nothing else.
