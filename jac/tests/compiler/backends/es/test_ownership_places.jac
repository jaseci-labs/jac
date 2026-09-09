import os;
import subprocess;
import from tests.support { TESTS_DIR }
import from tests.compiler.backends.es.codegen_helpers { compile_fixture_to_js }
import from jaclang.client.bun_installer { get_bun }

test "take and swap preserve place semantics in JavaScript" {
    js = compile_fixture_to_js(
        os.path.join(
            TESTS_DIR, "compiler", "backends", "es", "fixtures", "ownership_places.jac"
        )
    );
    runtime = get_bun();
    assert runtime is not None , "the JavaScript runtime is required for this test";
    ran = subprocess.run(
        [
            runtime,
            "--eval",
            js + "\nconsole.log(JSON.stringify([exchange(), field_places()]));\n"
        ],
        capture_output=True,
        text=True,
        timeout=30
    );
    assert ran.returncode == 0 , ran.stderr;
    assert ran.stdout.strip() == "[[2,null,1],[2,null,1,null,3,1,2,1]]" , ran.stdout;
}
