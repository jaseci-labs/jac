"""Graph schema extraction (GraphSchemaPass).

The relational shape of a module's graph is derived from what the program
already declares: node/edge/obj archetypes with typed `has` fields, declared
edge endpoints (`edge E: Src --> Tgt`), and connect sites for edges declared
without endpoints. The result lands in interop_manifest.graph_schema and is
JSON-serializable so it can travel with the .jir cache.
"""

import json;
import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURE = (
         "obj Settings {\n"
         "    has theme: str = \"light\",\n"
         "        lang: str = \"en\";\n"
         "}\n"
         "obj Payload {\n"
         "    has data: dict = {},\n"
         "        note: str = \"\";\n"
         "}\n"
         "node Profile {\n"
         "    has username: str = \"\",\n"
         "        followers: int = 0,\n"
         "        settings: (Settings | None) = None,\n"
         "        payload: Payload = Payload(),\n"
         "        best_friend: (Tweet | None) = None;\n"
         "}\n"
         "node Tweet {\n"
         "    has content: str = \"\",\n"
         "        embedding: list[float] = [];\n"
         "}\n"
         "node Comment {\n"
         "    has content: str = \"\";\n"
         "}\n"
         "edge Follow {}\n"
         "edge Post: Profile --> Tweet {}\n"
         "edge Like {\n"
         "    has weight: float = 1.0;\n"
         "}\n"
         "walker add_profile {\n"
         "    can build with `root entry {\n"
         "        p = here ++> Profile(username=\"a\");\n"
         "    }\n"
         "}\n"
         "walker interact {\n"
         "    can act with Profile entry {\n"
         "        t = Profile(username=\"b\") +>:Post():+> Tweet(content=\"hi\");\n"
         "        here +>:Follow():+> Profile(username=\"c\");\n"
         "        here +>:Like(weight=2.0):+> t[0];\n"
         "        c = Comment(content=\"x\");\n"
         "        here ++> c;\n"
         "    }\n"
         "}\n"
     );


def compile_fixture -> dict {
    tmp = tempfile.mkdtemp(prefix="jac_graph_schema_");
    path = os.path.join(tmp, "gsfix.jac");
    with open(path, "w") as f {
        f.write(FIXTURE);
    }
    prog = JacProgram();
    mod = prog.compile(path);
    assert not prog.errors_had , (
        f"fixture must compile clean: {[str(e) for e in prog.errors_had]}"
    );
    return mod.gen.interop_manifest.graph_schema;
}


def field_map(spec: dict) -> dict {
    return {f['name']: f for f in spec['fields']};
}


test "node has-fields classify into storage tiers" {
    gs = compile_fixture();
    assert set(gs['nodes'].keys()) == {'Profile', 'Tweet', 'Comment'};
    prof = field_map(gs['nodes']['Profile']);
    assert prof['username']['tier'] == 'scalar' and prof['username']['type'] == 'str';
    assert prof['followers']['tier'] == 'scalar';
    assert prof['settings']['tier'] == 'obj' and prof['settings']['optional'];
    assert prof['settings']['target'] == 'Settings';
    assert prof['payload']['tier'] == 'obj' and not prof['payload']['optional'];
    assert prof['best_friend']['tier'] == 'node_ref';
    assert prof['best_friend']['target'] == 'Tweet';
    assert prof['best_friend']['optional'];
    tweet = field_map(gs['nodes']['Tweet']);
    assert tweet['embedding']['tier'] == 'scalar_list';
}

test "declared edge endpoints are authoritative and observations corroborate" {
    gs = compile_fixture();
    post = gs['edges']['Post'];
    assert post['declared'] == {'src': 'Profile', 'dst': 'Tweet'};
    assert ['Profile', 'Tweet'] in post['observed'];
}

test "undeclared edges get endpoints observed at connect sites" {
    gs = compile_fixture();
    follow = gs['edges']['Follow'];
    assert follow['declared'] is None;
    assert ['Profile', 'Profile'] in follow['observed'];

    # `t[0]` is not statically resolvable: the destination must stay open,
    # never guessed.
    like = gs['edges']['Like'];
    assert ['Profile', None] in like['observed'];
    lf = field_map(like);
    assert lf['weight']['tier'] == 'scalar';
}

test "bare ++> records against GenericEdge including root sources" {
    gs = compile_fixture();
    gen = gs['edges']['GenericEdge'];
    assert ['Root', 'Profile'] in gen['observed'];
    assert ['Profile', None] in gen['observed'];
}

test "objs report flat_scalar for side-table eligibility" {
    gs = compile_fixture();
    assert gs['objs']['Settings']['flat_scalar'];
    assert not gs['objs']['Payload']['flat_scalar'];
}

test "graph schema is json-serializable for the jir cache" {
    gs = compile_fixture();
    assert json.loads(json.dumps(gs)) == gs;
}
