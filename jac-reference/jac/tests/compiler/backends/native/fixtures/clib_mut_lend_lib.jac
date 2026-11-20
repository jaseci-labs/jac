"""C symbols defined in Jac whose C declarations elsewhere take `&mut T`."""
import from c {
    def lend_store_i32(target: ptr[i32], value: i32) {
        target.view(1)[0] = value;
    }  def lend_store_i64(target: ptr[i64], value: i64) -> i32 {
        target.view(1)[0] = value;
        return i32(1);
    }
}

def:pub lend_lib_ready -> i64 {
    return 1;
}
