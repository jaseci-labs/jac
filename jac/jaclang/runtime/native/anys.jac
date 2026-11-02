import from c { def strlen(p: int) -> int;  def strcmp(a: int, b: int) -> int;  }

glob ANY_TAG_INT: int = 0,
     ANY_TAG_FLOAT: int = 1,
     ANY_TAG_STR: int = 2,
     ANY_TAG_LIST: int = 3,
     ANY_TAG_DICT: int = 4,
     ANY_TAG_SET: int = 5,
     ANY_TAG_OBJ: int = 6,
     ANY_TAG_BOOL: int = 7,
     ANY_TAG_NONE: int = 8,
     LIST_LEN: int = 0,
     HDR_TAG_BACK: int = 24,
     ANY_TAG_FIRST_REF: int = 2,
     ANY_TAG_LAST_REF: int = 6,
     BOX_TAG: int = 0,
     BOX_PAYLOAD: int = 8,
     BOX_SIZE: int = 16,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

def:pub __jac_rt_any_retain(tag: int, payload: int);

def:pub __jac_rt_any_release(tag: int, payload: int);

def:pub __jac_rt_any_box(tag: int, payload: int) -> int;

def:pub __jac_rt_any_truthy(tag: int, payload: int) -> bool;

def:pub __jac_rt_any_str(tag: int, payload: int) -> ptr[u8];

def:pub __jac_rt_type_name(o: int) -> ptr[u8];

def:pub __jac_rt_any_type_name(tag: int, payload: int) -> ptr[u8];

def:pub __jac_rt_any_isa(tag: int, payload: int, name: ptr[u8]) -> bool;

def:pub __jac_rt_cstr_eq(a: ptr[u8], b: ptr[u8]) -> bool;

def:pub __jac_rt_str_from_cstr(text: ptr[u8]) -> ptr[u8];

def:pub __jac_rt_class_name(text: ptr[u8]) -> ptr[u8];

def _holds_ref(tag: int) -> bool;

def _box_drop(box: ptr[u8]);
