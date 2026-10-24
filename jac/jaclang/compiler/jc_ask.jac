import from c { def PyTuple_New(n: int) -> int;  }
import from c { def PyTuple_SetItem(t: int, i: int, v: int) -> int;  }
import from c { def PyObject_CallObject(fn: int, args: int) -> int;  }
import from c { def PyUnicode_FromString(p: int) -> int;  }
import from c { def Py_DecRef(o: int) -> int;  }
import from c { def PyErr_Clear -> int;  }

obj AskState {
    has callback: int = 0,
        answer: str = "";
}

glob _ASK: AskState = AskState();

def set_host_callback(callback: int);

def take_host_answer(text: str);

def ask_host(method: str, key: str) -> str;
