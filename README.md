# epack-ci

A GitHub Action that runs a Locktivity evidence pipeline with [epack](https://github.com/locktivity/epack).

## Use it

Add a workflow like this one to your repository's default branch. The pipeline page in Locktivity shows the file name and the values to use.

```yaml
name: "Evidence Collection - Production"

on:
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - uses: locktivity/epack-ci@v1
        with:
          pipeline-id: 5b1c9e2a-7d4f-4c3e-9a61-2f8e0d4b7c15
          trusted-publishers: locktivity
        env:
          SENTRY_AUTH_TOKEN: ${{ secrets.SENTRY_AUTH_TOKEN }}
```

Then add each secret in the `env` block as a repository secret.

Locktivity accepts sign-ins only from this workflow file on the default branch. Runs must be scheduled or started with Run workflow. The job needs `id-token: write` and a Linux x64 runner, such as `ubuntu-latest`.

## What a run does

1. The action signs in to Locktivity with the workflow's GitHub ID token. If the pipeline is paused, the run stops here and passes.
2. It installs the epack version that the pipeline's current revision uses. It checks the download's SLSA provenance against the epack repository first.
3. It runs `epack run`. epack fetches the current revision and collects evidence. If a secret the revision needs is missing, epack runs the newest earlier revision that doesn't need it.
4. epack signs the pack as this workflow with Sigstore and sends it to Locktivity. The action also uploads the pack as the `evidence-pack` artifact.

## Inputs

| Input | Default | Description |
|---|---|---|
| `pipeline-id` | Required | The Locktivity pipeline ID. |
| `trusted-publishers` | `locktivity` | Comma-separated publishers that epack may install collectors, tools, and remotes from. |
| `api-endpoint` | `https://api.locktivity.com` | The Locktivity API to sign in to. Change it only to test against another Locktivity instance. |

## Organizations that allow only selected actions

If your organization or repository allows only selected actions, add these to the allowed list:

- `locktivity/epack-ci`
- `slsa-framework/slsa-verifier/actions/installer`
- `actions/upload-artifact`, or turn on the setting that allows actions created by GitHub

## Versions

With `@v1`, your workflow gets every 1.x release. A change that needs an edit to your workflow file gets a new major version.

The epack version comes from the pipeline in Locktivity, so updating epack doesn't need a new release of this action.

## Releasing

For maintainers:

1. Connect this repository to a test pipeline in Locktivity whose workflow file is `.github/workflows/epack.yaml`. Set the `SMOKE_PIPELINE_ID` repository variable to that pipeline's ID.
2. Run the Smoke test workflow on `main`. It must pass.
3. In `CHANGELOG.md`, rename the Unreleased section to the version, such as `## 1.2.0`, and commit.
4. Push a tag for that version, such as `v1.2.0`. The Release workflow publishes the release with that section as its notes and moves the `v1` tag to the same commit.

## Security

Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## License

Apache 2.0. See [LICENSE](LICENSE).
