import from c {
    obj JacRtUnwindRecord {
        has next: ptr[JacRtUnwindRecord],
            target: ptr[u8],
            cleanup: Callable[[ptr[u8]], None];
    }  obj JacRtExcState {
        has target: ptr[u8],
            type_id: i32,
            prev: ptr[JacRtExcState],
            message: ptr[u8],
            saved_unwind_top: ptr[JacRtUnwindRecord];
    }  obj JacRtExcContext {
        has handler: ptr[JacRtExcState],
            unwind_top: ptr[JacRtUnwindRecord],
            error_type: i32,
            error_target: ptr[u8],
            error_message: ptr[u8];
    }  def _longjmp(env: ptr[u8], value: i32) -> None;  def write(
        fd: i32, buf: ptr[u8], count: i64
    ) -> i64;  def strlen(text: ptr[u8]) -> i64;  def `exit(code: i32) -> None;
}

glob EXC_STATE_HEADER: int = 40;

def:pub __jac_rt_exc_context -> ptr[JacRtExcContext];

def:pub __jac_rt_exc_jmp_buf(state: ptr[JacRtExcState]) -> ptr[u8];

def:pub __jac_rt_exc_push(state: ptr[JacRtExcState]);

def:pub __jac_rt_exc_pop(state: ptr[JacRtExcState]);

def:pub __jac_rt_unwind_push(record: ptr[JacRtUnwindRecord]);

def:pub __jac_rt_unwind_pop(record: ptr[JacRtUnwindRecord]);

def:pub __jac_rt_raise(target: ptr[u8], type_id: i32, message: ptr[u8]);

def:pub __jac_rt_raise_builtin(type_id: i32, message: ptr[u8]);

def _write_text(text: ptr[u8]);

def _report_uncaught(message: ptr[u8]);
