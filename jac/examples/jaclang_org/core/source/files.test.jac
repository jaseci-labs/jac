import ast;
import re;
import from pathlib { Path }

def tour_sections -> list[dict] {
    source = Path(_project_root(), "core/site/landing/WaitWuuut.jac").read_text();
    catalog = source.split("glob GROUPS: list[dict] = ", 1)[1].split(
        ",\n     ABSENT:", 1
    )[0];
    groups = ast.literal_eval(catalog);
    return [section for group in groups for section in group["sections"]];
}

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

test "Landing page examples are served from their current source files" {
    source = Path(_project_root(), "core/site/landing/Showcase.jac").read_text();
    names = re.findall(r'sample_lines\("([a-z_]+)"\)', source);
    assert names;
    samples = {view.path: view for view in example_sources()};
    for name in names {
        path = "core/site/examples/" + name + ".jac";
        assert path in samples , path;
        assert samples[path].raw_lines
            == Path(_project_root(), path).read_text().split("\n");
        assert 'file="' + path + '"' in source , path;
    }
}

test "Mobile showcase clip highlights the actual native component embed" {
    span = source_span(
        "core/site/landing/MobileShowcase.jac", "<JacYacMobile embedded={True}/>"
    );
    assert span is not None and span.found;
    assert span.raw_lines[span.hl_from - span.start].strip()
        == "<JacYacMobile embedded={True}/>";
}

test "Illustrative ownership clip produces the advertised compiler diagnostics" {
    import subprocess;
    import from tempfile { TemporaryDirectory }
    source = Path(_project_root(), "core/site/landing/Showcase.jac").read_text();
    literal = source.split("glob _NATIVE_LINES: list[str] = ", 1)[1].split(
        "\n\ndef:pub ShowcasePanel", 1
    )[0].strip().removesuffix(
        ";"
    );
    lines = ast.literal_eval(literal);
    with TemporaryDirectory() as folder {
        path = Path(folder, "ownership_clip.jac");
        path.write_text("\n".join(lines) + "\n");
        result = subprocess.run(
            ["jac", "check", str(path)], capture_output=True, text=True, timeout=60
        );
        assert result.returncode != 0;
        output = result.stdout + result.stderr;
        assert "error[E1301]" in output , output;
        assert "error[E1303]" in output , output;
    }
}
