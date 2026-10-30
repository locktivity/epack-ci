# Changelog

## 1.0.0

Initial version of the action.

- Signs in to Locktivity as the calling workflow. A run for a paused pipeline stops at sign-in and passes.
- Installs the epack version that the pipeline's current revision uses, after checking its SLSA provenance.
- Runs the current revision with `epack run` and uploads the pack as the `evidence-pack` artifact.
