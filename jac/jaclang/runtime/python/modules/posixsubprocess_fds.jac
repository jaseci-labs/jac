"""File descriptor helpers the _posixsubprocess child runs between fork and exec.

Derived from CPython 3.14.6 Modules/_posixsubprocess.c; see ../LICENSE.cpython.
Everything here is async-signal-safe: scalar and pointer arithmetic over
memory the parent allocated, and plain C calls. Nothing allocates.
"""

import from jaclang.runtime.python.cpython_api { _Py_closerange }
import from jaclang.runtime.python.modules.posixsubprocess_constants { _SC_OPEN_MAX }
import from c { def close(fd: i32) -> i32;  def sysconf(name: i32) -> i64;  }

glob INT_MAX: i64 = 2147483647,
     # How _close_range_except closes a subrange of descriptors.
     CLOSE_EACH: i64 = 0,
     CLOSE_RANGE: i64 = 1;

# The NUL-terminated ASCII digits at `name` as a non-negative int; -1 if any
# other character is present. No libc call; arithmetic stays in 64 bits, and a
# number no descriptor can have (above INT_MAX) is not one.
def pos_int_from_ascii(name: ptr[u8]) -> i32 {
    number = i64(0);
    cursor = name;
    while True {
        character = cursor.view(1)[0];
        if character < u8(48) or character > u8(57) {
            break;
        }
        if number <= INT_MAX {
            number = number * 10 + i64(character - u8(48));
        }
        cursor += 1;
    }
    if cursor.view(1)[0] != u8(0) or number > INT_MAX {
        return i32(-1);
    }
    return i32(number);
}

# Binary search of the sorted descriptors to keep.
def fd_in_sorted_fd_sequence(fd: i32, fds_to_keep: ptr[i32], count: i64) -> bool {
    low = i64(0);
    high = count - 1;
    while low <= high {
        middle = (low + high) // 2;
        middle_fd = (fds_to_keep + middle).view(1)[0];
        if fd == middle_fd {
            return True;
        }
        if fd > middle_fd {
            low = middle + 1;
        } else {
            high = middle - 1;
        }
    }
    return False;
}

# The highest descriptor this process could have open.
def safe_get_max_fd -> i64 {
    local_max_fd = sysconf(i32(_SC_OPEN_MAX));
    if local_max_fd == -1 {
        # Matches the legacy Lib/subprocess.py behavior.
        local_max_fd = 256;
    }
    return local_max_fd;
}

def:priv close_subrange(first: i64, last: i64, closer: i64) {
    if closer == CLOSE_RANGE {
        _Py_closerange(i32(first), i32(last));
        return;
    }
    fd = first;
    while fd <= last {
        close(i32(fd));
        fd += 1;
    }
}

# Close [start_fd, end_fd] except the sorted fds_to_keep, one subrange at a
# time; end_fd -1 means the highest possible descriptor. Descriptor
# arithmetic is 64-bit so INT_MAX + 1 cannot overflow.
def close_range_except(
    start_fd: i32, end_fd: i32, fds_to_keep: ptr[i32], count: i64, closer: i64
) {
    first = i64(start_fd);
    last = i64(end_fd);
    if last == -1 {
        maximum = safe_get_max_fd();
        last = INT_MAX if maximum > INT_MAX else maximum;
    }
    index = i64(0);
    while index < count {
        keep_fd = i64((fds_to_keep + index).view(1)[0]);
        index += 1;
        if keep_fd < first {
            continue;
        }
        if first <= keep_fd - 1 {
            close_subrange(first, keep_fd - 1, closer);
        }
        first = keep_fd + 1;
    }
    if first <= last {
        close_subrange(first, last, closer);
    }
}
