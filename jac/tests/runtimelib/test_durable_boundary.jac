"""A child session shares its parent's durable boundary, not other requests'."""

import from tempfile { TemporaryDirectory }
import from jaclang.runtime.context { ExecutionContext }
import from .test_session_rollback { _ctx, _sess }

test "durable boundaries follow parent contexts across independent sessions" {
    with TemporaryDirectory() as td, TemporaryDirectory() as other_td {
        parent = _ctx(td);
        unrelated = _ctx(other_td);
        child = ExecutionContext(_parent=parent, _own_session=True);
        try {
            outer = _sess(parent);
            inner = _sess(child);
            separate = _sess(unrelated);
            assert outer is not inner;
            assert outer._durable_boundary is inner._durable_boundary;
            assert outer._durable_boundary is not separate._durable_boundary;
            assert outer._durable_boundary.current() == 0;
            inner._durable_boundary.mark();
            assert outer._durable_boundary.current() == 1;
            assert separate._durable_boundary.current() == 0;
        } finally {
            child.close();
            parent.close();
            unrelated.close();
        }
    }
}
