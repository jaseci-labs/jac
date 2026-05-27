"""Tests for the compiler-backed CodeIntelligence facade.

Exercises name lookup, cross-module def/use chains, OSP graph queries,
diagnostics, and typed context slices against a small fixture project
written into a temp directory (outside the jaclang package, so the
compiler routes it to a normal program rather than the internal one).
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.code_intel { CodeIntelligence }

# Fixture project source. Docstring lines use single-quoted Jac strings so
# the embedded triple-quotes need no escaping.
glob _MODEL = "\n".join(
         [
             '"""Domain model for the fixture project."""',
             "",
             '"""A person in the system."""',
             "node User {",
             "    has name: str;",
             "    has age: int = 0;",
             "}",
             "",
             '"""A piece of content authored by a user."""',
             "node Post {",
             "    has title: str;",
             '    has body: str = "";',
             "}",
             "",
             '"""Authorship relationship."""',
             "edge Wrote {}"
         ]
     ),
     _WALKERS = "\n".join(
         [
             '"""Walkers that traverse the domain model."""',
             "",
             "import from model { User, Post }",
             "",
             '"""Build a new user node."""',
             "def make_user(name: str) -> User {",
             "    return User(name=name);",
             "}",
             "",
             '"""Visits users and prints their names."""',
             "walker Crawler {",
             "    can scan with User entry {",
             "        print(here.name);",
             "    }",
             "}"
         ]
     );


"""Create a fresh temp project and return its directory."""
def make_project -> str {
    proj = tempfile.mkdtemp(prefix="ci_proj_");
    (Path(proj) / "model.jac").write_text(_MODEL);
    (Path(proj) / "walkers.jac").write_text(_WALKERS);
    return proj;
}


"""A freshly loaded CodeIntelligence over a fresh fixture project."""
def fresh -> CodeIntelligence {
    ci = CodeIntelligence(proj_dir=make_project());
    ci.load();
    return ci;
}


test "discovers project files" {
    ci = fresh();
    names = sorted([os.path.basename(f) for f in ci.files()]);
    assert names == ["model.jac", "walkers.jac"] , names;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "lookup resolves an archetype by name" {
    ci = fresh();
    hits = ci.lookup("User");
    assert len(hits) == 1 , hits;
    user = hits[0];
    assert user.kind == "node" , user.kind;
    assert os.path.basename(user.file) == "model.jac";
    assert "name: str" in user.fields , user.fields;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "definition returns the declaration site" {
    ci = fresh();
    post = ci.definition("Post");
    assert post is not None;
    assert post.kind == "node";
    assert post.line > 0;
    assert "A piece of content" in post.doc , post.doc;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "references span definition and cross-module uses" {
    ci = fresh();
    refs = ci.references("User");
    files = {os.path.basename(r.file) for r in refs};
    assert "model.jac" in files , files;
    assert "walkers.jac" in files , files;
    roles = {r.role for r in refs};
    assert "def" in roles , roles;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "walkers_visiting finds entry points by node type" {
    ci = fresh();
    eps = ci.walkers_visiting("User");
    walkers = {ep.walker_name for ep in eps};
    assert "Crawler" in walkers , walkers;
    crawler_ep = [
        ep
        for ep in eps
        if ep.walker_name == "Crawler"
    ][0];
    assert crawler_ep.node_type == "User" , crawler_ep.node_type;
    assert crawler_ep.event == "entry" , crawler_ep.event;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "nodes_visited_by lists a walker's targets" {
    ci = fresh();
    eps = ci.nodes_visited_by("Crawler");
    assert len(eps) == 1 , eps;
    assert eps[0].node_type == "User";
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "archetypes filters by kind" {
    ci = fresh();
    nodes = {a.name for a in ci.archetypes("node")};
    assert nodes == {"User", "Post"} , nodes;
    walkers = {a.name for a in ci.archetypes("walker")};
    assert walkers == {"Crawler"} , walkers;
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "clean project reports no error diagnostics" {
    ci = fresh();
    errors = [
        d
        for d in ci.diagnostics()
        if d.severity == "error"
    ];
    assert errors == [] , [e.render() for e in errors];
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "slice_for packs a typed neighbourhood" {
    ci = fresh();
    sl = ci.slice_for("Crawler");
    assert sl.target is not None;
    assert sl.target.name == "Crawler";
    assert "Crawler" in sl.render();
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "refresh picks up a newly written symbol" {
    ci = fresh();
    assert ci.definition("Comment") is None;
    extra = os.path.join(ci.proj_dir, "extra.jac");
    Path(extra).write_text("node Comment { has text: str; }\n");
    ci.refresh(extra);
    found = ci.definition("Comment");
    assert found is not None , "refresh did not pick up the new node";
    assert found.kind == "node";
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "refresh_and_diff surfaces breakage an edit causes in a dependent" {
    ci = fresh();
    model_path = os.path.join(ci.proj_dir, "model.jac");
    # Rename `node User` -> `node Account`; walkers.jac still imports and uses
    # `User`, so the edit to model.jac breaks the dependent module.
    Path(model_path).write_text(_MODEL.replace("node User", "node Account"));
    diags = ci.refresh_and_diff(model_path);
    hit_files = {os.path.basename(d.file) for d in diags};
    assert "walkers.jac" in hit_files , [d.render() for d in diags];
    shutil.rmtree(ci.proj_dir, ignore_errors=True);
}


test "structural index is persisted and served across loads without re-parsing" {
    proj = make_project();
    # First cold load over a fresh project: both modules are parsed and their
    # flat structural index is written to the project cache.
    ci1 = CodeIntelligence(proj_dir=proj, structural=True);
    ci1.load();
    assert {a.name for a in ci1.archetypes("node")} == {"User", "Post"};

    # A fresh facade over the same unchanged project must serve every module
    # from the on-disk index -- zero re-parses -- yet answer identically.
    events: list[dict] = [];
    ci2 = CodeIntelligence(proj_dir=proj, structural=True);
    ci2.on_event = lambda ev: dict : events.append(ev);
    ci2.load();
    assert len(events) == 1 , events;
    ev = events[0];
    assert ev["recompiled"] == 0 , ev;
    assert ev["cached"] == 2 , ev;
    assert {a.name for a in ci2.archetypes("node")} == {"User", "Post"};
    assert "Crawler" in {e.walker_name for e in ci2.walkers_visiting("User")};
    shutil.rmtree(proj, ignore_errors=True);
}


test "structural index cache invalidates only the edited module" {
    proj = make_project();
    # Warm the cache for both modules.
    CodeIntelligence(proj_dir=proj, structural=True).load();

    # Edit model.jac; walkers.jac is untouched. The content hash of model.jac
    # changes so its index is rebuilt, while walkers.jac is served from cache.
    model_path = os.path.join(proj, "model.jac");
    Path(model_path).write_text(_MODEL + "\nnode Tag { has label: str; }\n");

    events: list[dict] = [];
    ci = CodeIntelligence(proj_dir=proj, structural=True);
    ci.on_event = lambda ev: dict : events.append(ev);
    ci.load();
    ev = events[0];
    assert ev["recompiled"] == 1 , ev;
    assert ev["cached"] == 1 , ev;
    assert {a.name for a in ci.archetypes("node")} == {"User", "Post", "Tag"};
    shutil.rmtree(proj, ignore_errors=True);
}


test "lazy mode serves the map from cache and type-checks only on demand" {
    proj = make_project();
    # Warm the structural cache so the lazy load below is a pure cache hit.
    CodeIntelligence(proj_dir=proj, lazy=True).load();

    events: list[dict] = [];
    ci = CodeIntelligence(proj_dir=proj, lazy=True);
    ci.on_event = lambda ev: dict : events.append(ev);
    ci.load();
    # The lazy load is structural: both modules come from the on-disk index and
    # nothing is parsed or type-checked.
    assert events[-1]["op"] == "load" , events;
    assert events[-1]["cached"] == 2 , events;
    assert events[-1]["recompiled"] == 0 , events;
    # A structural query stays cheap -- no full pipeline runs.
    assert {a.name for a in ci.archetypes("node")} == {"User", "Post"};
    assert all([e["op"] != "typecheck" for e in events]) , events;

    # A type query (cross-module def/use chains) triggers the full upgrade once,
    # and then resolves correctly across modules.
    refs = ci.references("User");
    assert any([e["op"] == "typecheck" for e in events]) , events;
    files = {os.path.basename(r.file) for r in refs};
    assert "model.jac" in files and "walkers.jac" in files , files;
    shutil.rmtree(proj, ignore_errors=True);
}


test "refresh_and_diff does not misattribute a dependent's pre-existing error" {
    proj = tempfile.mkdtemp(prefix="ci_proj_");
    model_path = os.path.join(proj, "model.jac");
    walkers_path = os.path.join(proj, "walkers.jac");
    Path(model_path).write_text(_MODEL);
    # walkers.jac is broken from the start: `bad` returns a str from `-> int`.
    Path(walkers_path).write_text(
        _WALKERS + "\n\ndef bad() -> int { return \"not an int\"; }\n"
    );
    ci = CodeIntelligence(proj_dir=proj);
    ci.load();
    pre = {os.path.basename(d.file) for d in ci.diagnostics()};
    assert "walkers.jac" in pre , pre;
    # A harmless edit to model.jac must not re-surface walkers.jac's old error.
    Path(model_path).write_text(_MODEL + "\nnode Tag { has label: str; }\n");
    diags = ci.refresh_and_diff(model_path);
    hit_files = {os.path.basename(d.file) for d in diags};
    assert "walkers.jac" not in hit_files , [d.render() for d in diags];
    shutil.rmtree(proj, ignore_errors=True);
}
