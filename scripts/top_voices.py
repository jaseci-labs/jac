#!/usr/bin/env python3
"""Script to generate a markdown table of top voices from GitHub discussions."""

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from typing import Any

REPO = "Jaseci-Labs/jaseci"
PER_PAGE = 100
MAX_PR_LIMIT = 500
DEFAULT_PERIODS = [7, 30, 180, 365]

table_css = """
<style>
#tabs {
    display: flex;
    justify-content: space-between;
    padding: 0;
    margin: 0 0 1em 0;
    border-bottom: 2px solid #222;
    background: #23272e;
    list-style: none;
    width: 100%;
}
#tabs li {
    flex: 1 1 0;
    padding: 0.7em 1.5em;
    margin: 0;
    cursor: pointer;
    border: 1px solid #222;
    border-bottom: none;
    background: #23272e;
    color: #bfc7d5;
    border-radius: 8px 8px 0 0;
    transition: background 0.2s, color 0.2s;
    font-weight: 500;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
#tabs li.active, #tabs li:hover {
    background: #181b20;
    color: #fff;
    font-weight: bold;
    border-bottom: 2px solid #181b20;
    box-shadow: 0 -2px 8px #181b20;
    z-index: 2;
}
.tabcontent {
    border: 1px solid #222;
    border-radius: 0 0 8px 8px;
    padding: 1.5em;
    margin-bottom: 2em;
    box-shadow: 0 2px 8px rgba(0,0,0,0.12);
    color: #e0e6ed;
}
.tabcontent table {
    width: 100%;
    border-collapse: collapse;
    margin: 1em 0;
    font-size: 1em;
    background: #23272e;
    color: #e0e6ed;
}
.tabcontent th, .tabcontent td {
    border: 1px solid #222;
    padding: 0.7em 1em;
    text-align: left;
}
.tabcontent th {
    background: #181b20;
    color: #7ecfff;
    font-weight: 600;
}
.tabcontent tr:nth-child(even) {
    background: #23272e;
}
.tabcontent tr:hover {
    background: #2a313a;
}
</style>
"""


def check_gh_cli() -> bool:
    """Check if GitHub CLI is available and authenticated."""
    try:
        result = subprocess.run(
            ["gh", "auth", "status"],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False


def is_bot(user_data: dict | str) -> bool:
    """Check if a user is a bot."""
    if isinstance(user_data, dict):
        return (
            user_data.get("type", "").lower() == "bot"
            or "[bot]" in user_data.get("login", "").lower()
        )
    return "[bot]" in str(user_data).lower()


def paginated_api(endpoint: str) -> list[dict]:
    """Fetch all pages from a GitHub API endpoint."""
    items = []
    page = 1
    while True:
        cmd = ["gh", "api", f"{endpoint}&per_page={PER_PAGE}&page={page}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            break
        data = json.loads(result.stdout)
        if not data:
            break
        items.extend(data)
        if len(data) < PER_PAGE:
            break
        page += 1
    return items


def fetch_comments(since_date: str) -> list[dict]:
    """Fetch issue and PR comments."""
    comments = []

    for item in paginated_api(f"/repos/{REPO}/issues/comments?since={since_date}"):
        if not is_bot(item.get("user", {})):
            comments.append(
                {
                    "author": item["user"].get("login", "unknown"),
                    "date": item.get("created_at", ""),
                }
            )

    for item in paginated_api(f"/repos/{REPO}/pulls/comments?since={since_date}"):
        if not is_bot(item.get("user", {})):
            comments.append(
                {
                    "author": item["user"].get("login", "unknown"),
                    "date": item.get("created_at", ""),
                }
            )

    return comments


def fetch_reviews(since_date: str) -> list[dict]:
    """Fetch PR reviews."""
    reviews: list[dict] = []
    cmd = [
        "gh",
        "pr",
        "list",
        "--repo",
        REPO,
        "--state",
        "merged",
        "--limit",
        str(MAX_PR_LIMIT),
        "--json",
        "number,updatedAt,mergedAt",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return reviews

    since_dt = datetime.fromisoformat(since_date.replace("Z", "+00:00"))
    for pr in json.loads(result.stdout):
        pr_date = pr.get("mergedAt") or pr.get("updatedAt")
        if not pr_date:
            continue
        pr_date_dt = datetime.fromisoformat(pr_date.replace("Z", "+00:00"))
        if pr_date_dt < since_dt:
            continue

        review_cmd = ["gh", "api", f"/repos/{REPO}/pulls/{pr['number']}/reviews"]
        review_result = subprocess.run(
            review_cmd, capture_output=True, text=True, check=False
        )
        if review_result.returncode == 0:
            for review in json.loads(review_result.stdout):
                if is_bot(review.get("user", {})):
                    continue
                review_date = review.get("submitted_at", "")
                if review_date:
                    review_dt = datetime.fromisoformat(
                        review_date.replace("Z", "+00:00")
                    )
                    if review_dt >= since_dt:
                        reviews.append(
                            {
                                "author": review["user"].get("login", "unknown"),
                                "date": review_date,
                            }
                        )
    return reviews


def fetch_issues(since_date: str) -> list[dict]:
    """Fetch issues created."""
    cmd = [
        "gh",
        "issue",
        "list",
        "--repo",
        REPO,
        "--limit",
        str(MAX_PR_LIMIT),
        "--search",
        f"created:>{since_date[:10]}",
        "--json",
        "author,createdAt",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return []

    issues = []
    for item in json.loads(result.stdout):
        if not is_bot(item.get("author", {})):
            issues.append(
                {
                    "author": item["author"].get("login", "unknown"),
                    "date": item.get("createdAt", ""),
                }
            )
    return issues


def fetch_real_names(usernames: set) -> dict:
    """Fetch real names for GitHub usernames."""
    names = {}
    for username in usernames:
        if username == "unknown":
            continue
        cmd = ["gh", "api", f"/users/{username}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode == 0:
            user_data = json.loads(result.stdout)
            name = user_data.get("name")
            if name and name.lower() != username.lower():
                names[username] = name
    return names


def process_voices(
    comments: list, reviews: list, issues: list, days: int
) -> list[dict[str, Any]]:
    """Process voice data to get stats for a specific period."""
    since_date = (datetime.now(UTC) - timedelta(days=days)).replace(tzinfo=None)

    voices: dict[str, dict] = defaultdict(
        lambda: {
            "comments": 0,
            "reviews": 0,
            "issues": 0,
            "active_days": set(),
            "names": defaultdict(int),
        }
    )
    all_usernames = set()

    for items, key in [
        (comments, "comments"),
        (reviews, "reviews"),
        (issues, "issues"),
    ]:
        for item in items:
            try:
                date = datetime.fromisoformat(
                    item["date"].replace("Z", "+00:00")
                ).replace(tzinfo=None)
                if date < since_date:
                    continue
            except (ValueError, KeyError):
                continue

            author = item["author"]
            if author == "unknown" or is_bot(author):
                continue

            all_usernames.add(author)
            voices[author][key] += 1
            voices[author]["active_days"].add(date.date())
            voices[author]["names"][author] += 1

    print(f"Fetching names for {len(all_usernames)} users...", file=sys.stderr)
    real_names = fetch_real_names(all_usernames)

    results = []
    for username, data in voices.items():
        if is_bot(username):
            continue
        display_name = real_names.get(username, username)
        if is_bot(display_name):
            continue
        total = data["comments"] + data["reviews"] + data["issues"]
        results.append(
            {
                "name": display_name,
                "comments": data["comments"],
                "reviews": data["reviews"],
                "issues": data["issues"],
                "active_days": len(data["active_days"]),
                "total": total,
            }
        )

    return sorted(results, key=lambda x: x["total"], reverse=True)


def generate_html_table(voices: list[dict], days: int) -> str:
    """Generate an HTML table from voice data."""
    if not voices:
        return f"<p>No discussion activity found in the last {days} days.</p>"

    end_date = datetime.now(UTC).date()
    start_date = end_date - timedelta(days=days)

    lines = []
    lines.append(
        f"<h3>Top voices in the last {days} days "
        f"({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')})</h3>"
    )
    lines.append("<table>")
    lines.append(
        "<thead><tr><th>Voice</th><th>Comments</th><th>Reviews</th><th>Issues</th><th>Active Days</th></tr></thead>"
    )
    lines.append("<tbody>")
    for voice in voices:
        lines.append(
            f"<tr><td>{voice['name']}</td><td>{voice['comments']}</td>"
            f"<td>{voice['reviews']}</td><td>{voice['issues']}</td><td>{voice['active_days']}</td></tr>"
        )
    lines.append("</tbody></table>")
    return "\n".join(lines)


def get_table_css() -> str:
    """Return CSS for the table design."""
    return table_css


def main() -> None:
    """Run the script."""
    parser = argparse.ArgumentParser(
        description="Generate a table of top voices from GitHub discussions."
    )
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="Generate an additional table for a specific number of days.",
    )

    args = parser.parse_args()

    if not check_gh_cli():
        print(
            "# Top Voices\n\n> GitHub CLI not found or not authenticated. Unable to fetch discussion data.\n"
        )
        return

    periods = []
    if args.days is not None:
        periods.append(args.days)
    for p in DEFAULT_PERIODS:
        if p not in periods:
            periods.append(p)
    if not periods:
        return

    max_days = max(periods)
    since_date = (datetime.now(UTC) - timedelta(days=max_days)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )

    print(f"Fetching discussion data since {since_date}...", file=sys.stderr)

    comments = fetch_comments(since_date)
    reviews = fetch_reviews(since_date)
    issues = fetch_issues(since_date)

    print(
        f"Found {len(comments)} comments, {len(reviews)} reviews, {len(issues)} issues",
        file=sys.stderr,
    )

    html = []
    html.append(get_table_css())
    html.append('<div class="tabcontent">')

    for days in periods:
        voices = process_voices(comments, reviews, issues, days)
        html.append(generate_html_table(voices, days))

    html.append("</div>")
    print("\n".join(html))


if __name__ == "__main__":
    main()
