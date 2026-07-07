#!/usr/bin/env python3
"""Generate a self-hosted stargazers-over-time SVG for the README.

Fetches the star timeline from the GitHub REST API (sampled pages) and renders
a line chart to contents/images/star-history.svg. Pure standard library.

Auth: reads GITHUB_TOKEN / GH_TOKEN from the environment (required in CI to
avoid the 60 req/hour unauthenticated limit). Run locally with:
    GITHUB_TOKEN=<pat> python3 .github/scripts/gen_star_history.py
"""
import json, math, os, sys, urllib.request
from datetime import datetime, timezone

REPO = os.environ.get("STAR_REPO", "halfrost/Halfrost-Field")
OUT = os.environ.get("STAR_OUT", "contents/images/star-history.svg")
TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
API = "https://api.github.com"


def api(path, accept="application/vnd.github+json"):
    req = urllib.request.Request(API + path)
    req.add_header("Accept", accept)
    req.add_header("User-Agent", "star-history-generator")
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def collect_points():
    total = api(f"/repos/{REPO}")["stargazers_count"]
    last_page = max(1, math.ceil(total / 100))
    # sample ~28 pages evenly across the whole history
    step = max(1, last_page // 27)
    pages = list(range(1, last_page + 1, step))
    pts = []
    for p in pages:
        data = api(f"/repos/{REPO}/stargazers?per_page=100&page={p}",
                   "application/vnd.github.star+json")
        if not data:
            continue
        d = data[0].get("starred_at")
        if d:
            t = datetime.strptime(d, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            pts.append((t, (p - 1) * 100))
    pts.append((datetime.now(timezone.utc), total))
    pts.sort()
    return pts, total


def render(pts, total):
    W, H = 800, 400
    ML, MR, MT, MB = 72, 30, 46, 44
    PW, PH = W - ML - MR, H - MT - MB
    t0, t1 = pts[0][0], pts[-1][0]
    span = (t1 - t0).total_seconds() or 1
    ymax = (total // 2000 + 1) * 2000
    ystep = 2000 if ymax <= 16000 else 5000

    def X(t): return ML + PW * ((t - t0).total_seconds() / span)
    def Y(v): return MT + PH * (1 - v / ymax)

    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" font-family="-apple-system,Segoe UI,Helvetica,Arial,sans-serif">',
         f'<rect x="0" y="0" width="{W}" height="{H}" rx="10" fill="#ffffff"/>',
         f'<text x="{ML}" y="26" font-size="16" font-weight="700" fill="#1f2328">Star History</text>',
         f'<text x="{W-MR}" y="26" font-size="12" fill="#57606a" text-anchor="end">{REPO}</text>']
    for v in range(0, ymax + 1, ystep):
        y = Y(v)
        s.append(f'<line x1="{ML}" y1="{y:.1f}" x2="{W-MR}" y2="{y:.1f}" stroke="#eaeef2" stroke-width="1"/>')
        lab = f'{v//1000}k' if v else '0'
        s.append(f'<text x="{ML-8}" y="{y+4:.1f}" font-size="11" fill="#8c959f" text-anchor="end">{lab}</text>')
    for yr in range(t0.year, t1.year + 1):
        xt = datetime(yr, 1, 1, tzinfo=timezone.utc)
        if xt < t0 or xt > t1:
            continue
        x = X(xt)
        s.append(f'<line x1="{x:.1f}" y1="{MT}" x2="{x:.1f}" y2="{MT+PH}" stroke="#f2f4f6" stroke-width="1"/>')
        s.append(f'<text x="{x:.1f}" y="{MT+PH+18}" font-size="11" fill="#8c959f" text-anchor="middle">{yr}</text>')
    line = " ".join(f'{X(t):.1f},{Y(v):.1f}' for t, v in pts)
    s.append(f'<polygon points="{ML},{MT+PH} {line} {W-MR},{MT+PH}" fill="#2f81f7" fill-opacity="0.10"/>')
    s.append(f'<polyline points="{line}" fill="none" stroke="#2f81f7" stroke-width="2.4" '
             f'stroke-linejoin="round" stroke-linecap="round"/>')
    ex, ey = X(pts[-1][0]), Y(pts[-1][1])
    s.append(f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="4" fill="#2f81f7"/>')
    s.append(f'<text x="{ex-6:.1f}" y="{ey-8:.1f}" font-size="12" font-weight="700" '
             f'fill="#2f81f7" text-anchor="end">{total:,} ★</text>')
    s.append('</svg>')
    return "\n".join(s)


def main():
    pts, total = collect_points()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(render(pts, total))
    print(f"wrote {OUT} ({total:,} stars, {len(pts)} points)")


if __name__ == "__main__":
    sys.exit(main())
