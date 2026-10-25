import from c {
    def syscall(number: i64, *args: any) -> i64;  def close(fd: i32) -> i32;  def read(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def _Py_open(
        pathname: ptr[u8], flags: i32
    ) -> i32;  glob:priv _Py_HashSecret_Initialized: i32 = 0,
         getrandom_works: i32 = 1,
         getentropy_works: i32 = 1,
         urandom_fd: i32 = -1,
         urandom_status: _Py_stat_struct = _Py_stat_struct();
}

glob:priv GRND_NONBLOCK: Final[i64] = 1,
     HASH_SECRET_SIZE: Final[i64] = 24;

def py_getrandom(buffer: ptr[u8], size: i64, blocking: bool, raise_: bool) -> i32;

def py_getentropy(buffer: ptr[u8], size: i64, raise_: bool) -> i32;

def dev_urandom(buffer: ptr[u8], size: i64, raise_: bool) -> i32;

def dev_urandom_close;

def lcg_urandom(x0: u32, buffer: ptr[u8], size: i64);

def pyurandom(buffer: ptr[u8], size: i64, blocking: bool, raise_: bool) -> i32;

import from c {
    def _PyOS_URandom(buffer: ptr, size: i64) -> i32 {
        return pyurandom(ptr[u8](buffer), size, True, True);
    }  def _PyOS_URandomNonblock(buffer: ptr, size: i64) -> i32 {
        return pyurandom(ptr[u8](buffer), size, False, True);
    }  def _Py_HashRandomization_Init(config: ptr[u8]) -> PyStatus {
        secret = ptr[u8](addressof(_Py_HashSecret));
        secret_size = HASH_SECRET_SIZE;

        initialized = addressof(_Py_HashSecret_Initialized);
        if initialized.view(1)[0] != 0 {
            return status_ok();
        }
        initialized.view(1)[0] = 1;

        if ptr[i32](config + PyConfig_USE_HASH_SEED).view(1)[0] != 0 {
            hash_seed = ptr[u64](config + PyConfig_HASH_SEED).view(1)[0];
            if hash_seed == u64(0) {
                memset(ptr(secret), i32(0), u64(secret_size));
            } else {
                lcg_urandom(u32.wrap(hash_seed), secret, secret_size);
            }
        } else {
            res = pyurandom(secret, secret_size, False, False);
            if res < 0 {
                return status_err(
                    ptr[u8]("_Py_HashRandomization_Init"),
                    ptr[u8]("failed to get random numbers to initialize Python")
                );
            }
        }
        return status_ok();
    }  def _Py_HashRandomization_Fini {
        dev_urandom_close();
    }
}

impl py_getrandom(buffer: ptr[u8], size: i64, blocking: bool, raise_: bool) -> i32 {
    works = addressof(getrandom_works);
    if works.view(1)[0] == 0 {
        return i32(0);
    }

    flags: i64 = 0 if blocking else GRND_NONBLOCK;
    dest = buffer;
    remaining = size;
    while 0 < remaining {
        n = remaining;
        jacpy_set_errno(0);
        err: i32 = 0;
        if raise_ {
            save = PyEval_SaveThread();
            n = syscall(SYS_GETRANDOM, ptr(dest), n, flags);
            err = i32.wrap(jacpy_errno());
            PyEval_RestoreThread(save);
        } else {
            n = syscall(SYS_GETRANDOM, ptr(dest), n, flags);
            err = i32.wrap(jacpy_errno());
        }

        if n < 0 {
            if err == ENOSYS or err == EPERM {
                works.view(1)[0] = 0;
                return i32(0);
            }

            if err == EAGAIN and not raise_ and not blocking {
                return i32(0);
            }

            if err == EINTR {
                if raise_ {
                    if PyErr_CheckSignals() != 0 {
                        return i32(-1);
                    }
                }

                continue;
            }

            if raise_ {
                jacpy_set_errno(i64(err));
                PyErr_SetFromErrno(PyExc_OSError);
            }
            return i32(-1);
        }

        dest = dest + n;
        remaining -= n;
    }
    return i32(1);
}

impl py_getentropy(buffer: ptr[u8], size: i64, raise_: bool) -> i32 {
    works = addressof(getentropy_works);
    if works.view(1)[0] == 0 {
        return i32(0);
    }

    dest = buffer;
    remaining = size;
    while remaining > 0 {
        length = remaining if remaining < 256 else 256;
        res: i32 = 0;
        err: i32 = 0;

        if raise_ {
            save = PyEval_SaveThread();
            res = getentropy_fill(dest, length);
            err = i32.wrap(jacpy_errno());
            PyEval_RestoreThread(save);
        } else {
            res = getentropy_fill(dest, length);
            err = i32.wrap(jacpy_errno());
        }

        if res < 0 {
            if err == ENOSYS or err == EPERM {
                works.view(1)[0] = 0;
                return i32(0);
            }

            if err == EINTR {
                if raise_ {
                    if PyErr_CheckSignals() != 0 {
                        return i32(-1);
                    }
                }

                continue;
            }

            if raise_ {
                jacpy_set_errno(i64(err));
                PyErr_SetFromErrno(PyExc_OSError);
            }
            return i32(-1);
        }

        dest = dest + length;
        remaining -= length;
    }
    return i32(1);
}

impl dev_urandom(buffer: ptr[u8], size: i64, raise_: bool) -> i32 {
    fd: i32 = -1;
    n: i64 = 0;
    dest = buffer;
    remaining = size;
    cached_fd = addressof(urandom_fd);
    cached = addressof(urandom_status);

    if raise_ {
        if cached_fd.view(1)[0] >= 0 {
            st = _Py_stat_struct();
            save = PyEval_SaveThread();
            fstat_result = _Py_fstat_noraise(cached_fd.view(1)[0], &mut st);
            PyEval_RestoreThread(save);

            if fstat_result != 0
                or st.st_dev != cached.view(1)[0].st_dev
                or st.st_ino != cached.view(1)[0].st_ino {
                cached_fd.view(1)[0] = -1;
            }
        }

        if cached_fd.view(1)[0] >= 0 {
            fd = cached_fd.view(1)[0];
        } else {
            fd = _Py_open(ptr[u8]("/dev/urandom"), O_RDONLY);
            if fd < 0 {
                err = i32.wrap(jacpy_errno());
                if err == ENOENT or err == ENXIO or err == ENODEV or err == EACCES {
                    PyErr_SetString(
                        PyExc_NotImplementedError,
                        "/dev/urandom (or equivalent) not found"
                    );
                }

                return i32(-1);
            }
            if cached_fd.view(1)[0] >= 0 {
                close(fd);
                fd = cached_fd.view(1)[0];
            } else {
                st = _Py_stat_struct();
                if _Py_fstat(fd, &mut st) != 0 {
                    close(fd);
                    return i32(-1);
                }
                cached_fd.view(1)[0] = fd;
                cached.view(1)[0].st_dev = st.st_dev;
                cached.view(1)[0].st_ino = st.st_ino;
            }
        }

        while True {
            n = _Py_read(fd, ptr(dest), u64(remaining));
            if n == -1 {
                return i32(-1);
            }
            if n == 0 {
                PyErr_Format(
                    PyExc_RuntimeError,
                    "Failed to read %zi bytes from /dev/urandom",
                    remaining
                );
                return i32(-1);
            }

            dest = dest + n;
            remaining -= n;
            if not (0 < remaining) {
                break;
            }
        }
    } else {
        fd = _Py_open_noraise(ptr(ptr[u8]("/dev/urandom")), O_RDONLY);
        if fd < 0 {
            return i32(-1);
        }
        while 0 < remaining {
            n = read(fd, ptr(dest), u64(remaining));
            while n < 0 and i32.wrap(jacpy_errno()) == EINTR {
                n = read(fd, ptr(dest), u64(remaining));
            }

            if n <= 0 {
                close(fd);
                return i32(-1);
            }

            dest = dest + n;
            remaining -= n;
        }
        close(fd);
    }
    return i32(0);
}

impl dev_urandom_close {
    cached_fd = addressof(urandom_fd);
    if cached_fd.view(1)[0] >= 0 {
        close(cached_fd.view(1)[0]);
        cached_fd.view(1)[0] = -1;
    }
}

impl lcg_urandom(x0: u32, buffer: ptr[u8], size: i64) {
    x = x0;
    index: i64 = 0;
    while index < size {
        x = wrapping_mul(x, u32(214013));
        x = wrapping_add(x, u32(2531011));

        (buffer + index).view(1)[0] = u8((x >> u32(16)) & u32(0xff));
        index += 1;
    }
}

impl pyurandom(buffer: ptr[u8], size: i64, blocking: bool, raise_: bool) -> i32 {
    if size < 0 {
        if raise_ {
            PyErr_Format(PyExc_ValueError, "negative argument not allowed");
        }
        return i32(-1);
    }

    if size == 0 {
        return i32(0);
    }

    res: i32 = 0;
    if SYS_GETRANDOM != 0 {
        res = py_getrandom(buffer, size, blocking, raise_);
    } elif HAVE_GETENTROPY {
        res = py_getentropy(buffer, size, raise_);
    } else {
        return dev_urandom(buffer, size, raise_);
    }
    if res < 0 {
        return i32(-1);
    }
    if res == 1 {
        return i32(0);
    }

    return dev_urandom(buffer, size, raise_);
}
