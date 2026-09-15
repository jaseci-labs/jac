# Jac deployment image

`jaseci/jaclang` packages Jac, its serving dependencies, and embedded PostgreSQL
binaries for container deployments. Docker publishing remains a required job in
the normal Jac release workflow.

## Retry Docker without rebuilding Jac

The `Publish Jac Docker image` workflow can also run independently. It downloads
the selected release's Linux binaries and verifies their published SHA-256
checksums before building both image architectures.

After merging a Dockerfile fix, publish an image from existing release assets:

```bash
gh workflow run publish-docker.yml --repo jaseci-labs/jac --ref main -f tag=v0.37.15
```

Use `tag=dev` for the rolling development image. The selected workflow ref
provides the Dockerfile; the tag selects the binaries. Draft releases are
supported once both Linux binaries and their checksums have been uploaded.
By default this publishes Docker images only. Older versions do not replace
`latest` when a newer GitHub release exists.

To finish an otherwise-complete release after Docker was its only failure, set
`publish_release=true` and pass `required_platforms` from the original release's
plan job. After Docker succeeds, the workflow runs the normal release asset
guard and publishes the draft with `GITHUB_TOKEN`, which avoids triggering
another binary build. An empty required-platform list is rejected. The normal
release workflow continues to wait for Docker before publishing.

## Dependency bootstrap

The seed project still uses `jac install` to resolve serving dependencies.
Its virtual environment starts with the runtime's existing precompiled pip.
Running `ensurepip` would compile a second, source-only copy of pip under
emulation and can exceed Jac's environment-creation timeout.
