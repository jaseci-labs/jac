"""A program's native stdlib dependencies live in that program, not in the
process-global self-host program the running compiler keeps for its own
modules."""
import os;
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }


def _pkg_path(rel: str) -> str {
    pkg = os.path.dirname(os.path.abspath(str(jaclang.__file__)));
    return os.path.join(pkg, *rel.split("/"));
}


test "a native stdlib module resolves into the program that imports it" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    assert not cache.is_selfhost(prog);
    sock = _pkg_path("runtime/na_stdlib/socket.jac");
    assert os.path.isfile(sock) , sock;
    assert cache.owns(sock) , "the native stdlib ships inside the jaclang tree";
    assert cache.resolve(sock, prog) is prog , (
        "a checked program's socket import was routed into the self-host hub,"
        " where its type memos would outlive this program's compile closure"
    );
}


test "a compiler module still resolves into the self-host program" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    log_mod = _pkg_path("compiler/driver/log.jac");
    assert os.path.isfile(log_mod) , log_mod;
    assert cache.resolve(log_mod, prog) is cache.program;
    assert cache.resolve(log_mod, prog, force=True) is prog;
}

test "shared construction runtime resolves into its consumer program" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    fragment = _pkg_path("runtime/graph_fragment.jac");
    assert cache.owns(fragment);
    assert cache.resolve(fragment, prog) is prog;
    assert cache.resolve(fragment, cache.program) is cache.program;
}


test "the self-host program keeps its own native stdlib imports" {
    prog = JacProgram();
    cache = prog._get_compiler().selfhost;
    sock = _pkg_path("runtime/na_stdlib/socket.jac");
    assert cache.resolve(sock, cache.program) is cache.program;
}
