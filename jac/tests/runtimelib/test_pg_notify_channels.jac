"""Channel identity for PgStore LISTEN/NOTIFY (#8046).

notify() and listen() must agree on what a channel *is*. They used to
disagree: listen() ran LISTEN on a sanitized identifier (name lowercased,
every non-identifier character folded to '_') while notify() published the
raw string through pg_notify, so any channel carrying a ':' namespace
separator lost every message, and a listener on 'cache:invalidate' was woken
by the logically distinct 'cache_invalidate'. Both failures were silent.

These tests pin the contract from both sides: a message is delivered to
exactly the listeners that asked for that exact channel name, whatever bytes
it contains, including names Postgres itself cannot carry as a channel.

This suite stands up its OWN embedded cluster (the pattern the scale
backplane and job-store suites use) instead of attaching to the shared one.
Sibling suites in this directory stop the shared server on purpose (`jac db
stop` in test_db_cli), and a NOTIFY is not durable across a restart, so
sharing that lifecycle would make delivery assertions racy.
"""

import atexit;
import shutil;
import time;
import from tempfile { mkdtemp }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store { PgStore }

glob _holder: dict = {},
     _LONG_STEM = 'cache:' + ('x' * 70) + ':';


def _discard_runtime {
    # The cluster belongs to this worker process, so it leaves with it
    # instead of lingering as an orphan server on the machine.
    rt = _holder.pop('rt', None);
    home = _holder.pop('home', None);
    if rt is not None {
        try {
            rt.stop();
        } except Exception { }
    }
    if home is not None {
        shutil.rmtree(home, ignore_errors=True);
    }
}


def _runtime -> any {
    if 'rt' not in _holder {
        home = mkdtemp(prefix='jacnotify_');
        _holder['home'] = home;
        _holder['rt'] = PgRuntime(data_dir=home + '/data');
        atexit.register(_discard_runtime);
    }
    return _holder['rt'];
}


def _pair -> tuple {
    # Publisher and subscriber on separate connections: the same path a
    # second pod takes, and it makes delivery push-driven rather than
    # waiting out the listen loop's idle poll.
    rt = _runtime();
    info = rt.ensure();
    return (
        PgStore(conninfo=info, ensure_cb=rt.ensure),
        PgStore(conninfo=info, ensure_cb=rt.ensure)
    );
}


def _settle {
    # The listen loop parks in select() with the LISTEN already registered;
    # give the thread a moment to reach it before publishing.
    time.sleep(0.5);
}


def _wait_for(box: list, want: int, seconds: float = 10.0) {
    deadline = time.monotonic() + seconds;
    while len(box) < want and time.monotonic() < deadline {
        time.sleep(0.05);
    }
}


test "notify reaches a listener on a channel with a namespace separator" {
    (sub, `pub) = _pair();
    got: list[str] = [];
    try {
        sub.listen('cache:invalidate', lambda (payload: str) { got.append(payload); });
        _settle();
        `pub.notify('cache:invalidate', 'A');
        _wait_for(got, 1);
    } finally {
        sub.close();
        `pub.close();
    }
    assert got == ['A'] , (
        "notify('cache:invalidate') never reached its own listener, got "
        f"{got}: notify and listen disagree on the channel identifier"
    );
}


test "channels that sanitize alike never cross-deliver" {
    # The old sanitizer lowercased too, so 'CACHE:INVALIDATE' collapsed onto
    # the same identifier as the other two.
    (sub, `pub) = _pair();
    colon: list[str] = [];
    plain: list[str] = [];
    upper: list[str] = [];
    try {
        sub.listen(
            'cache:invalidate', lambda (payload: str) { colon.append(payload); }
        );
        sub.listen(
            'cache_invalidate', lambda (payload: str) { plain.append(payload); }
        );
        sub.listen(
            'CACHE:INVALIDATE', lambda (payload: str) { upper.append(payload); }
        );
        _settle();
        `pub.notify('cache:invalidate', 'A');
        `pub.notify('cache_invalidate', 'B');
        _wait_for(colon, 1);
        _wait_for(plain, 1);
        # Let any stray cross-delivery land before counting.
        time.sleep(0.5);
    } finally {
        sub.close();
        `pub.close();
    }
    assert colon == ['A'] , (
        "the 'cache:invalidate' listener saw traffic from a channel that only "
        f"sanitizes to the same identifier: {colon}"
    );
    assert plain == ['B'] , f"expected only 'B' on 'cache_invalidate', got {plain}";
    assert upper == [] , f"'CACHE:INVALIDATE' is a distinct channel but received {upper}";
}


test "channel names past the postgres identifier limit round trip intact" {
    (sub, `pub) = _pair();
    one = _LONG_STEM + 'one';
    two = _LONG_STEM + 'two';
    got_one: list[str] = [];
    got_two: list[str] = [];
    try {
        sub.listen(one, lambda (payload: str) { got_one.append(payload); });
        sub.listen(two, lambda (payload: str) { got_two.append(payload); });
        _settle();
        `pub.notify(two, 'long-two');
        _wait_for(got_two, 1);
        time.sleep(0.5);
    } finally {
        sub.close();
        `pub.close();
    }
    assert got_two == ['long-two'] , (
        f"a channel name of {len(two)} bytes lost its message, got {got_two}:"
        ' over-long names must still map to one stable listen identifier'
    );
    assert got_one == [] , (
        f"two channel names sharing their first 63 bytes cross-delivered: {got_one}"
    );
}


test "a name postgres cannot carry verbatim still routes to one listener" {
    # A NUL byte terminates a string on the wire, so this name can never be a
    # postgres channel; it must still reach its own listener and nobody else.
    (sub, `pub) = _pair();
    one = 'cache:\x00:one';
    two = 'cache:\x00:two';
    got_one: list[str] = [];
    got_two: list[str] = [];
    try {
        sub.listen(one, lambda (payload: str) { got_one.append(payload); });
        sub.listen(two, lambda (payload: str) { got_two.append(payload); });
        _settle();
        `pub.notify(one, 'nul-one');
        _wait_for(got_one, 1);
        time.sleep(0.5);
    } finally {
        sub.close();
        `pub.close();
    }
    assert got_one == ['nul-one'] , (
        f"the unrepresentable channel name lost its message, got {got_one}"
    );
    assert got_two == [] , f"a sibling unrepresentable name cross-delivered: {got_two}";
}


test "unlisten stops delivery and parks the listen thread" {
    (sub, `pub) = _pair();
    got: list[str] = [];
    alive_after: bool = True;
    try {
        sub.listen('cache:invalidate', lambda (payload: str) { got.append(payload); });
        _settle();
        `pub.notify('cache:invalidate', 'first');
        _wait_for(got, 1);
        parked: any = sub._listen_thread;
        sub.unlisten('cache:invalidate');
        # unlisten joins the thread, so it is gone the moment it returns.
        alive_after = parked is not None and parked.is_alive();
        `pub.notify('cache:invalidate', 'second');
        time.sleep(1.0);
    } finally {
        sub.close();
        `pub.close();
    }
    assert got == ['first'] , (
        f"unlisten did not stop delivery on the channel, got {got}"
    );
    assert not alive_after , (
        'the listen thread outlived its last subscriber: a background thread'
        ' that keeps polling can reconnect after the store is done with it'
    );
}
