"""Machine-readable c2jac fidelity sidecars.

Human comment headers stay in lift.render_c2jac_report; this module owns the
JSON provenance artifact for re-lifts, project aggregates, and the AI loop.
"""

import json;
import os;
import from jaclang.compiler.cfront.fidelity { band_of_code }
import from jaclang.compiler.passes.main.cast_load_pass { CLiftSite }

obj C2JacReport {
    has version: int = 1,
        source: str = "",
        output: str = "",
        lenient: bool = True,
        sites: list[dict] = [],
        quarantined_functions: list[str] = [],
        tier_b_count: int = 0;

    def to_dict -> dict {
        return {
            "version": self.version,
            "source": self.source,
            "output": self.output,
            "lenient": self.lenient,
            "sites": self.sites,
            "quarantined_functions": self.quarantined_functions,
            "tier_b_count": self.tier_b_count
        };
    }
}

def site_to_dict(site: CLiftSite) -> dict {
    return {
        "code": site.code,
        "band": site.band if site.band else band_of_code(site.code),
        "line": site.line,
        "msg": site.msg,
        "function": site.function,
        "quarantined": site.quarantined
    };
}

def build_c2jac_report(
    source: str,
    output: str,
    sites: list[CLiftSite],
    quarantined: list[str],
    lenient: bool = True
) -> C2JacReport {
    site_dicts = [site_to_dict(s) for s in sites];
    return C2JacReport(
        source=source,
        output=output,
        lenient=lenient,
        sites=site_dicts,
        quarantined_functions=list(quarantined),
        tier_b_count=len(site_dicts)
    );
}

def build_c2jac_report_from_diags(
    source: str,
    output: str,
    diags: list[tuple[str, str, int]],
    quarantined: list[str] | None = None,
    lenient: bool = True
) -> C2JacReport {
    # Back-compat path when only (code, msg, line) triples are available.
    qset = set(quarantined or []);
    sites: list[dict] = [];
    for (code, msg, line) in diags {
        sites.append(
            {
                "code": code,
                "band": band_of_code(code),
                "line": line,
                "msg": msg,
                "function": None,
                "quarantined": False
            }
        );
    }
    return C2JacReport(
        source=source,
        output=output,
        lenient=lenient,
        sites=sites,
        quarantined_functions=list(qset),
        tier_b_count=len(sites)
    );
}

def report_sidecar_path(jac_or_c_path: str) -> str {
    stem = jac_or_c_path;
    for suf in [".c2jac.report.json", ".jac", ".c", ".i"] {
        if stem.endswith(suf) {
            stem = stem[: -len(suf)];
            break;
        }
    }
    return stem + ".c2jac.report.json";
}

def write_c2jac_report(path: str, payload: C2JacReport) -> str {
    out = path if path.endswith(".c2jac.report.json") else report_sidecar_path(path);
    parent = os.path.dirname(out);
    if parent {
        os.makedirs(parent, exist_ok=True);
    }
    with open(out, "w", encoding="utf-8") as f {
        json.dump(payload.to_dict(), f, indent=2, sort_keys=True);
        f.write("\n");
    }
    return out;
}

def build_project_report(files: list[C2JacReport]) -> dict {
    total = 0;
    file_rows: list[dict] = [];
    all_q: list[str] = [];
    for r in files {
        total += r.tier_b_count;
        file_rows.append(
            {
                "source": r.source,
                "output": r.output,
                "tier_b_count": r.tier_b_count,
                "quarantined_functions": r.quarantined_functions
            }
        );
        for q in r.quarantined_functions {
            if q not in all_q {
                all_q.append(q);
            }
        }
    }
    return {
        "version": 1,
        "files": file_rows,
        "tier_b_total": total,
        "quarantined_functions": all_q
    };
}

def write_project_report(out_dir: str, files: list[C2JacReport]) -> str {
    path = os.path.join(out_dir, "project.c2jac.report.json");
    os.makedirs(out_dir, exist_ok=True);
    with open(path, "w", encoding="utf-8") as f {
        json.dump(build_project_report(files), f, indent=2, sort_keys=True);
        f.write("\n");
    }
    return path;
}
