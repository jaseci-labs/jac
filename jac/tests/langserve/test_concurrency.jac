"""Concurrent requests and shutdown share the language server worker."""

import threading;
import time;
import os;
import sys;
import contextlib;

import from tests.support { JAC_ROOT }

import jaclang.lsp.protocol.types as lspt;

import jaclang;
import from jaclang.lsp.server.engine { JacLangServer }
import from jaclang.lsp.protocol { uris }
import from jaclang.lsp.protocol.server { Workspace }

glob FIXTURE_DIR = os.path.join(
         os.path.dirname(os.path.abspath(__file__)), "fixtures"
     ),
     _active_servers: list[any] = [];

def _clear_jac_modules {
    jac_modules_to_clear = [
        k
        for k in list(sys.modules.keys())
        if not k.startswith(("jaclang", "test", "_"))
            and hasattr(sys.modules.get(k), "__jac_mod__")
    ];
    for mod_name in jac_modules_to_clear {
        sys.modules.pop(mod_name, None);
    }
}

def setup_test {
    _clear_jac_modules();
    _active_servers.clear();
}

def teardown_test {
    for server in _active_servers {
        with contextlib.suppress(Exception) as _s {
            server.shutdown();
        }
        server.program.clear_type_system(clear_hub=True);
    }
    _active_servers.clear();
    _clear_jac_modules();
}

def create_server(workspace_path: str | None = None) -> JacLangServer {
    lsp = JacLangServer();
    workspace_root = workspace_path if workspace_path is not None else FIXTURE_DIR;
    workspace_val = Workspace(root_uri=uris.from_fs_path(workspace_root));
    lsp.lsp._workspace = workspace_val;
    _active_servers.append(lsp);
    return lsp;
}

"""Verify that read operations (hover, outline, semantic tokens) can proceed
    concurrently without deadlock while type checking updates the hub."""
test "concurrent queries during type checking" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = os.path.join(FIXTURE_DIR, "circle.jac");
        circle_uri_maybe = uris.from_fs_path(circle_file);
        assert circle_uri_maybe is not None;
        circle_uri: str = circle_uri_maybe;

        # First, type check the file so hub is populated
        lsp.type_check_file(circle_uri);

        # Now simulate concurrent reads from multiple threads while a write happens
        errors: list[str] = [];
        results: dict[str, bool] = {};
        num_iterations = 10;

        def read_hover {
            try {
                for _ in range(num_iterations) {
                    lsp.get_hover_info(circle_uri, lspt.Position(line=5, character=4));
                }
                results["hover"] = True;
            } except Exception as e {
                errors.append(f"hover: {e}");
            }
        }

        def read_outline {
            try {
                for _ in range(num_iterations) {
                    lsp.get_outline(circle_uri);
                }
                results["outline"] = True;
            } except Exception as e {
                errors.append(f"outline: {e}");
            }
        }

        def read_semantic_tokens {
            try {
                for _ in range(num_iterations) {
                    lsp.get_semantic_tokens(circle_uri);
                }
                results["sem_tokens"] = True;
            } except Exception as e {
                errors.append(f"sem_tokens: {e}");
            }
        }

        def read_definition {
            try {
                for _ in range(num_iterations) {
                    lsp.get_definition(circle_uri, lspt.Position(line=5, character=4));
                }
                results["definition"] = True;
            } except Exception as e {
                errors.append(f"definition: {e}");
            }
        }

        def write_type_check {
            try {
                for _ in range(3) {
                    lsp.type_check_file(circle_uri);
                }
                results["type_check"] = True;
            } except Exception as e {
                errors.append(f"type_check: {e}");
            }
        }

        # Launch readers and writer concurrently
        threads = [
            threading.Thread(target=read_hover),
            threading.Thread(target=read_outline),
            threading.Thread(target=read_semantic_tokens),
            threading.Thread(target=read_definition),
            threading.Thread(target=write_type_check),

        ];
        for t in threads {
            t.start();
        }
        for t in threads {
            t.join(timeout=60);
        }

        assert not errors , f"Concurrent access errors: {errors}";
        assert len(results) == 5 , (f"Not all operations completed: {results}");
    } finally {
        teardown_test();
    }
}

"""Verify shutdown completes without deadlock when the dispatcher is busy."""
test "shutdown under active dispatch" {
    setup_test();
    try {
        lsp = create_server();
        circle_file = os.path.join(FIXTURE_DIR, "circle.jac");
        circle_uri_maybe = uris.from_fs_path(circle_file);
        assert circle_uri_maybe is not None;
        circle_uri: str = circle_uri_maybe;

        # Kick off a type check via the dispatcher
        lsp.type_check_file(circle_uri);

        # Queue more work so dispatcher has something to do
        lsp.type_check(circle_uri);

        # Shutdown should complete without deadlock
        shutdown_done = threading.Event();

        def do_shutdown {
            lsp.shutdown();
            shutdown_done.set();
        }

        t = threading.Thread(target=do_shutdown);
        t.start();
        completed = shutdown_done.`wait(timeout=15);
        assert completed , "Shutdown deadlocked — did not complete within 15s";
        t.join(timeout=5);

        # Remove from active servers since we already shut it down
        _active_servers.remove(lsp);
    } finally {
        teardown_test();
    }
}
