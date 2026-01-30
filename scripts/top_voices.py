#!/usr/bin/env python3
"""Script to generate a markdown table of top voices from GitHub discussions."""

import argparse
import subprocess
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from typing import Any

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


def fetch_issue_comments(since_date: str) -> list[dict[str, Any]]:
    """Fetch issue comments using GitHub CLI."""
    comments = []
    try:
        # Fetch issue comments with pagination
        page = 1
        while True:
            cmd = [
                "gh",
                "api",
                f"/repos/Jaseci-Labs/jaseci/issues/comments?since={since_date}&per_page=100&page={page}",
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                break

            import json

            data = json.loads(result.stdout)
            if not data:
                break

            for item in data:
                author = item.get("author", {})
                if author.get("type") == "Bot":
                    continue
                comments.append({
                    "author": author.get("login", "unknown"),
                    "date": item.get("created_at", ""),
                })

            # Check if we got a full page (if less, we're done)
            if len(data) < 100:
                break
            page += 1
    except Exception as e:
        print(f"Warning: Error fetching issue comments: {e}")
    return comments


def fetch_pr_comments(since_date: str) -> list[dict[str, Any]]:
    """Fetch PR review comments using GitHub CLI."""
    comments = []
    try:
        page = 1
        while True:
            cmd = [
                "gh",
                "api",
                f"/repos/Jaseci-Labs/jaseci/pulls/comments?since={since_date}&per_page=100&page={page}",
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            if result.returncode != 0:
                break

            import json

            data = json.loads(result.stdout)
            if not data:
                break

            for item in data:
                author = item.get("author", {})
                if author.get("type") == "Bot":
                    continue
                comments.append({
                    "author": author.get("login", "unknown"),
                    "date": item.get("created_at", ""),
                })

            if len(data) < 100:
                break
            page += 1
    except Exception as e:
        print(f"Warning: Error fetching PR comments: {e}")
    return comments


def fetch_pr_reviews(since_date: str) -> list[dict[str, Any]]:
    """Fetch PR reviews using GitHub CLI."""
    reviews = []
    try:
        # Get all PRs merged or updated since date
        cmd = [
            "gh",
            "pr",
            "list",
            "--repo", "Jaseci-Labs/jaseci",
            "--state", "merged",
            "--limit", "500",
            "--json", "number,updatedAt,mergedAt",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            return reviews

        import json

        prs = json.loads(result.stdout)
        since_dt = datetime.fromisoformat(since_date.replace("Z", "+00:00"))

        for pr in prs:
            # Check if PR was updated/merged since date
            pr_date = pr.get("mergedAt") or pr.get("updatedAt")
            if not pr_date:
                continue
            pr_date_dt = datetime.fromisoformat(pr_date.replace("Z", "+00:00"))
            if pr_date_dt < since_dt:
                continue

            # Fetch reviews for this PR
            pr_number = pr.get("number")
            review_cmd = [
                "gh",
                "api",
                f"/repos/Jaseci-Labs/jaseci/pulls/{pr_number}/reviews",
            ]
            review_result = subprocess.run(
                review_cmd, capture_output=True, text=True, check=False
            )
            if review_result.returncode == 0:
                review_data = json.loads(review_result.stdout)
                for review in review_data:
                    author = review.get("user", {})
                    if author.get("type") == "bot":
                        continue
                    review_date = review.get("submitted_at", "")
                    if review_date:
                        review_dt = datetime.fromisoformat(review_date.replace("Z", "+00:00"))
                        if review_dt >= since_dt:
                            reviews.append({
                                "author": author.get("login", "unknown"),
                                "date": review_date,
                            })
    except Exception as e:
        print(f"Warning: Error fetching PR reviews: {e}")
    return reviews


def fetch_issues_created(since_date: str) -> list[dict[str, Any]]:
    """Fetch issues created using GitHub CLI."""
    issues = []
    try:
        cmd = [
            "gh",
            "issue",
            "list",
            "--repo", "Jaseci-Labs/jaseci",
            "--limit", "500",
            "--search", f"created:>{since_date[:10]}",
            "--json", "author,createdAt",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            return issues

        import json

        data = json.loads(result.stdout)
        for item in data:
            author = item.get("author", {})
            if author.get("type") == "Bot":
                continue
            issues.append({
                "author": author.get("login", "unknown"),
                "date": item.get("createdAt", ""),
            })
    except Exception as e:
        print(f"Warning: Error fetching issues: {e}")
    return issues


def process_voices(
    comments: list[dict[str, Any]],
    reviews: list[dict[str, Any]],
    issues: list[dict[str, Any]],
    days: int,
) -> list[dict[str, Any]]:
    """Process voice data to get stats for a specific period."""
    since_date = (datetime.now(UTC) - timedelta(days=days)).replace(tzinfo=None)

    voices: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "comments": 0,
            "reviews": 0,
            "issues_created": 0,
            "active_days": set(),
        }
    )

    # Process comments
    for item in comments:
        try:
            date = datetime.fromisoformat(item["date"].replace("Z", "+00:00")).replace(tzinfo=None)
            if date >= since_date:
                author = item["author"]
                voices[author]["comments"] += 1
                voices[author]["active_days"].add(date.date())
        except (ValueError, KeyError):
            continue

    # Process reviews
    for item in reviews:
        try:
            date = datetime.fromisoformat(item["date"].replace("Z", "+00:00")).replace(tzinfo=None)
            if date >= since_date:
                author = item["author"]
                voices[author]["reviews"] += 1
                voices[author]["active_days"].add(date.date())
        except (ValueError, KeyError):
            continue

    # Process issues created
    for item in issues:
        try:
            date = datetime.fromisoformat(item["date"].replace("Z", "+00:00")).replace(tzinfo=None)
            if date >= since_date:
                author = item["author"]
                voices[author]["issues_created"] += 1
                voices[author]["active_days"].add(date.date())
        except (ValueError, KeyError):
            continue

    # Sort by total engagement (comments + reviews + issues)
    return sorted(
        [
            {
                "name": name,
                "comments": data["comments"],
                "reviews": data["reviews"],
                "issues": data["issues_created"],
                "active_days": len(data["active_days"]),
                "total": data["comments"] + data["reviews"] + data["issues_created"],
            }
            for name, data in voices.items()
        ],
        key=lambda x: x["total"],
        reverse=True,
    )


def generate_html_table(voices: list[dict[str, Any]], days: int) -> str:
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
        name = voice["name"]
        comments = voice["comments"]
        reviews = voice["reviews"]
        issues = voice["issues"]
        active_days = voice["active_days"]
        lines.append(
            f"<tr><td>{name}</td><td>{comments}</td><td>{reviews}</td><td>{issues}</td><td>{active_days}</td></tr>"
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

    # Check if gh CLI is available
    if not check_gh_cli():
        print("# Top Voices\n\n> GitHub CLI not found or not authenticated. Unable to fetch discussion data.\n")
        return

    periods = []
    if args.days is not None:
        periods.append(args.days)
    for p in [7, 30, 180, 365]:
        if p not in periods:
            periods.append(p)
    if not periods:
        return

    # Calculate the earliest date we need
    max_days = max(periods)
    since_date = (datetime.now(UTC) - timedelta(days=max_days)).strftime("%Y-%m-%dT%H:%M:%SZ")

    print(f"Fetching discussion data since {since_date}...", file=sys.stderr)

    # Fetch all data once
    comments = fetch_issue_comments(since_date)
    pr_comments = fetch_pr_comments(since_date)
    reviews = fetch_pr_reviews(since_date)
    issues = fetch_issues_created(since_date)

    # Combine comments from issues and PRs
    all_comments = comments + pr_comments

    print(f"Found {len(all_comments)} comments, {len(reviews)} reviews, {len(issues)} issues", file=sys.stderr)

    # Generate tables for each period
    html = []
    html.append(get_table_css())
    html.append('<div class="tabcontent">')

    for days in periods:
        voices = process_voices(all_comments, reviews, issues, days)
        html.append(generate_html_table(voices, days))

    html.append("</div>")

    print("\n".join(html))


if __name__ == "__main__":
    import sys
    main()
