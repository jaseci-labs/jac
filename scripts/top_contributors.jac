"""Script to generate a markdown table of top contributors from local git repository."""

import argparse;
import subprocess;
import from collections { defaultdict }
import from datetime { UTC, datetime, timedelta }
import from typing { Any }

glob tabel_css = """
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
""";

"""Get commits from local git repository for the specified number of days."""
def get_commits_from_git(days: int) -> list[dict[str, str]] {
    since_date = (datetime.now(UTC) - timedelta(days=days)).strftime("%Y-%m-%d");
    cmd = [
        "git",
        "log",
        f"--since={since_date}",
        "--pretty=format:%an|%ae|%ad",
        "--date=short",

    ];
    try {
        result = subprocess.run(cmd, capture_output=True, text=True, check=True);
        commits: list[dict[str, str]] = [];
        for line in result.stdout.strip().split("\n") {
            if not line {
                continue;
            }
            parts = line.split("|");
            if len(parts) == 3 {
                commits.append(
                    {
                        "author_name": parts[0],
                        "author_email": parts[1],
                        "commit_date": parts[2],

                    }
                );
            }
        }
        return commits;
    } except subprocess.CalledProcessError as e {
        print(f"Error fetching commits from git: {e}");
        return [];
    }
}

"""Process commits to get contributor stats for a specific period."""
def process_contributors(
    commits: list[dict[str, str]], days: int
) -> list[dict[str, Any]] {
    since_date = (datetime.now(UTC) - timedelta(days=days)).date();
    contributors: dict[str, dict[str, Any]] = defaultdict(
        lambda : {"commits": 0, "active_days": set(), "names": defaultdict(int)}
    );
    for commit in commits {
        try {
            commit_date = datetime.strptime(commit["commit_date"], "%Y-%m-%d").date();
        } except ValueError {
            continue;
        }
        if commit_date > since_date {
            author_name = commit["author_name"];
            author_email = commit["author_email"];
            contributors[author_email]["commits"] += 1;
            contributors[author_email]["active_days"].add(commit_date);
            contributors[author_email]["names"][author_name] += 1;
        }
    }
    return sorted(
        [
            {
                "name": max(data["names"].items(), key=lambda x : x[1])[0],
                "email": email,
                "commits": data["commits"],
                "active_days": len(data["active_days"]),

            } for (email, data) in contributors.items()
        ],
        key=lambda x : x["commits"],
        reverse=True,
    );
}

"""Generate an HTML table from contributor data and return as string."""
def generate_html_table(contributors: list[dict[str, Any]], days: int) -> str {
    if not contributors {
        return f"<p>No contributions found in the last {days} days.</p>";
    }
    end_date = datetime.now(UTC).date();
    start_date = end_date - timedelta(days=days);
    lines: list[str] = [];
    lines.append(
        f"<h3>Top contributors in the last {days} days "
        f"({start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')})</h3>"
    );
    lines.append("<table>");
    lines.append(
        "<thead><tr><th>Contributor</th><th>Commits</th><th>Active Days</th></tr></thead>"
    );
    lines.append("<tbody>");
    for contributor in contributors {
        name = contributor["name"];
        commits = contributor["commits"];
        active_days = contributor["active_days"];
        lines.append(
            f"<tr><td>{name}</td><td>{commits}</td><td>{active_days}</td></tr>"
        );
    }
    lines.append("</tbody></table>");
    return "\n".join(lines);
}

"""Return CSS for the tab and table design."""
def get_tabs_css -> str {
    return tabel_css;
}

glob parser = argparse.ArgumentParser(
         description="Generate a table of top contributors from local git repository."
     );

with entry {
    parser.add_argument(
        "--days",
        type=int,
        default=None,
        help="Generate an additional table for a specific number of days.",
    );
}

glob args = parser.parse_known_args()[0],
     periods: list[int] = [];

with entry {
    if args.days is not None {
        periods.append(args.days);
    }
    for p in [7, 30, 180, 365] {
        if p not in periods {
            periods.append(p);
        }
    }
    if not periods {
        return;
    }
}

glob max_days = max(periods),
     all_commits = get_commits_from_git(max_days),
     html: list[str] = [];

with entry {
    html.append(get_tabs_css());
    html.append('<div class="tabcontent">');
    for days in periods {
        contributors = process_contributors(all_commits, days);
        html.append(generate_html_table(contributors, days));
    }
    html.append("</div>");
    print("\n".join(html));
}
