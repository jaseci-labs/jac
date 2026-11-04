"""The defining side of a `&mut` C struct parameter called from another module."""
import from c {
    obj fd_record {
        has fd0: i32 = 0,
            fd1: i32 = 0;
    }  def pipe2(fds: &mut fd_record, flags: i32) -> i32;
}

def pipe_across(fds: &mut fd_record, flags: i32) -> i32 {
    return pipe2(fds, flags);
}
