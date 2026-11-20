"""A node space a native app runs in its own process: its modules run
by embedded Node (rt/js.jac). The app carries the crossings between them
in-process, each way through the other side's port: the app's own spaces'
calls to the node space go to the space's (its main module's `port`), and the
space's calls to the app's spaces come back through the app's
(globalThis.__JAC_IN_PROCESS__, which the JS runtime's client reads). A
program the build makes this module part of registers it as it starts."""

import threading;
import from "node:module" { createRequire }
import from "node:vm" { runInThisContext }

"""Start node space `space` from `dir` (its modules, __main.mjs their
start), which this program reaches in-process from then on; its calls to the
program's own spaces, `mine`, come back through `port`."""
def run_node_space(
    space: str,
    dir: str,
    mine: list[str],
    port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
) {
    # Its runtime's client finds the program's spaces here, each a function
    # of (path, JSON text, caller, trusted) giving [status, JSON text].
    carried = runInThisContext("globalThis.__JAC_IN_PROCESS__ ??= {}");
    for sp in mine {
        carried[sp] = lambda (path: str, text: str, caller: str, trusted: bool, *rest: any) -> any {
            (status, reply) = port(path, text.encode("utf-8"), caller, trusted);
            return [status, reply.decode("utf-8")];
        };
    }
    main = createRequire(dir + "/")(dir + "/__main.mjs");
    its_port = main.port;
    # Node runs on the thread that started it, this one: a call of the space
    # from another (a server's call's own thread) is made here for it, by
    # the server's loop, and waited for there.
    home = threading.get_ident();

    def ask(path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
        reply = its_port(path, body.decode("utf-8"), caller, trusted)._jac_wait();
        status: int = reply[0];
        text: str = reply[1];
        return (status, text.encode("utf-8"));
    }

    carry_in_process(
        space,
        lambda (path: str, body: bytes, caller: str, trusted: bool) -> tuple[int, bytes] {
            if threading.get_ident() == home {
                return ask(path, body, caller, trusted);
            }
            if not loop_serving() {
                raise RuntimeError(
                    f"node space '{space}' is called from the thread that started the program, and this program serves nothing for another thread's call to wait on",
                );
            }
            got: list[tuple[int, bytes]] = [];
            failed: list[Exception] = [];
            done = threading.Event();
            on_loop(
                lambda {
                    try {
                        got.append(ask(path, body, caller, trusted));
                    } except Exception as e {
                        failed.append(e);
                    }
                    done.set();
                },
            );
            done.wait();
            if len(failed) > 0 {
                raise failed[0];
            }
            return got[0];
        },
    );
}

glob _node_host: bool = register_space_host(
    "node",
    SpaceHost(
        start=lambda (
            space: str,
            dir: str,
            mine: list[str],
            port: Callable[[str, bytes, str, bool], tuple[int, bytes]],
        ) -> list[Scheduled] {
            run_node_space(space, dir, mine, port);
            return [];
        },
    ),
);
