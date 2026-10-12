import { createHash, timingSafeEqual } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { LEGACY_PUBLIC_KEY, validateReleaseManifest } from "./release-manifest.mjs";

const expectedVersion = argument("version");
const releaseRepository = argument("release-repository");
const manifest = validateReleaseManifest(JSON.parse(await readFile(argument("manifest"), "utf8")), {
  product: "danetti-price-scraper",
  channel: "stable",
  releaseRepository,
  publicKeys: [optionalArgument("public-key") ?? LEGACY_PUBLIC_KEY],
  allowGitDistribution: process.argv.includes("--allow-git-distribution"),
});
if (manifest.version !== expectedVersion) throw new Error("A kiadási manifest verziója eltér.");
if (process.argv.includes("--manifest-only")) {
  console.log(`Danetti ${expectedVersion} manifest eredete és csomagadata rendben.`);
  process.exit(0);
}
const bytes = await readFile(argument("zip"));
const digest = createHash("sha256").update(bytes).digest("hex");
if (
  manifest.asset.size !== bytes.length ||
  !timingSafeEqual(Buffer.from(digest), Buffer.from(manifest.asset.sha256))
)
  throw new Error("A kiadási csomag mérete vagy hash-e érvénytelen.");
const require = createRequire(
  optionalArgument("runtime-root")
    ? resolve(optionalArgument("runtime-root"), "package.json")
    : new URL("../../package.json", import.meta.url)
);
const AdmZip = require("adm-zip");

const zip = new AdmZip(bytes);
const prefix = "danetti-price-scraper/";
const archiveFiles = zip.getEntries().filter((entry) => !entry.isDirectory);
const uniqueNames = new Set();
let expandedSize = 0;
for (const entry of archiveFiles) {
  const name = entry.entryName.replaceAll("\\", "/");
  const relative = name.slice(prefix.length);
  if (
    !name.startsWith(prefix) ||
    !isSafeRelativePath(relative) ||
    uniqueNames.has(name.toLowerCase())
  )
    throw new Error("A release ZIP útvonala vagy ismétlődő fájlneve érvénytelen.");
  uniqueNames.add(name.toLowerCase());
  expandedSize += entry.header.size;
}
if (archiveFiles.length > 50000 || expandedSize > 1024 * 1024 * 1024)
  throw new Error("A release ZIP kibontott mérete túl nagy.");
const entries = new Map(
  zip
    .getEntries()
    .filter((entry) => !entry.isDirectory)
    .map((entry) => [entry.entryName.replaceAll("\\", "/"), entry])
);
const releaseFilesEntry = entries.get(`${prefix}release-files.json`);
const prebuildEntry = entries.get(`${prefix}logs/danetti-runtime-prebuild.json`);
if (!releaseFilesEntry || !prebuildEntry) {
  throw new Error(
    "A release-csomagból hiányzik a biztonságos fájllista vagy a runtime prebuild manifest."
  );
}
const releaseFiles = parseZipJson(releaseFilesEntry);
const prebuild = parseZipJson(prebuildEntry);
if (
  releaseFiles.product !== "danetti-price-scraper" ||
  releaseFiles.version !== expectedVersion ||
  !Array.isArray(releaseFiles.files) ||
  prebuild.schema !== 1 ||
  prebuild.product !== "danetti-price-scraper" ||
  prebuild.version !== expectedVersion ||
  prebuild.releaseCommit !== manifest.release_commit ||
  !Array.isArray(prebuild.requiredOutputs)
) {
  throw new Error("A release fájllista vagy runtime prebuild manifest azonosítója érvénytelen.");
}
const listedFiles = new Set(releaseFiles.files);
if (listedFiles.size !== releaseFiles.files.length) throw new Error("Ismétlődő release fájllista.");
for (const name of entries.keys()) {
  if (!listedFiles.has(name.slice(prefix.length)))
    throw new Error(`Nem felsorolt release-fájl: ${name}`);
}
const packageJson = parseZipJson(entries.get(`${prefix}package.json`));
if (packageJson.name !== "danetti-price-scraper" || packageJson.version !== expectedVersion)
  throw new Error("A release package.json azonosítója érvénytelen.");
for (const path of releaseFiles.files) {
  if (!isSafeRelativePath(path) || !entries.has(`${prefix}${path}`))
    throw new Error(`Hiányzó vagy nem biztonságos release-fájl: ${path}`);
}
for (const output of prebuild.requiredOutputs) {
  if (!listedFiles.has(output.path))
    throw new Error(`A prebuild output nincs a fájllistában: ${output.path}`);
  const entry = entries.get(`${prefix}${output.path}`);
  const outputBytes = entry?.getData();
  if (
    !entry ||
    outputBytes.length !== output.size ||
    createHash("sha256").update(outputBytes).digest("hex") !== output.sha256
  ) {
    throw new Error(`A prebuild output hash-e érvénytelen: ${output.path}`);
  }
}
console.log(`Danetti ${expectedVersion} eredete, csomaghash-e és prebuild manifestje rendben.`);

function optionalArgument(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : undefined;
}
function argument(name) {
  const value = optionalArgument(name);
  if (!value) throw new Error(`Hiányzó --${name} argumentum.`);
  return value;
}

function isSafeRelativePath(path) {
  return (
    typeof path === "string" &&
    path.length > 0 &&
    !path.startsWith("/") &&
    !path.startsWith("\\") &&
    !/^[A-Za-z]:/.test(path) &&
    !/[\u0000-\u001f:]/.test(path) &&
    !path
      .split(/[\\/]/)
      .some(
        (part) =>
          !part || part === "." || part === ".." || part === ".git" || part === "node_modules"
      ) &&
    !path.split(/[\\/]/).some((part) => /^\.env(?:$|\.)/.test(part) && part !== ".env.example") &&
    (!path.startsWith("logs/") || path === "logs/danetti-runtime-prebuild.json")
  );
}

function parseZipJson(entry) {
  return JSON.parse(
    entry
      .getData()
      .toString("utf8")
      .replace(/^\uFEFF/, "")
  );
}
