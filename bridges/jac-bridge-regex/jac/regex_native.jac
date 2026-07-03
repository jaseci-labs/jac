import struct;

import from "libc.so.6" { def strlen(s: str) -> int;  }

import from "libjac_bridge_regex.so" {
    def jac_regex_Regex_new(
        pattern: str, pattern_len: int, out_handle: bytes, out_err: bytes
    ) -> i32;  def jac_regex_Regex_is_match(
        handle: int, text: str, text_len: int, out_bool: bytes, out_err: bytes
    ) -> i32;  def jac_regex_Regex_drop(handle: int) -> None;  def jac_regex_error_drop(
        err_handle: int
    ) -> None;
}

obj Regex {
    has __handle: int = 0,
        __closed: bool = True;

    def init(pattern: str) {
        out_h = struct.pack("<Q", 0);
        out_e = struct.pack("<Q", 0);
        st = jac_regex_Regex_new(pattern, strlen(pattern), out_h, out_e);
        if st == 0 {
            self.__handle = struct.unpack("<Q", out_h)[0];
            self.__closed = False;
        } else {
            err_h = struct.unpack("<Q", out_e)[0];
            jac_regex_error_drop(err_h);
            raise ValueError("Regex::new failed with status " + str(st));
        }
    }

    def is_match(text: str) -> bool {
        if self.__closed {
            raise RuntimeError("Regex.is_match called after close()");
        }
        out_b = struct.pack("<B", 0);
        out_e = struct.pack("<Q", 0);
        st = jac_regex_Regex_is_match(self.__handle, text, strlen(text), out_b, out_e);
        if st == 0 {
            return struct.unpack("<B", out_b)[0] != 0;
        }
        err_h = struct.unpack("<Q", out_e)[0];
        jac_regex_error_drop(err_h);
        raise ValueError("is_match failed with status " + str(st));
    }

    def close {
        if not self.__closed {
            jac_regex_Regex_drop(self.__handle);
            self.__handle = 0;
            self.__closed = True;
        }
    }

    def __del__ {
        self.close();
    }
}

glob re = Regex("foo\\d+");

with entry {
    assert re.is_match("foo42") , "expected match";
    assert not re.is_match("bar") , "expected no-match";
    re.close();
}

glob caught = False;

with entry {
    try {
        bad = Regex("(unclosed");
    } except Exception as e {
        caught = True;
    }
    assert caught , "expected error for bad pattern";
}
