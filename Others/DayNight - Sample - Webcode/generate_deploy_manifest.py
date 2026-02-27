#!/usr/bin/env python3
"""Generate an S3/CloudFront deployment manifest for this static DayNight site.

The script scans local HTML files, extracts linked assets/pages, and writes a
JSON manifest that can be used to plan uploads and cache behavior.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent
MANIFEST_FILE = ROOT / "deployment-manifest.json"

# Keep this list explicit so the script stays aligned with the repository.
DEFAULT_HTML_PAGES = [
    "index.html",
    "projects.html",
    "inbox.html",
    "analytics.html",
    "settings.html",
    "login.html",
    "about-templatemo.html",
]

HREF_SRC_PATTERN = re.compile(r'(?:href|src)=["\']([^"\']+)["\']', re.IGNORECASE)


@dataclass(frozen=True)
class UploadRule:
    pattern: str
    cache_control: str


@dataclass(frozen=True)
class DeploymentManifest:
    site_name: str
    entry_page: str
    html_pages: list[str]
    static_assets: list[str]
    suggested_upload_order: list[str]
    cloudfront_invalidation_paths: list[str]
    upload_rules: list[UploadRule]


def extract_local_refs(html_text: str) -> set[str]:
    """Return local file references from href/src attributes."""
    refs: set[str] = set()
    for raw_ref in HREF_SRC_PATTERN.findall(html_text):
        ref = raw_ref.strip()
        if not ref or ref.startswith(("http://", "https://", "mailto:", "#", "javascript:")):
            continue
        clean_ref = ref.split("?", 1)[0].split("#", 1)[0]
        if clean_ref:
            refs.add(clean_ref)
    return refs


def existing_files(paths: Iterable[str]) -> list[str]:
    """Keep only files that exist in the repository root."""
    return sorted(path for path in paths if (ROOT / path).is_file())


def build_manifest() -> DeploymentManifest:
    html_pages = existing_files(DEFAULT_HTML_PAGES)
    discovered_refs: set[str] = set()

    for page in html_pages:
        html_text = (ROOT / page).read_text(encoding="utf-8")
        discovered_refs.update(extract_local_refs(html_text))

    local_refs = existing_files(discovered_refs)
    static_assets = sorted(ref for ref in local_refs if not ref.endswith(".html"))

    # Upload HTML last to avoid clients seeing new references before assets exist.
    suggested_upload_order = static_assets + html_pages

    invalidation_paths = sorted({"/", *{f"/{page}" for page in html_pages}})

    rules = [
        UploadRule(pattern="*.html", cache_control="public, max-age=60"),
        UploadRule(pattern="*.css", cache_control="public, max-age=31536000, immutable"),
        UploadRule(pattern="*.js", cache_control="public, max-age=31536000, immutable"),
    ]

    return DeploymentManifest(
        site_name="DayNight Admin",
        entry_page="index.html",
        html_pages=html_pages,
        static_assets=static_assets,
        suggested_upload_order=suggested_upload_order,
        cloudfront_invalidation_paths=invalidation_paths,
        upload_rules=rules,
    )


def main() -> None:
    manifest = build_manifest()
    payload = asdict(manifest)
    payload["upload_rules"] = [asdict(rule) for rule in manifest.upload_rules]

    MANIFEST_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {MANIFEST_FILE.relative_to(ROOT)}")
    print(f"Pages: {len(manifest.html_pages)} | Assets: {len(manifest.static_assets)}")


if __name__ == "__main__":
    main()
