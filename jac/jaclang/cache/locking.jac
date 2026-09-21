import errno;
import os;
import from pathlib { Path }

obj FileLock {
    has path: Path,
        handle: int = -1;

    def acquire(create: bool = True) -> bool {
        if self.handle >= 0 {
            return True;
        }
        if create {
            self.path.parent.mkdir(parents=True, exist_ok=True);
        }
        fd = os.open(str(self.path), os.O_RDWR | (os.O_CREAT if create else 0), 0o600);
        try {
            if os.name == "nt" {
                import msvcrt;
                if os.fstat(fd).st_size == 0 {
                    os.write(fd, b"0");
                }
                os.lseek(fd, 0, 0);
                msvcrt.locking(fd, msvcrt.LK_NBLCK, 1);
            } else {
                import fcntl;
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB);
            }
        } except OSError as err {
            os.close(fd);
            if err.errno in [errno.EACCES, errno.EAGAIN] {
                return False;
            }
            raise;
        } except Exception {
            os.close(fd);
            raise;
        }
        self.handle = fd;
        return True;
    }

    def release {
        if self.handle >= 0 {
            os.close(self.handle);
            self.handle = -1;
        }
    }
}
