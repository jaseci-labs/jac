import ast;
import from pathlib { Path }

def tour_sections -> list[dict[str, any]];

test "Every live deep dive clip resolves to a unique current source anchor" {
    sections = tour_sections();
    assert sections;
    for section in sections {
        for suffix in ["", "2"] {
            if "path" + suffix not in section {
                continue;
            }
            path = section["path" + suffix];
            needle = section["needle" + suffix];
            view = source_file(path);
            assert view is not None , path;
            matches = [
                i
                for (i, line) in enumerate(view.raw_lines)
                if needle in line
            ];
            assert len(matches) == 1 , (path, needle, matches);
            span = source_span(
                path,
                needle,
                section["hl" + suffix],
                section["before" + suffix],
                section["after" + suffix]
            );
            assert span is not None and span.found , (path, needle);
            assert span.hl_from == matches[0] + 1;
            assert span.start <= span.hl_from <= span.hl_to <= view.lines;
            assert needle in span.raw_lines[span.hl_from - span.start];
        }
    }
}

test "A removed source anchor is reported as missing" {
    span = source_span("core/source/files.jac", "missing-source-anchor-for-regression");
    assert span is not None and not span.found;
    assert span.hl_from == 0 and span.hl_to == -1;
    assert source_span("core/source/missing.jac", "anything") is None;
}

test "Mobile showcase clip highlights the actual native component embed" {
    span = source_span(
        "core/site/landing/impl/MobileShowcase.impl.jac",
        "<JacYacMobile embedded={True}/>"
    );
    assert span is not None and span.found;
    assert span.raw_lines[span.hl_from - span.start].strip()
        == "<JacYacMobile embedded={True}/>";
}

impl tour_sections -> list[dict[str, any]] {
    source = Path(_project_root(), "core/site/landing/WaitWuuut.jac").read_text();
    head = source.split("glob GROUPS: ", 1)[1];
    catalog = head.split(" = ", 1)[1].split(",\n     ABSENT:", 1)[0];
    groups = ast.literal_eval(catalog);
    return [section for group in groups for section in group["sections"]];
}
