glob _docs_index: list = [];


def _build_docs_index() -> list {
    index: list = [];
    data_dir = get_data_dir();

    sources: list = [];
    # Reference docs (split by topic)
    ref_dir = os.path.join(data_dir, "reference");
    if os.path.isdir(ref_dir) {
        for fname in sorted(os.listdir(ref_dir)) {
            if fname.endswith(".md") {
                label = fname.replace(".md", "");
                sources.append((label, os.path.join(ref_dir, fname)));
            }
        }
    }
    # Example docs (split by project)
    ex_dir = os.path.join(data_dir, "examples");
    if os.path.isdir(ex_dir) {
        for fname in sorted(os.listdir(ex_dir)) {
            if fname.endswith(".md") {
                label = "example:" + fname.replace(".md", "");
                sources.append((label, os.path.join(ex_dir, fname)));
            }
        }
    }
    if not sources {
        import sys;
        sys.stderr.write(f"[jac_docs] WARNING: no docs found in {data_dir}\n");
    }
    for (source_name, filepath) in sources {
        try {
            with open(filepath, "r", encoding="utf-8") as f {
                content = f.read();
            }
        } except (FileNotFoundError, OSError) {
            continue;
        }
        sections = re.split(r'\n(?=## )', content);
        section_num = 0;
        for section in sections {
            section = section.strip();
            if not section.startswith("## ") {
                continue;
            }
            section_num += 1;
            lines = section.split("\n", 1);
            title = lines[0].replace("## ", "", 1).strip();
            body = lines[1].strip() if len(lines) > 1 else "";
            raw_text = (title + " " + body).lower();
            keyword_set = set(re.findall(r'[a-z0-9_]+', raw_text));
            index.append(
                {
                    "title": title,
                    "source": source_name,
                    "section_num": section_num,
                    "body": body,
                    "keywords": keyword_set
                }
            );
        }
    }
    return index;
}


def _ensure_index() -> list {
    if not _docs_index {
        idx = _build_docs_index();
        # Mutate in place since glob reassignment may not work in impl
        _docs_index.clear();
        _docs_index.extend(idx);
    }
    return _docs_index;
}


impl jac_docs(query: str, max_results: int = 3) -> str {
    tool_status("jac_docs", query);
    if not query or not query.strip() {
        return "Error: query is required. Example: jac_docs('imports') or jac_docs('frontend effects lifecycle').";
    }

    index = _ensure_index();
    if not index {
        return "Error: Jac documentation index is empty — data files not found.";
    }

    query_terms = set(re.findall(r'[a-z0-9_]+', query.lower()));
    if not query_terms {
        return "Error: no searchable terms in query.";
    }

    scored: list = [];
    for section in index {
        title_lower = section["title"].lower();
        title_hits = 0;
        body_hits = 0;
        for term in query_terms {
            if term in title_lower {
                title_hits += 1;
            }
            if term in section["keywords"] {
                body_hits += 1;
            }
        }
        score = (title_hits * 3) + body_hits;
        if score > 0 {
            scored.append({"section": section, "score": score});
        }
    }

    if not scored {
        return f"No matching sections found for: '{query}'. Try broader terms like 'syntax', 'walker', 'frontend', 'imports', 'llm', 'api'.";
    }

    scored.sort(key=lambda x : x["score"], reverse=True);
    top = scored[:max_results];

    parts: list = [];
    matched_titles: list = [];
    for entry in top {
        s = entry["section"];
        parts.append(f"## {s['title']} (from {s['source']})\n\n{s['body']}");
        matched_titles.append(s["title"]);
    }

    titles_str = ", ".join(matched_titles);
    tool_end(f"-> {titles_str}");

    result = "\n\n---\n\n".join(parts);
    (result, _) = truncate_output(result);
    return result;
}
