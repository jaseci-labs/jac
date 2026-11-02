"""Closure runtime: cells and closure objects.

A cell holds one captured variable, shared by the function that declares it
and every closure over it: 16 bytes from `__jac_rt_alloc`, the value's bits at
+0 and its kind (KIND_*, as in lists) at +8. Storing borrows the value and
retains it when its kind is refcounted; the cell's drop releases it.

A closure is 16 + 8n bytes: the code address at +0, the cell count n at +8 and
n retained cells from +16. Generated code calls the code address with the
closure itself as the first argument; the body reads its captures through the
cells. A closure over nothing still allocates, so every function value has one
shape. The closure's drop releases its cells."""
glob CELL_BITS: int = 0,
     CELL_KIND: int = 8,
     CELL_SIZE: int = 16,
     CLOSURE_CODE: int = 0,
     CLOSURE_COUNT: int = 8,
     CLOSURE_CELLS: int = 16,
     SLOT: int = 8,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

def:pub __jac_rt_cell_new(kind: int) -> int;

def:pub __jac_rt_cell_get_ref(cell: int) -> int;

def:pub __jac_rt_cell_set(cell: int, bits: int, kind: int);

def:pub __jac_rt_closure_new(code: int, count: int) -> int;

def:pub __jac_rt_closure_set(closure: int, index: int, cell: int);

def _cell_drop(cell: ptr[u8]);

def _closure_drop(closure: ptr[u8]);
