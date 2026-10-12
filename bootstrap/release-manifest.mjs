import { createPublicKey, verify } from "node:crypto";

export const RELEASE_REPOSITORY = "Bajna007/DanettiPriceScraper-Releases";
export const GIT_MANIFEST_URL = `https://api.github.com/repos/${RELEASE_REPOSITORY}/contents/stable/manifest-git.json?ref=main`;
export const LEGACY_PUBLIC_KEY = "b1lkLdDw9CaJ+62oHEcGAmQgw9so6E+nxiyuCWkJUp4=";

export function gitPackageUrl(repository, artifactCommit, version) {
  return `https://raw.githubusercontent.com/${repository}/${artifactCommit}/packages/v${version}/danetti-price-scraper-${version}.zip`;
}

export function validateReleaseManifest(value, config) {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("manifest must be an object");
  const manifest = value;
  const gitDistribution = manifest.schema_version === "2.0.0";
  if (
    (!gitDistribution && manifest.schema_version !== "1.0.0") ||
    manifest.product !== config.product ||
    manifest.channel !== config.channel ||
    typeof manifest.version !== "string" ||
    !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(manifest.version ?? "") ||
    !manifest.asset ||
    typeof manifest.asset !== "object" ||
    Array.isArray(manifest.asset) ||
    typeof manifest.changelog !== "string" ||
    typeof manifest.published_at !== "string" ||
    !Number.isFinite(Date.parse(manifest.published_at)) ||
    typeof manifest.release_commit !== "string" ||
    !/^[a-f0-9]{40}$/.test(manifest.release_commit) ||
    manifest.asset.name !== `${config.product}-${manifest.version}.zip` ||
    !Number.isSafeInteger(manifest.asset.size) ||
    manifest.asset.size < 1 ||
    manifest.asset.size > 1024 * 1024 * 1024 ||
    typeof manifest.asset.sha256 !== "string" ||
    !/^[a-f0-9]{64}$/.test(manifest.asset.sha256) ||
    typeof manifest.package_url !== "string"
  ) {
    throw new Error("manifest fields invalid");
  }
  if (gitDistribution) {
    if (
      config.allowGitDistribution !== true ||
      config.releaseRepository !== RELEASE_REPOSITORY ||
      manifest.distribution !== "github_git" ||
      typeof manifest.artifact_commit !== "string" ||
      !/^[a-f0-9]{40}$/.test(manifest.artifact_commit ?? "") ||
      manifest.asset.size > 100 * 1024 * 1024 ||
      manifest.package_url !==
        gitPackageUrl(config.releaseRepository, manifest.artifact_commit, manifest.version)
    ) {
      throw new Error("manifest GitHub distribution invalid");
    }
    return manifest;
  }
  if (
    manifest.package_url !==
      `https://github.com/${config.releaseRepository}/releases/download/v${manifest.version}/${manifest.asset.name}` ||
    typeof manifest.signature !== "string"
  ) {
    throw new Error("manifest package invalid");
  }
  const unsigned = { ...manifest };
  delete unsigned.signature;
  const signature = Buffer.from(manifest.signature, "base64");
  const payload = Buffer.from(JSON.stringify(canonicalize(unsigned)));
  const valid =
    signature.length === 64 &&
    config.publicKeys.some((encoded) => {
      const raw = Buffer.from(encoded, "base64");
      if (raw.length !== 32) return false;
      const key = createPublicKey({
        key: Buffer.concat([Buffer.from("302a300506032b6570032100", "hex"), raw]),
        format: "der",
        type: "spki",
      });
      return verify(null, payload, key, signature);
    });
  if (!valid) throw new Error("manifest signature invalid");
  return manifest;
}

export function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object")
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalize(value[key])])
    );
  return value;
}
