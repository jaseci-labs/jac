"""String runtime: comparison, length, size and output over the `JacStr`
descriptor's parts. A string's bytes are UTF-8 and its header word at -8 holds
the tagged byte length (bit 0 set, the ASCII flag in bit 63)."""
import from c {
    def memcpy(dst: ptr[u8], src: ptr[u8], n: i64) -> ptr[u8];  def memcmp(a: ptr[u8], b: ptr[u8], n: i64) -> i32;  def strlen(text: ptr[u8]) -> i64;  def fwrite(
        data: ptr[u8], size: i64, count: i64, stream: ptr[u8]
    ) -> i64;  def __jac_stdio(fd: i32) -> ptr[u8];
}

glob STR_TAG_OFF: int = -8,
     STR_LEN_PAYLOAD_MASK: int = 9223372036854775807,
     INT_TEXT_MAX: int = 24;

def:pub __jac_rt_str_cmp(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> int;

def:pub __jac_rt_str_len(owner: ptr[u8], data: ptr[u8], n: int) -> int;

def:pub __jac_rt_str_size(text: ptr[u8]) -> int;

def:pub __jac_rt_str_new(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_str_ref(owner: ptr[u8], data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_str_concat(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> ptr[u8];

def:pub __jac_rt_str_from_int(value: int) -> ptr[u8];

def:pub __jac_rt_str_char_at(data: ptr[u8], n: int, index: int) -> ptr[u8];

def:pub __jac_rt_write(fd: int, data: ptr[u8], n: int);

def:pub __jac_rt_write_int(fd: int, value: int);

def _int_text(value: int, buf: int) -> int;

def _str_alloc(n: int) -> ptr[u8];

def _str_finish(text: ptr[u8], n: int) -> ptr[u8];
