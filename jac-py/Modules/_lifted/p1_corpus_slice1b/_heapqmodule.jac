import from _bisectmodule {
    PyListObject,
    PyObject,
    PySequenceMethods,
    PyTypeObject,
    richcmpfunc,
    ssizeargfunc,
    unaryfunc
}

glob ptrdiff_t = int,
     size_t = int,
     ssize_t = int,
     intptr_t = int,
     uintptr_t = int,
     int8_t = int,
     uint8_t = int,
     int16_t = int,
     uint16_t = int,
     int32_t = int,
     uint32_t = int,
     int64_t = int,
     uint64_t = int,
     intmax_t = int,
     uintmax_t = int,
     int_least8_t = int,
     uint_least8_t = int,
     int_least16_t = int,
     uint_least16_t = int,
     int_least32_t = int,
     uint_least32_t = int,
     int_least64_t = int,
     uint_least64_t = int,
     int_fast8_t = int,
     uint_fast8_t = int,
     int_fast16_t = int,
     uint_fast16_t = int,
     int_fast32_t = int,
     uint_fast32_t = int,
     int_fast64_t = int,
     uint_fast64_t = int,
     Py_ssize_t = int,
     Py_hash_t = int,
     PyExc_IndexError: PyObj = PyObj(),
     PyExc_RuntimeError: PyObj = PyObj();

def siftdown(heap: PyListObject, startpos: int, pos: int) -> int {
    newitem: PyObj = PyObj();
    parent: PyObj = PyObj();
    arr: object = object();
    parentpos: int = 0;
    size: int = 0;
    cmp: int = 0;

    size = heap.ob_size;
    if (pos >= size) {
        raise IndexError("index out of range");
    }

    arr = heap.ob_item;
    newitem = arr[pos];
    while (pos > startpos) {
        parentpos = (pos - 1) >> 1;
        parent = arr[parentpos];
        ;
        ;
        cmp = PyObject_RichCompareBool(newitem, parent, 0);
        ;
        ;
        if (cmp < 0) {
            return -1;
        }
        if (size != heap.ob_size) {
            raise RuntimeError("list changed size during iteration");
        }

        if (cmp == 0) {
            break;
        }
        arr = heap.ob_item;
        arr[pos] = parent;
        arr[parentpos] = newitem;
        pos = parentpos;
    }

    return 0;
}

def heap_siftdown(heap: PyObj, startpos: int, pos: int) -> int {
    return siftdown(heap, startpos, pos);
}
