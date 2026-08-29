# DanettiPriceScraper Releases

Public, verify-only distribution repository for signed Danetti stable-channel metadata and
authenticated repair tooling. Application source, release construction, and signing authority stay
in the private [`Bajna007/DanettiPriceScraper`](https://github.com/Bajna007/DanettiPriceScraper)
repository.

## Tracked contents

- `stable/manifest.json`: generated stable-channel manifest pointing to the exact GitHub release
  asset and private source commit;
- `stable/repair-updater.ps1`: authenticated repair entry point copied from that signed source
  commit;
- `scripts/verify-release-repository.ps1`: read-only structure and provenance gate.

Release packages are GitHub release assets, not application-source files committed to this tree.
This repository must never contain private signing keys, credentials, customer data, database
exports, backups, or local environment files.

## Trust model

Do not hand-edit a signed manifest or replace a published asset. The private source repository owns
the canonical publisher:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/updates/publish-release.ps1 -Version <version>
```

That workflow builds and verifies the package, publishes the release asset, creates the source tag,
signs the manifest, and copies the public repair script. A commit or push in this repository is not a
release.

## Verify this repository

From this checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-release-repository.ps1
```

When the private source checkout is available, add it to prove source-commit, tag, package-version,
and repair-script provenance:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-release-repository.ps1 `
  -SourceRepository "<path-to-DanettiPriceScraper>"
```

The repository-only gate validates manifest structure, product/channel, semantic version, asset
name, byte size, SHA-256 field, URL, source-commit shape, timestamp, signature encoding, and local
repair-tool consistency. With `-SourceRepository`, it additionally proves that tag `v<version>`
resolves to the declared source commit and that source metadata matches.

Full package digest and Ed25519 verification remains owned by the authenticated source verifier.
Use the private repository's documented `apply-signed-update.ps1 ... -VerifyOnly` flow against the
published asset. A green metadata check alone is not proof that a release was deployed or installed.
