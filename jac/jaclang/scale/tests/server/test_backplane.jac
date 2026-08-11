"""Cross-pod fan-out for the WebSocket PgBackplane.

Every other connection-manager test drives MemoryBackplane, so the wire
path (publish -> pg NOTIFY -> listener thread -> handler on another
instance) is otherwise only asserted via isinstance. These tests stand up
ONE embedded Postgres and TWO independent PgBackplane instances against it
- pod A and pod B, each with its own store connection - and prove a message
published on A is delivered, byte for byte, to B.
"""

import asyncio;
import from tempfile { mkdtemp }
import from jaclang.runtimelib.pgembed { PgRuntime }
import from jaclang.runtimelib.store { PgStore }
import from jaclang.scale.websocket.backplane { PgBackplane }

glob _holder: dict = {};


def _store -> (PgStore | None) {
    try {
        if 'rt' not in _holder {
            _holder['rt'] = PgRuntime(data_dir=mkdtemp(prefix='jacbp_') + '/data');
        }
        store = PgStore(conninfo=_holder['rt'].ensure());
        store.ensure_schema({});
        return store;
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    }
}


async def _pods -> (tuple | None) {
    sa = _store();
    if sa is None {
        return None;
    }
    sb = _store();
    a = PgBackplane();
    b = PgBackplane();
    a._store = sa;
    b._store = sb;
    a._loop = asyncio.get_running_loop();
    b._loop = asyncio.get_running_loop();
    return (a, b, sa, sb);
}


test "message published on pod A reaches a subscriber on pod B" {
    async def scenario -> (dict | None) {
        pods = await _pods();
        if pods is None {
            return None;
        }
        (a, b, sa, sb) = pods;
        got: list[dict] = [];

        async def handler(channel: str, message: dict) {
            got.append(message);
        }
        await b.subscribe('room-1', handler);
        payload = {'kind': 'chat', 'body': 'hello from pod A', 'n': 7};
        for _i in range(40) {
            if got {
                break;
            }
            await a.publish('room-1', payload);
            await asyncio.sleep(0.25);
        }
        await a.close();
        await b.close();
        sa.close();
        sb.close();
        return got[0] if got else {};
    }
    result = asyncio.run(scenario());
    if result is not None {
        assert result == {'kind': 'chat', 'body': 'hello from pod A', 'n': 7};
    }
}


test "oversized payloads spill through kv and arrive intact" {
    async def scenario -> (dict | None) {
        pods = await _pods();
        if pods is None {
            return None;
        }
        (a, b, sa, sb) = pods;
        got: list[dict] = [];

        async def handler(channel: str, message: dict) {
            got.append(message);
        }
        await b.subscribe('room-big', handler);
        payload = {'kind': 'blob', 'body': 'x' * 20000};
        for _i in range(40) {
            if got {
                break;
            }
            await a.publish('room-big', payload);
            await asyncio.sleep(0.25);
        }
        await a.close();
        await b.close();
        sa.close();
        sb.close();
        return got[0] if got else {};
    }
    result = asyncio.run(scenario());
    if result is not None {
        assert result.get('kind') == 'blob';
        assert len(result.get('body', '')) == 20000;
    }
}


test "publishing pod delivers exactly one copy to its own subscriber (#8000 f2)" {
    # publish() used to dispatch locally AND ride pg_notify, which Postgres
    # self-delivers, so the origin pod dispatched every broadcast twice.
    async def scenario -> (int | None) {
        pods = await _pods();
        if pods is None {
            return None;
        }
        (a, b, sa, sb) = pods;
        got_a: list[dict] = [];
        got_b: list[dict] = [];

        async def handler_a(channel: str, message: dict) {
            got_a.append(message);
        }
        async def handler_b(channel: str, message: dict) {
            got_b.append(message);
        }
        await a.subscribe('room-self', handler_a);
        await b.subscribe('room-self', handler_b);
        await a.publish('room-self', {'n': 1});
        deadline = 40;
        while deadline > 0 and (not got_a or not got_b) {
            await asyncio.sleep(0.25);
            deadline -= 1;
        }
        # Allow any straggler duplicate to surface before counting.
        await asyncio.sleep(0.5);
        await a.close();
        await b.close();
        sa.close();
        sb.close();
        assert len(got_b) == 1 , f"pod B expected 1 copy, got {len(got_b)}";
        return len(got_a);
    }
    copies = asyncio.run(scenario());
    if copies is not None {
        assert copies == 1 , f"publishing pod expected exactly 1 copy, got {copies}";
    }
}


test "oversized publish from inside an open store transaction is delivered (#8000 f2)" {
    # The kv spill used to ride the main connection, so a publish issued while
    # that connection had an open transaction wrote an uncommitted row the
    # receiver could not see. The spill now rides the side connection.
    async def scenario -> (dict | None) {
        pods = await _pods();
        if pods is None {
            return None;
        }
        (a, b, sa, sb) = pods;
        got: list[dict] = [];

        async def handler(channel: str, message: dict) {
            got.append(message);
        }
        await b.subscribe('room-txn', handler);
        payload = {'kind': 'txnblob', 'body': 'y' * 20000};
        sa.begin();
        try {
            await a.publish('room-txn', payload);
            deadline = 40;
            while deadline > 0 and not got {
                await asyncio.sleep(0.25);
                deadline -= 1;
            }
        } finally {
            sa.rollback();
        }
        await a.close();
        await b.close();
        sa.close();
        sb.close();
        return got[0] if got else {};
    }
    result = asyncio.run(scenario());
    if result is not None {
        assert result.get('kind') == 'txnblob' , 'spill row must commit out-of-band';
        assert len(result.get('body', '')) == 20000;
    }
}
