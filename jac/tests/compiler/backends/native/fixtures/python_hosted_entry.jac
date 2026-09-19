"""Exercise generated server-to-native stubs with a Python C API dependency."""
import from c { def PyGILState_Check -> i32;  def PyErr_BadArgument -> i32;  }

def hosted_gil -> int {
    return int(PyGILState_Check());
}

def hosted_failure -> int {
    return int(PyErr_BadArgument());
}

def server_call -> int {
    return hosted_gil();
}

def server_failure -> int {
    return hosted_failure();
}
