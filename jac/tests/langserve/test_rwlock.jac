"""Tests for ReadWriteLock concurrency correctness."""

import threading;
import time;
import os;
import sys;
import contextlib;

import from pathlib { Path }

import lsprotocol.types as lspt;

import jaclang;
import from jaclang.langserve.rwlock { ReadWriteLock }
import from jaclang.langserve.engine { JacLangServer }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.workspace { Workspace }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures"),
     _active_servers: list = [];

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
        server.clear_type_system(clear_hub=True);
    }
    _active_servers.clear();
    _clear_jac_modules();
}

def create_server(workspace_path: str | None = None) -> JacLangServer {
    lsp = JacLangServer();
    workspace_root = workspace_path if workspace_path is not None else FIXTURE_DIR;
    workspace_val = Workspace(workspace_root, lsp);
    lsp.lsp._workspace = workspace_val;
    _active_servers.append(lsp);
    return lsp;
}

test "rwlock concurrent readers and exclusive writer" {
    """Verify multiple readers run concurrently, writers get exclusive access,
    and writer priority prevents reader starvation of writers."""
    setup_test();
    try {
        lock = ReadWriteLock();
        results: list[str] = [];
        barrier = threading.Barrier(3);  # Sync 3 reader threads

        def reader_work(reader_id: int) -> None {
            with lock.read_lock() {
                # All readers should be able to enter concurrently
                barrier.wait(timeout=5);  # Would deadlock if readers blocked each other
                results.append(f"reader_{reader_id}_in");
                time.sleep(0.05);  # Hold lock briefly
                results.append(f"reader_{reader_id}_out");
            }
        }

        # Phase 1: Concurrent readers don't block each other
        threads = [threading.Thread(target=reader_work, args=[i]) for i in range(3)];
        for t in threads {
            t.start();
        }
        for t in threads {
            t.join(timeout=10);
        }
        # All 3 readers entered the lock (barrier would timeout otherwise)
        assert len(results) == 6 , f"Expected 6 results, got {len(results)}: {results}";

        # Phase 2: Writer excludes readers
        results.clear();
        writer_entered = threading.Event();
        writer_done = threading.Event();
        reader_entered = threading.Event();

        def writer_work -> None {
            with lock.write_lock() {
                writer_entered.set();
                results.append("writer_in");
                time.sleep(0.15);  # Hold write lock
                results.append("writer_out");
            }
            writer_done.set();
        }

        def reader_after_writer -> None {
            # Wait until writer has started, then try to read
            writer_entered.wait(timeout=5);
            time.sleep(0.02);  # Small delay to ensure writer is holding lock
            with lock.read_lock() {
                reader_entered.set();
                results.append("reader_after");
            }
        }

        wt = threading.Thread(target=writer_work);
        rt = threading.Thread(target=reader_after_writer);
        wt.start();
        rt.start();
        wt.join(timeout=10);
        rt.join(timeout=10);

        # Writer must complete before reader enters
        assert results.index("writer_out") < results.index("reader_after") , (
            f"Writer should finish before reader enters: {results}"
        );

        # Phase 3: Writer priority — waiting writer blocks new readers
        results.clear();
        hold_read = threading.Event();
        writer_waiting = threading.Event();

        def holding_reader -> None {
            with lock.read_lock() {
                results.append("hold_reader_in");
                hold_read.wait(timeout=5);  # Hold read lock until signaled
                results.append("hold_reader_out");
            }
        }

        def priority_writer -> None {
            writer_waiting.set();
            with lock.write_lock() {
                results.append("priority_writer");
            }
        }

        def late_reader -> None {
            writer_waiting.wait(timeout=5);
            time.sleep(0.05);  # Ensure writer is queued first
            with lock.read_lock() {
                results.append("late_reader");
            }
        }

        t1 = threading.Thread(target=holding_reader);
        t1.start();
        time.sleep(0.05);  # Let reader acquire lock

        t2 = threading.Thread(target=priority_writer);
        t3 = threading.Thread(target=late_reader);
        t2.start();
        t3.start();
        time.sleep(0.1);  # Let writer and late reader queue up

        hold_read.set();  # Release the holding reader
        t1.join(timeout=10);
        t2.join(timeout=10);
        t3.join(timeout=10);

        # Writer should run before late reader (writer priority)
        assert results.index("priority_writer") < results.index("late_reader") , (
            f"Writer should have priority over late reader: {results}"
        );
    } finally {
        teardown_test();
    }
}

test "concurrent queries during type checking" {
    """Verify that read operations (hover, outline, semantic tokens) can proceed
    concurrently without deadlock while type checking updates the hub."""
    setup_test();
    try {
        lsp = create_server();
        circle_file = os.path.join(FIXTURE_DIR, "circle.jac");
        circle_uri = uris.from_fs_path(circle_file);

        # First, type check the file so hub is populated
        lsp.type_check_file(circle_uri);

        # Now simulate concurrent reads from multiple threads while a write happens
        errors: list[str] = [];
        results: dict[str, bool] = {};
        num_iterations = 10;

        def read_hover -> None {
            try {
                for _ in range(num_iterations) {
                    lsp.get_hover_info(circle_uri, lspt.Position(line=5, character=4));
                }
                results["hover"] = True;
            } except Exception as e {
                errors.append(f"hover: {e}");
            }
        }

        def read_outline -> None {
            try {
                for _ in range(num_iterations) {
                    lsp.get_outline(circle_uri);
                }
                results["outline"] = True;
            } except Exception as e {
                errors.append(f"outline: {e}");
            }
        }

        def read_semantic_tokens -> None {
            try {
                for _ in range(num_iterations) {
                    lsp.get_semantic_tokens(circle_uri);
                }
                results["sem_tokens"] = True;
            } except Exception as e {
                errors.append(f"sem_tokens: {e}");
            }
        }

        def read_definition -> None {
            try {
                for _ in range(num_iterations) {
                    lsp.get_definition(circle_uri, lspt.Position(line=5, character=4));
                }
                results["definition"] = True;
            } except Exception as e {
                errors.append(f"definition: {e}");
            }
        }

        def write_type_check -> None {
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

test "shutdown under active dispatch" {
    """Verify shutdown completes without deadlock when the dispatcher is busy."""
    setup_test();
    try {
        lsp = create_server();
        circle_file = os.path.join(FIXTURE_DIR, "circle.jac");
        circle_uri = uris.from_fs_path(circle_file);

        # Kick off a type check via the dispatcher
        lsp.type_check_file(circle_uri);

        # Queue more work so dispatcher has something to do
        lsp._do_type_check(circle_uri);

        # Shutdown should complete without deadlock
        shutdown_done = threading.Event();

        def do_shutdown -> None {
            lsp.shutdown();
            shutdown_done.set();
        }

        t = threading.Thread(target=do_shutdown);
        t.start();
        completed = shutdown_done.wait(timeout=15);
        assert completed , "Shutdown deadlocked — did not complete within 15s";
        t.join(timeout=5);

        # Remove from active servers since we already shut it down
        _active_servers.remove(lsp);
    } finally {
        teardown_test();
    }
}
