# DanettiPriceScraper-Releases

Public signed Danetti update packages, channel manifests, and authenticated repair tooling only. Application development belongs in the private source repository.

`stable/manifest.json` points to the exact release asset and source commit. Treat it as generated signed data: publish it through the validated source-repository release workflow and verify its signature, size, and SHA-256 digest instead of editing it by hand.

## Release workflow

Source authority is the private [`Bajna007/DanettiPriceScraper`](https://github.com/Bajna007/DanettiPriceScraper) repository. From a clean, reviewed source checkout, its canonical publisher is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/updates/publish-release.ps1 -Version <version>
```

That workflow creates and verifies the package, release asset, signed manifest, source tag, and public repair script. Do not reproduce those mutations here and do not hand-edit signed output.

After publication, run this repository's read-only structural/provenance gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-release-repository.ps1 -SourceRepository "<path-to-DanettiPriceScraper>"
```

Without `-SourceRepository`, the gate still checks the manifest schema, product/channel, semantic version, asset name/size/SHA-256, package URL, source-commit shape, timestamp, and Ed25519 signature encoding. With the source checkout, it also proves that the commit exists, tag `v<version>` resolves to that exact commit, source `package.json` has the same version, and `stable/repair-updater.ps1` equals the file at the signed source commit.

Full package digest and Ed25519 verification remains owned by the authenticated source verifier. Run its documented `scripts/updates/apply-signed-update.ps1 ... -VerifyOnly` flow against the published asset; a green repository-only gate is not a release or deployment claim.
