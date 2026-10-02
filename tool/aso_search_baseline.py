#!/usr/bin/env python3
"""Capture public iTunes Search API results, not device App Store rankings."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess

APP_ID = 6800177702
TERMS = ("conquest", "conquest isles", "island conquest")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = []
    for country in ("jp", "us"):
        for term in TERMS:
            response = subprocess.run(
                ["curl", "--fail", "--silent", "--show-error", "--max-time", "30",
                 "--get", "https://itunes.apple.com/search",
                 "--data-urlencode", f"term={term}", "--data-urlencode", f"country={country}",
                 "--data-urlencode", "entity=software", "--data-urlencode", "limit=200"],
                check=True, capture_output=True, text=True,
            )
            results = json.loads(response.stdout)["results"]
            rows.append({
                "country": country, "term": term, "count": len(results),
                "own": [[i, item.get("trackName"), item.get("version"), item.get("userRatingCount", 0)]
                        for i, item in enumerate(results, 1) if item.get("trackId") == APP_ID],
                "top10": [[i, item.get("trackName"), item.get("trackId"), item.get("userRatingCount", 0)]
                          for i, item in enumerate(results[:10], 1)],
            })
    snapshot = {
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "source": "iTunes Search API; ordering is not the device App Store search rank",
        "appId": APP_ID, "results": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    for row in rows:
        print(f"{row['country']} / {row['term']}: {row['own'] or 'not returned'}")


if __name__ == "__main__":
    main()
