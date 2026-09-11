"""Boundary classes and codecs must resolve types in their declaring modules."""

import os;
import re;
import subprocess;
import from tempfile { TemporaryDirectory }
import from tests.support { JAC_ROOT }
import from jaclang.client.bun_installer { get_bun }
import from jaclang.compiler.driver.program { JacProgram }

test "JavaScript boundary types preserve provider scopes and aliases" {
    path = os.path.join(
        JAC_ROOT,
        "jaclang",
        "scale",
        "tests",
        "fixtures",
        "typed_boundary",
        "browser.jac"
    );
    prog = JacProgram();
    mod = prog.compile(path);
    assert not prog.errors_had , str(prog.errors_had);
    js = mod.gen.js;
    bun = get_bun();
    if bun is None {
        testskip("Bun is required to execute generated JavaScript");
    }
    # Run the emitted codecs with only the HTTP transport replaced.
    js = re.sub(r"import[^;]+;", "", js);
    harness = """
async function __jacCallFunction(name, args, options) {
    return {meta: {owner: options.route.includes('other') ? 'other' : 'scoring'}};
}
const first = await fetch_score();
const second = await other_score();
function check(value, message) { if (!value) throw new Error(message); }
check(ScoredPayload !== OtherPayload, 'provider payload classes collapsed');
check(Meta !== OtherMeta, 'provider nested classes collapsed');
check(first instanceof ScoredPayload, 'first provider returned wrong class');
check(second instanceof OtherPayload, 'second provider returned wrong class');
check(first.meta instanceof Meta, 'first nested type used wrong scope');
check(second.meta instanceof OtherMeta, 'second nested type used wrong scope');
check(first.meta.owner === 'scoring' && second.meta.owner === 'other', 'field loss');
const left = first.__to_wire();
const right = second.__to_wire();
check(left._jac_type_id !== right._jac_type_id, 'wire identities collapsed');
check(left.meta._jac_type_id !== right.meta._jac_type_id, 'nested identities collapsed');
""";
    with TemporaryDirectory() as tmp {
        script = os.path.join(tmp, "boundary.mjs");
        with open(script, "w") as f {
            f.write(js + harness);
        }
        result = subprocess.run(
            [bun, script], capture_output=True, text=True, timeout=30
        );
        assert result.returncode == 0 , result.stdout + result.stderr;
    }
}
