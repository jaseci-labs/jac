"""Stopping a service never signals a process group the service does not lead.

`stop_service` follows `terminate` with a group signal so a service's own
children (a dev app's vite process) are reaped with it. A child that was not
started in its own session shares the caller's group, and signalling that
group kills the caller and everything beside it: on CI that is the runner
itself, which reports a shutdown signal mid-step and uploads no log. The
group signal is therefore sent only to a group the child leads.
"""
import os;
import signal;
import subprocess;
import sys;
import time;
import unittest.mock;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceEntry,
    ServiceRegistry
}
import from jaclang.scale.runtime.orchestrator.process_manager {
    ServiceProcessManager,
    _owns_group,
    _signal_group
}

def _sleeper(new_session: bool) -> subprocess.Popen {
    return subprocess.Popen(
        [sys.executable, "-c", "import time; time.sleep(60)"],
        start_new_session=new_session
    );
}

def _wait_gone(proc: subprocess.Popen, seconds: float) -> bool {
    deadline = time.monotonic() + seconds;
    while time.monotonic() < deadline {
        if proc.poll() is not None {
            return True;
        }
        time.sleep(0.05);
    }
    return proc.poll() is not None;
}

test "a child in the caller's own group is signalled alone" {
    bystander = _sleeper(False);
    target = _sleeper(False);
    try {
        assert not _owns_group(target.pid);
        _signal_group(target.pid, int(signal.SIGTERM));
        assert _wait_gone(target, 5.0) , "the target itself must still be signalled";
        time.sleep(0.3);
        assert bystander.poll() is None , (
            "a sibling in the caller's group was killed by the group signal"
        );
    } finally {
        for p in (bystander, target) {
            if p.poll() is None {
                p.kill();
            }
            p.`wait();
        }
    }
}

test "a child that leads its own session takes its children down with it" {
    leader = subprocess.Popen(
        [
            sys.executable,
            "-c",
            "import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)']); time.sleep(60)"
        ],
        start_new_session=True
    );
    try {
        time.sleep(0.5);
        assert _owns_group(leader.pid);
        _signal_group(leader.pid, int(signal.SIGTERM));
        assert _wait_gone(leader, 5.0) , "the session leader must be signalled";
        time.sleep(0.5);
        try {
            os.killpg(leader.pid, 0);
            survivors = True;
        } except ProcessLookupError {
            survivors = False;
        }
        assert not survivors , "the leader's own children were not reaped";
    } finally {
        try {
            os.killpg(leader.pid, int(signal.SIGKILL));
        } except (ProcessLookupError, OSError) {}
        if leader.poll() is None {
            leader.kill();
        }
        leader.`wait();
    }
}

def _as_any(value: any) -> any {
    return value;
}

test "stopping a process the manager did not launch never signals its group" {
    bystander = _sleeper(False);
    try {
        reg = ServiceRegistry();
        reg.register(
            ServiceEntry(name="orders", file="orders.jac", prefix="/api/orders")
        );
        pm = ServiceProcessManager(registry=reg);
        mock_proc = unittest.mock.MagicMock();
        mock_proc.pid = bystander.pid;
        mock_proc.`wait = unittest.mock.MagicMock(return_value=0);
        pm.processes["orders"] = _as_any(mock_proc);
        assert pm.stop_service("orders");
        mock_proc.terminate.assert_called_once();
        time.sleep(0.3);
        assert bystander.poll() is None , (
            "stop_service group-signalled a process it never launched"
        );
    } finally {
        if bystander.poll() is None {
            bystander.kill();
        }
        bystander.`wait();
    }
}
