# Dropping the kit

**If you drop the kit, your knr-ops still works fine.** Every design decision in the kit is judged against that sentence. Here is what dropping it takes.

```sh
git rm -r kit
git rm .github/workflows/kit-*.yml
git commit -m "Remove knr-ops-kit"
```

Your estate reconciles through that commit exactly as it did before it, and nothing needs migrating first.

## Why that is all

| Area | What is true |
|---|---|
| Reconciling | Flux reads committed YAML from the paths it always read. It never read anything from `kit/` |
| In the cluster | The kit installed no CRDs, controllers or webhooks |
| State | The kit holds no state file. Nothing in a cluster depends on anything the kit recorded |
| Bootstrap | `knr-bootstrap` and `bootstrap.toml` were never changed, and `mise run bootstrap` works as before |
| Typed directories | The built YAML is already committed where Flux reads it, so you go back to editing it by hand |
| CI | `validate` and `konflate` were never touched |

## Optional leftovers

None of these affects anything. Remove the ones you used, for tidiness.

| Leftover | Remove it with |
|---|---|
| The ownership label on each kustomize root | Delete the `labels:` block. No controller selects on it, and Flux removes it from the objects on its next reconcile |
| The `chant/lifecycle` branch | `git push origin --delete chant/lifecycle`. It holds run history and approvals |
| The operator CronJob | Delete `mgmt/aws/infrastructure/chant-operator/` and its line in the parent `kustomization.yaml`. Flux prunes it |
| A steward or review agent | Delete the declarations and run `npx chant run fountain-apply` before you remove `kit/` |
| Self-hosted fountain | Delete its component directory. Flux prunes it |

## Checking for yourself

The kit's test suite proves this on every commit. It bootstraps `local-host` with the kit present and records the rendered output of every root. It then deletes `kit/` and renders again, and the two renders have to be identical.

You can run the same check on your fork.

```sh
cd kit && just drop-test
```

## What the kit refuses to do

Each refusal below exists to keep this page true.

| The kit never | Because |
|---|---|
| Points a Flux `Kustomization` at a path that only a build fills | Flux would then depend on the kit |
| Applies to a cluster | Flux is the only writer |
| Runs a scheduled rule that changes the estate | A report can be ignored, and a change cannot |
| Moves a value out of `bootstrap.toml` | `knr-bootstrap` reads it there |
| Makes one of its jobs the only merge gate | Removing the job would remove the gate |
| Keeps a value the estate needs where only the kit can read it | The estate has to reconcile without the kit |
