"""Native reentrant FIFO with CPython's portable, interruptible wait primitive.

The interpreter lock protects queue state. A notification wakes one waiter;
consuming an item passes that notification on when more items remain. CPython
references are visible to its cycle collector through the borrowed-item ABI.
Derived from CPython 3.14.6; see ../LICENSE.cpython.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyErr_SetNone,
    PyObject,
    PyThread_release_lock,
    Py_MakePendingCalls,
    Py_NewRef,
    _PyDeadline_Get,
    _PyDeadline_Init,
    jacpy_error_pending,
    jacpy_is_none,
    jacpy_lock_free,
    jacpy_lock_wait,
    jacpy_release,
    jacpy_timeout_ns
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module { jacpy_binding_visit }

import from jaclang.runtime.python.modules.object_ring { object_ring }

obj queue_state(NativeState) {
    has lock: ptr,
        items: object_ring = object_ring(),
        waiters: int = 0,
        notification: bool = False;

    def clear {
        jacpy_queue_clear(self);
    }

    def traverse_refs(visitor: ptr[PyObject], context: ptr[PyObject]) -> i32 {
        for i in range(self.items.count) {
            result = jacpy_binding_visit(self.items.borrow(i), visitor, context);
            if result != 0 {
                return result;
            }
        }
        return i32(0);
    }

    def drop {
        self.clear();
        jacpy_lock_free(self.lock);
    }

    def notify {
        if self.waiters > 0 and self.items.count > 0 and not self.notification {
            self.notification = True;
            PyThread_release_lock(self.lock);
        }
    }
}

def:pub jacpy_queue_new(lock: ptr) -> queue_state {
    return queue_state(lock=lock);
}

def:pub jacpy_queue_clear(state: queue_state) {
    items = state.items;
    # Publish an empty queue before releasing values whose finalizers may put().
    state.items = object_ring();
    while items.count > 0 {
        jacpy_release(items.pop(True));
    }
}

def:pub jacpy_queue_size(state: queue_state) -> i64 {
    return i64(state.items.count);
}

# Borrowed references: the CPython GC visitor never calls Python or releases GIL.
def:pub jacpy_queue_borrow(state: queue_state, index: i64) -> ptr[PyObject] {
    return state.items.borrow(int(index));
}

def:pub jacpy_queue_put(state: queue_state, value: ptr[PyObject]) {
    state.items.push(Py_NewRef(value));
    state.notify();
}

def:pub jacpy_queue_get(
    state: queue_state, empty: ptr[PyObject], block: i64, timeout: ptr[PyObject]
) -> ptr[PyObject] {
    deadline: i64 = 0;
    if block != 0 and jacpy_is_none(timeout) == 0 {
        nanoseconds = jacpy_timeout_ns(timeout);
        if jacpy_error_pending() != 0 {
            return NULL;
        }
        if nanoseconds < 0 {
            object_error("ValueError", "'timeout' must be a non-negative number");
            return NULL;
        }
        deadline = _PyDeadline_Init(nanoseconds);
    }
    while True {
        if state.items.count > 0 {
            value = state.items.pop(True);
            state.notify();
            return value;
        }
        if block == 0 {
            PyErr_SetNone(empty);
            return NULL;
        }
        remaining: i64 = -1;
        if deadline != 0 {
            remaining = _PyDeadline_Get(deadline);
            if remaining < 0 {
                PyErr_SetNone(empty);
                return NULL;
            }
        }
        state.waiters += 1;
        status = jacpy_lock_wait(state.lock, remaining);
        state.waiters -= 1;
        if status == 1 {
            state.notification = False;
        } elif status == 0 {
            PyErr_SetNone(empty);
            return NULL;
        } elif Py_MakePendingCalls() < 0 {
            return NULL;
        }
    }
    return NULL;
}
