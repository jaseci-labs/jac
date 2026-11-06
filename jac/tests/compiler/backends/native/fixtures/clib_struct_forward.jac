"""A Jac function's `&mut` C struct parameter is the caller's storage."""
import from c { def pipe(fds: &mut fd_record) -> i32;  def close(fd: i32) -> i32;  }
import from clib_struct_forward_lib { fd_record, pipe_across }

def forward(fds: &mut fd_record, flags: i32) -> i32 {
    return pipe2_local(fds, flags);
}

def pipe2_local(fds: &mut fd_record, flags: i32) -> i32 {
    return pipe_across(fds, flags);
}

def mark(fds: &mut fd_record) {
    fds.fd0 = 40;
    fds.fd1 += 2;
}

def opened(fds: fd_record) -> int {
    got = 1 if fds.fd0 > 2 and fds.fd1 > 2 and fds.fd0 != fds.fd1 else 0;
    close(fds.fd0);
    close(fds.fd1);
    return got;
}

def direct -> int {
    fds = fd_record();
    if pipe(&mut fds) != 0 {
        return -1;
    }
    return opened(fds);
}

def forwarded -> int {
    fds = fd_record();
    if forward(&mut fds, i32(0)) != 0 {
        return -1;
    }
    return opened(fds);
}

def across -> int {
    fds = fd_record();
    if pipe_across(&mut fds, i32(0)) != 0 {
        return -1;
    }
    return opened(fds);
}

def written -> int {
    fds = fd_record(fd0=1, fd1=1);
    mark(&mut fds);
    return int(fds.fd0) + int(fds.fd1);
}
