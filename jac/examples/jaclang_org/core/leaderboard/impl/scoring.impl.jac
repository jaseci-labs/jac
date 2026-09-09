impl analyze(files: dict[str, str]) -> RepoAnalysis {
    an = RepoAnalysis();
    for rel in files.keys() {
        low = rel.lower();
        text = files[rel];
        if low.endswith(".jac") {
            an.jac_files += 1;
            an.jac_lines += len(text.split("\n"));
            if re.search(
                r"(?m)^\s*walker\s+\w|^\s*node\s+\w|^\s*edge\s+\w|\bspawn\b|\+\+>", text
            ) {
                an.features.osp = True;
            }
            if "by llm" in text {
                an.features.ai = True;
            }
            if re.search(r"(?m)\bJsx(Element|Page)\b|^\s*return\s+<[A-Za-z]", text) {
                an.features.cl = True;
            }
            if low.endswith(".sv.jac")
                or re.search(
                    r"(?m)^\s*sv\s*\{|^\s*sv\s+import\b|walker:pub|def:pub", text
                ) {
                an.features.sv = True;
            }
            if low.endswith(".na.jac")
                or re.search(r"(?m)^\s*na\s*\{|^\s*na\s+import\b", text) {
                an.features.na = True;
            }
            if re.search(r"(?m)^\s*test\s+\w|^\s*test\s*[\{\"]", text) {
                an.features.tests = True;
            }
        } elif low == "readme.md" {
            an.readme = True;
            an.readme_lines = len(text.split("\n"));
        } elif low.endswith("jac.toml") {
            an.toml = True;
        } elif low == "license" or low == "license.md" or low == "license.txt" {
            an.license = True;
        } elif low.startswith(".github/workflows/") {
            an.ci = True;
        } elif low.startswith("docs/") {
            an.docs = True;
        }
    }
    return an;
}

impl RepoAnalysis.jac_pct -> int {
    denom = self.jac_bytes + self.other_code_bytes;
    if denom <= 0 {
        return 100 if self.jac_files > 0 else 0;
    }
    return int(round(100.0 * self.jac_bytes / denom));
}

impl belt_for(total: int) -> str {
    if total >= 80 {
        return "black";
    }
    if total >= 65 {
        return "brown";
    }
    if total >= 50 {
        return "green";
    }
    if total >= 35 {
        return "orange";
    }
    if total >= 20 {
        return "yellow";
    }
    return "white";
}

impl score(meta: RepoMeta, an: RepoAnalysis) -> ScoreBreakdown {
    parts: list[ScorePart] = [];

    def part(category: str, label: str, pts: float, mx: float, note: str) -> float {
        parts.append(
            ScorePart(
                category=category, label=label, pts=round(pts, 1), max=mx, note=note
            )
        );
        return pts;
    }

    substance = part(
        "substance",
        "Jac volume",
        min(18.0, (math.log10(an.jac_lines + 1) / math.log10(50000.0)) * 18.0),
        18.0,
        str(an.jac_lines)
            + " lines across "
            + str(an.jac_files)
            + " files (log scale, full at 50k)"
    );
    pct = an.jac_pct();
    substance += part(
        "substance",
        "Jac share of the code",
        (pct / 100.0) * 12.0,
        12.0,
        str(pct)
            + "% of the repo's programming-language bytes are Jac (markup, styles, shell, and config excluded)"
    );

    breadth = part(
        "breadth",
        "Object-spatial programming",
        7.0 if an.features.osp else 0.0,
        7.0,
        "walkers, nodes, edges, or spawns in the source"
    );
    breadth += part(
        "breadth",
        "AI integration",
        6.0 if an.features.ai else 0.0,
        6.0,
        "delegates work with `by llm`"
    );
    breadth += part(
        "breadth",
        "Client codespace",
        5.0 if an.features.cl else 0.0,
        5.0,
        "JSX components (JsxElement / JsxPage)"
    );
    breadth += part(
        "breadth",
        "Server codespace",
        4.0 if an.features.sv else 0.0,
        4.0,
        ".sv.jac files, sv blocks, or :pub endpoints"
    );
    breadth += part(
        "breadth",
        "Native codespace",
        4.0 if an.features.na else 0.0,
        4.0,
        ".na.jac files or na blocks"
    );
    breadth += part(
        "breadth",
        "Tests",
        3.0 if an.features.tests else 0.0,
        3.0,
        "test blocks in the source"
    );
    spaces = (1 if an.features.cl else 0)
        + (1 if an.features.sv else 0)
        + (1 if an.features.na else 0);
    breadth += part(
        "breadth",
        "Multi-codespace bonus",
        3.0 if spaces >= 2 else 0.0,
        3.0,
        "uses " + str(spaces) + " of the cl/sv/na codespaces"
    );
    breadth = min(30.0, breadth);

    craft = part(
        "craft",
        "README",
        (2.0 + min(3.0, an.readme_lines / 60.0 * 3.0)) if an.readme else 0.0,
        5.0,
        (str(an.readme_lines) + " lines (full marks near 60)")
            if an.readme
            else "no README found"
    );
    craft += part(
        "craft", "jac.toml", 4.0 if an.toml else 0.0, 4.0, "packaged as a Jac project"
    );
    craft += part(
        "craft",
        "License",
        3.0 if an.license else 0.0,
        3.0,
        "LICENSE file present" if an.license else "no license file"
    );
    craft += part(
        "craft",
        "CI",
        3.0 if an.ci else 0.0,
        3.0,
        "GitHub Actions workflows" if an.ci else "no .github/workflows"
    );
    craft += part(
        "craft",
        "Docs",
        2.0 if an.docs else 0.0,
        2.0,
        "docs/ directory" if an.docs else "no docs/ directory"
    );
    pushed_days = days_since(meta.pushed_at);
    recency = 0.0;
    if pushed_days <= 30.0 {
        recency = 3.0;
    } elif pushed_days <= 90.0 {
        recency = 2.0;
    } elif pushed_days <= 365.0 {
        recency = 1.0;
    }
    craft += part(
        "craft",
        "Recent upkeep",
        recency,
        3.0,
        "last push " + str(int(pushed_days)) + " days ago"
    );
    craft = min(20.0, craft);

    community = part(
        "community",
        "Stars",
        min(12.0, (math.log10(meta.stars + 1) / math.log10(1000.0)) * 12.0),
        12.0,
        str(meta.stars) + " stars (log scale, full at 1k)"
    );
    community += part(
        "community",
        "Forks",
        min(5.0, (math.log10(meta.forks + 1) / math.log10(200.0)) * 5.0),
        5.0,
        str(meta.forks) + " forks (log scale, full at 200)"
    );
    community += part(
        "community",
        "Topics",
        3.0 if len(meta.topics) > 0 else 0.0,
        3.0,
        (", ".join(meta.topics)) if meta.topics else "no topics set"
    );
    community = min(20.0, community);

    total = int(round(substance + breadth + craft + community));
    return ScoreBreakdown(
        total=total,
        belt=belt_for(total),
        substance=int(round(substance)),
        breadth=int(round(breadth)),
        craft=int(round(craft)),
        community=int(round(community)),
        details=parts
    );
}
