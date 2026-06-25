"""P3 sidecar report: serialize Tier-B sites to *.c2jac.report.json.

The sidecar JSON is the authoritative Tier-B artifact. Inline comment injection
(post-format) is deferred per §9.2a — coordinate-space mapping between C-source
line numbers and post-format Jac line numbers is resolved in a later pass.

Entry point: write_report(input_path, tags)  → writes the JSON file.
             report_json(input_path, tags)   → returns the JSON string.
"""

import json;
import from jaclang.compiler.c2jac.tags { TagTable }

def report_json(input_path: str, tags: TagTable) -> str {
    tier_b = tags.tier_b_entries();
    sites: list[dict] = [];
    for nt in tier_b {
        sites.append(
            {
                "c_line": nt.c_line,
                "idiom": nt.idiom.value,
                "reason": nt.reason,
                "snippet": nt.snippet,

            }
        );
    }
    payload: dict = {"version": 1, "input": input_path, "tier_b_sites": sites,};
    return json.dumps(payload, indent=2);
}

def write_report(input_path: str, tags: TagTable) -> str {
    report_path = input_path.rsplit(".", 1)[0] + ".c2jac.report.json";
    with open(report_path, "w") as f {
        f.write(report_json(input_path, tags));
    }
    return report_path;
}
