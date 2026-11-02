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
