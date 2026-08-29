# Release repository rules

- This public repository contains signed Danetti release manifests and repair tooling only. Keep application source, credentials, private signing keys, customer data, database exports, and local environment files out of it.
- Treat GitHub `main` as the synchronization authority. Fetch before comparing; update a clean workspace by fast-forward only. Never reset, clean, force-push, or overwrite an active/dirty workspace.
- Do not hand-edit a signed manifest or replace a release asset. Publish through the validated release process in the private source repository, then verify the tag, exact source commit, version, byte size, SHA-256 digest, and Ed25519 signature.
- Generic Caveman, Impeccable, and Emil skills are provided by the user's global agent layer. Do not vendor copies into this release repository; add a repository skill only for a genuinely release-specific workflow.
- A Git push is not a release or a deployment. Do not create, replace, or delete GitHub release assets unless the user explicitly requests that release operation.
- Source authority: private `Bajna007/DanettiPriceScraper`. Its canonical publisher is `scripts/updates/publish-release.ps1`; this repository never substitutes for that workflow.
- Before proposing any release-repository commit, run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-release-repository.ps1`. When the source checkout is available, also pass `-SourceRepository <path>` to prove source commit, version tag, package version, and repair-script provenance.
