# Danetti release distribution

This public repository contains signed manifests and repair/verification tooling,
not application source, credentials, signing keys or private runtime/customer data.
The private `Bajna007/DanettiPriceScraper` publisher
`scripts/updates/publish-release.ps1` is the release authority.

Never hand-edit signed manifests, reconstruct a signer here or replace/delete
release assets without an explicitly requested release operation. Verify tag,
source commit, version, byte size, SHA-256 and Ed25519 signature through the
existing process. A Git push is neither a signed release nor deployment.

For changed release metadata/tooling or actual publication use
`scripts/verify-release-repository.ps1`; supply `-SourceRepository <path>` when
available to verify source/version/tag/repair-script provenance. Plain instructions
need diff/reference review, not a new app build or asset publication. Missing
required release proof is not a pass; do not repeat unchanged checks unnecessarily.

Fetch before comparing refs; preserve active/dirty work and fast-forward only a
clean expected checkout. Stage intended paths; no destructive reset/clean,
force-push or silent switching. Keep Actions disabled. Generic model/style/UI
skills add no value to this distribution contract and must not be copied here.
Report actual changes/checks and publication state without a mandatory audit template.
