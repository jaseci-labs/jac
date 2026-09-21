"""Reference healing respects the memory provider's resolution outcome."""
import unittest.mock;

test "foreign references are preserved without deployment flags" {
    import from uuid { uuid4 as _uuid4 }
    import from jaclang.runtime.archetype { EdgeAnchor }
    import from jaclang.runtime.runtime { JacRuntimeInterface, resolve_ref }

    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = _uuid4();

    fake_ctx = unittest.mock.MagicMock();
    fake_ctx.mem.get = unittest.mock.MagicMock(return_value=None);
    fake_ctx.mem.preserve_unresolved_ref = unittest.mock.MagicMock(return_value=True);

    with unittest.mock.patch.object(
        JacRuntimeInterface, "get_context", return_value=fake_ctx
    ) {
        got = resolve_ref(stub, None);
    }

    assert got is None;
    fake_ctx.mem.quarantine_ref.assert_not_called();
}

test "genuinely dangling references are still healed" {
    import from uuid { uuid4 as _uuid4 }
    import from jaclang.runtime.archetype { EdgeAnchor }
    import from jaclang.runtime.runtime { JacRuntimeInterface, resolve_ref }

    stub: any = EdgeAnchor.__new__(EdgeAnchor);
    stub.id = _uuid4();

    fake_ctx = unittest.mock.MagicMock();
    fake_ctx.mem.get = unittest.mock.MagicMock(return_value=None);
    fake_ctx.mem.preserve_unresolved_ref = unittest.mock.MagicMock(return_value=False);

    with unittest.mock.patch.object(
        JacRuntimeInterface, "get_context", return_value=fake_ctx
    ) {
        got = resolve_ref(stub, None);
    }

    assert got is None;
    fake_ctx.mem.quarantine_ref.assert_called_once();
}

test "a deleted foreign row becomes eligible for normal reference healing" {
    import from uuid { uuid4 }
    import from typing { cast }
    import from jaclang.data.store { Store }
    import from jaclang.server.session { Session }
    store = unittest.mock.MagicMock();
    store.load_full.return_value = {};
    session = Session(store=cast(Store, store));
    id = uuid4();
    session._foreign_refs.add(id);
    with unittest.mock.patch.object(session, 'read_barrier') {
        assert session.batch_get([id]) == {};
    }
    assert not session.preserve_unresolved_ref(id);
}
