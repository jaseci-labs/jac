"""Embedded-postgres initdb provision must survive transient failures.

Two concurrent cold caches running initdb against one disk blew the
hardcoded 120s timeout, and the partial cluster left behind poisoned
every later attempt (initdb refuses non-empty data dirs). Provision now
retries once after wiping the data dir, with the timeout tunable via
JAC_PG_INITDB_TIMEOUT.
"""

import os;
import subprocess;
import tempfile;
import from unittest.mock { patch }
import from jaclang.data.pgembed { PgRuntime }


test "initdb timeout wipes partial cluster and retries successfully" {
    data_dir = tempfile.mkdtemp(prefix="jac_initdb_retry_");
    rt = PgRuntime(data_dir=data_dir, superuser='jac');
    calls: list = [];

    def fake_run(args: list, **kw: any) -> any {
        calls.append(args);
        if len(calls) == 1 {
            raise subprocess.TimeoutExpired(cmd='initdb', timeout=0.01);
        }
        return type("R", (), {"returncode": 0, "stderr": ""})();
    }

    with patch("jaclang.data.pgembed.subprocess.run", side_effect=fake_run) {
        rt._initdb_if_needed(bin_dir="/nonexistent/bin");
    }
    assert len(calls) == 2 , f"expected one retry, got {len(calls)} attempts";
}

test "initdb failure exhausts retries and leaves a clean slate" {
    data_dir = tempfile.mkdtemp(prefix="jac_initdb_fail_");
    rt = PgRuntime(data_dir=data_dir, superuser='jac');
    calls: list = [];

    def fake_run(args: list, **kw: any) -> any {
        calls.append(args);
        return type("R", (), {"returncode": 1, "stderr": "boom"})();
    }

    failed = False;
    try {
        with patch("jaclang.data.pgembed.subprocess.run", side_effect=fake_run) {
            rt._initdb_if_needed(bin_dir="/nonexistent/bin");
        }
    } except Exception {
        failed = True;
    }
    assert len(calls) == 2 , f"expected exactly two attempts, got {len(calls)}";
    assert failed , "exhausted initdb must raise";
    assert not os.path.exists(data_dir) or os.listdir(data_dir) == [] , "partial cluster must not survive a failed provision";
}

test "initdb retry never wipes a cluster another process completed" {
    data_dir = tempfile.mkdtemp(prefix="jac_initdb_race_");
    rt = PgRuntime(data_dir=data_dir, superuser='jac');
    calls: list = [];

    def fake_run(args: list, **kw: any) -> any {
        calls.append(args);
        if len(calls) == 1 {
            with open(os.path.join(data_dir, 'PG_VERSION'), 'w') as f {
                f.write('16');
            }
            return type("R", (), {"returncode": 1, "stderr": "boom"})();
        }
        return type("R", (), {"returncode": 0, "stderr": ""})();
    }

    with patch("jaclang.data.pgembed.subprocess.run", side_effect=fake_run) {
        rt._initdb_if_needed(bin_dir="/nonexistent/bin");
    }
    assert len(calls) == 1 , f"provision must not retry once the cluster is complete, got {len(
        calls
    )} calls";
    assert os.path.isfile(os.path.join(data_dir, 'PG_VERSION')) , "completed cluster marker must survive the failed attempt";
    assert os.listdir(data_dir) == ['PG_VERSION'] , "no wipe may touch a completed data dir";
}
