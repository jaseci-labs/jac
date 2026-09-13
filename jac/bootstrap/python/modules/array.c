/* Python array types, buffer views, and argument conversion for native Jac. */
#include <Python.h>
#include <stddef.h>
#include <stdint.h>
#define H(p) ((uint64_t)(uintptr_t)(p))
#define O(h) ((PyObject *)(uintptr_t)(h))
typedef struct { PyObject_HEAD void *native; PyObject *weakrefs; Py_ssize_t shape; char format[2]; } Array;
typedef struct { PyObject_HEAD void *native; } Iterator;
typedef struct { PyObject *array_type,*iterator_type; } Module;
static PyModuleDef definition;
extern void jac_retain(void *),jac_release(void *);
extern void *jacpy_array_new(void),*jacpy_array_cursor_new(uint64_t);
extern void jacpy_array_clear(void *),jacpy_array_export(void *,int64_t),jacpy_array_reverse(void *,int64_t),jacpy_array_cursor_clear(void *),jacpy_array_cursor_set(void *,int64_t);
extern int64_t jacpy_array_init(void *,int64_t),jacpy_array_length(void *),jacpy_array_code(void *),jacpy_array_itemsize(void *),jacpy_array_memory(void *);
extern int64_t jacpy_array_assign(void *,int64_t,uint64_t),jacpy_array_insert(void *,int64_t,uint64_t),jacpy_array_empty(void *),jacpy_array_extend(void *,uint64_t),jacpy_array_fromlist(void *,uint64_t),jacpy_array_fromunicode(void *,uint64_t);
extern int64_t jacpy_array_frombytes(void *,uint64_t,int64_t),jacpy_array_copy(void *,void *,int64_t,int64_t,int64_t),jacpy_array_assign_slice(void *,int64_t,int64_t,int64_t,void *),jacpy_array_delete(void *,int64_t,int64_t,int64_t),jacpy_array_repeat(void *,int64_t),jacpy_array_search(void *,uint64_t,int64_t,int64_t,int64_t);
extern uint64_t jacpy_array_field(void *),jacpy_array_address(void *),jacpy_array_item(void *,int64_t),jacpy_array_pop(void *,int64_t),jacpy_array_tolist(void *),jacpy_array_tobytes(void *),jacpy_array_tounicode(void *),jacpy_array_repr(void *),jacpy_array_compare(void *,void *,int64_t);
extern uint64_t jacpy_array_cursor_owner(void *),jacpy_array_cursor_next(void *);
extern int64_t jacpy_array_cursor_index(void *);
extern int64_t jacpy_array_fromfile(void *,uint64_t,int64_t),jacpy_array_tofile(void *,uint64_t);
extern uint64_t jacpy_array_reduce(void *,uint64_t,uint64_t,uint64_t,int64_t),jacpy_array_cursor_reduce(void *,uint64_t),jacpy_array_reconstruct_object(uint64_t,int64_t,int64_t,uint64_t);
static Module *module_for(PyTypeObject *type) { PyObject *m=PyType_GetModuleByDef(type,&definition); return m ? PyModule_GetState(m) : NULL; }
static int is_array(PyObject *value,Module *m) { return PyObject_TypeCheck(value,(PyTypeObject *)m->array_type); }
void *jacpy_array_state(uint64_t handle) { void *state=((Array *)O(handle))->native; jac_retain(state); return state; }
static PyObject *done(int64_t status) { if(status<0) return NULL; Py_RETURN_NONE; }
static int array_clear(PyObject *op) { Array *a=(Array *)op; if(a->native) jacpy_array_clear(a->native); return 0; }
static int array_traverse(PyObject *op,visitproc visit,void *arg) { Array *a=(Array *)op; Py_VISIT(Py_TYPE(op)); if(a->native) Py_VISIT(O(jacpy_array_field(a->native))); return 0; }
static void array_dealloc(PyObject *op) { Array *a=(Array *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); if(a->weakrefs) PyObject_ClearWeakRefs(op); array_clear(op); if(a->native) jac_release(a->native); type->tp_free(op); Py_DECREF(type); }
static PyObject *allocate(PyTypeObject *type,int code) {
    Array *a=(Array *)type->tp_alloc(type,0); if(!a) return NULL;
    a->native=jacpy_array_new(); a->format[0]=code=='u' ? 'w' : (char)code; a->format[1]=0;
    if(jacpy_array_init(a->native,code)<0) { Py_DECREF(a); return NULL; } return (PyObject *)a;
}
static int append_buffer(Array *a,PyObject *value) {
    Py_buffer view; if(PyObject_GetBuffer(value,&view,PyBUF_SIMPLE)<0) return -1;
    int status=(int)jacpy_array_frombytes(a->native,H(view.buf),view.len); PyBuffer_Release(&view); return status;
}
static PyObject *array_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    Module *m=module_for(type); if(!m) return NULL;
    if(kw && PyDict_GET_SIZE(kw) && (type==(PyTypeObject *)m->array_type || type->tp_init==((PyTypeObject *)m->array_type)->tp_init)) { PyErr_SetString(PyExc_TypeError,"array.array() takes no keyword arguments"); return NULL; }
    int code; PyObject *initial=NULL;
    if(!PyArg_ParseTuple(args,"C|O:array",&code,&initial)) return NULL;
    if(PySys_Audit("array.__new__","CO",code,initial ? initial : Py_None)<0) return NULL;
    if(code=='u' && PyErr_WarnEx(PyExc_DeprecationWarning,"The 'u' type code is deprecated and will be removed in Python 3.16",1)<0) return NULL;
    int unicode=code=='u' || code=='w';
    if(initial && !unicode && (PyUnicode_Check(initial) || (is_array(initial,m) && (jacpy_array_code(((Array *)initial)->native)=='u' || jacpy_array_code(((Array *)initial)->native)=='w')))) {
        PyErr_Format(PyExc_TypeError,"cannot use a %s to initialize an array with typecode '%c'",PyUnicode_Check(initial) ? "str" : "unicode array",code); return NULL;
    }
    PyObject *op=allocate(type,code); if(!op) return NULL; Array *a=(Array *)op;
    if(initial) {
        int status;
        if(PyBytes_Check(initial) || PyByteArray_Check(initial)) status=append_buffer(a,initial);
        else if(is_array(initial,m) && jacpy_array_code(((Array *)initial)->native)==code) status=(int)jacpy_array_copy(a->native,((Array *)initial)->native,0,1,jacpy_array_length(((Array *)initial)->native));
        else status=(int)jacpy_array_extend(a->native,H(initial));
        if(status<0) { Py_DECREF(op); return NULL; }
    }
    return op;
}
static Py_ssize_t array_length(PyObject *op) { return (Py_ssize_t)jacpy_array_length(((Array *)op)->native); }
static PyObject *array_item(PyObject *op,Py_ssize_t index) { return O(jacpy_array_item(((Array *)op)->native,index)); }
static int array_assign_item(PyObject *op,Py_ssize_t index,PyObject *value) {
    Array *a=(Array *)op;
    if(index<0 || index>=array_length(op)) { PyErr_SetString(PyExc_IndexError,"array assignment index out of range"); return -1; }
    return (int)(value ? jacpy_array_assign(a->native,index,H(value)) : jacpy_array_delete(a->native,index,1,1));
}
static PyObject *array_subscript(PyObject *op,PyObject *key) {
    if(PyIndex_Check(key)) { Py_ssize_t index=PyNumber_AsSsize_t(key,PyExc_IndexError); if(index==-1 && PyErr_Occurred()) return NULL; if(index<0) index+=array_length(op); return array_item(op,index); }
    if(PySlice_Check(key)) {
        Py_ssize_t start,stop,step; if(PySlice_Unpack(key,&start,&stop,&step)<0) return NULL;
        Py_ssize_t count=PySlice_AdjustIndices(array_length(op),&start,&stop,step);
        Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; Array *a=(Array *)op;
        PyObject *result=allocate((PyTypeObject *)m->array_type,(int)jacpy_array_code(a->native)); if(!result) return NULL;
        if(jacpy_array_copy(((Array *)result)->native,a->native,start,step,count)<0) { Py_DECREF(result); return NULL; } return result;
    }
    PyErr_SetString(PyExc_TypeError,"array indices must be integers or slices"); return NULL;
}
static int array_assign_subscript(PyObject *op,PyObject *key,PyObject *value) {
    if(PyIndex_Check(key)) { Py_ssize_t index=PyNumber_AsSsize_t(key,PyExc_IndexError); if(index==-1 && PyErr_Occurred()) return -1; if(index<0) index+=array_length(op); return array_assign_item(op,index,value); }
    if(PySlice_Check(key)) {
        Py_ssize_t start,stop,step; if(PySlice_Unpack(key,&start,&stop,&step)<0) return -1;
        Py_ssize_t count=PySlice_AdjustIndices(array_length(op),&start,&stop,step); Array *a=(Array *)op;
        if(!value) return (int)jacpy_array_delete(a->native,start,step,count);
        Module *m=module_for(Py_TYPE(op)); if(!m) return -1;
        if(!is_array(value,m)) { PyErr_SetString(PyExc_TypeError,"can only assign array to array slice"); return -1; }
        return (int)jacpy_array_assign_slice(a->native,start,step,count,((Array *)value)->native);
    }
    PyErr_SetString(PyExc_TypeError,"array indices must be integers or slices"); return -1;
}
static PyObject *array_inplace_concat(PyObject *op,PyObject *other) {
    Module *m=module_for(Py_TYPE(op)); if(!m) return NULL;
    if(!is_array(other,m)) { PyErr_SetString(PyExc_TypeError,"can only extend array with array"); return NULL; }
    if(jacpy_array_assign_slice(((Array *)op)->native,array_length(op),1,0,((Array *)other)->native)<0) return NULL;
    return Py_NewRef(op);
}
static PyObject *array_copy(PyObject *op,PyObject *unused) {
    Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; Array *a=(Array *)op;
    PyObject *result=allocate((PyTypeObject *)m->array_type,(int)jacpy_array_code(a->native)); if(!result) return NULL;
    if(jacpy_array_copy(((Array *)result)->native,a->native,0,1,array_length(op))<0) { Py_DECREF(result); return NULL; } return result;
}
static PyObject *array_concat(PyObject *op,PyObject *other) { PyObject *copy=array_copy(op,NULL); if(!copy) return NULL; PyObject *result=array_inplace_concat(copy,other); Py_DECREF(copy); return result; }
static PyObject *array_inplace_repeat(PyObject *op,Py_ssize_t times) { if(jacpy_array_repeat(((Array *)op)->native,times)<0) return NULL; return Py_NewRef(op); }
static PyObject *array_repeat(PyObject *op,Py_ssize_t times) { PyObject *copy=array_copy(op,NULL); if(!copy) return NULL; PyObject *result=array_inplace_repeat(copy,times); Py_DECREF(copy); return result; }
static PyObject *array_richcompare(PyObject *op,PyObject *other,int operation) { Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; if(!is_array(other,m)) Py_RETURN_NOTIMPLEMENTED; return O(jacpy_array_compare(((Array *)op)->native,((Array *)other)->native,operation)); }
static int array_contains(PyObject *op,PyObject *value) { return (int)jacpy_array_search(((Array *)op)->native,H(value),0,PY_SSIZE_T_MAX,3); }
static PyObject *array_repr(PyObject *op) { return O(jacpy_array_repr(((Array *)op)->native)); }
static PyObject *array_append(PyObject *op,PyObject *value) { return done(jacpy_array_insert(((Array *)op)->native,PY_SSIZE_T_MAX,H(value))); }
static PyObject *array_insert(PyObject *op,PyObject *args) { Py_ssize_t index; PyObject *value; if(!PyArg_ParseTuple(args,"nO:insert",&index,&value)) return NULL; return done(jacpy_array_insert(((Array *)op)->native,index,H(value))); }
static PyObject *array_pop(PyObject *op,PyObject *args) { Py_ssize_t index=-1; if(!PyArg_ParseTuple(args,"|n:pop",&index)) return NULL; return O(jacpy_array_pop(((Array *)op)->native,index)); }
static PyObject *array_index(PyObject *op,PyObject *args) { PyObject *value; Py_ssize_t start=0,stop=PY_SSIZE_T_MAX; if(!PyArg_ParseTuple(args,"O|nn:index",&value,&start,&stop)) return NULL; int64_t result=jacpy_array_search(((Array *)op)->native,H(value),start,stop,1); return result<0 ? NULL : PyLong_FromLongLong(result); }
static PyObject *array_count(PyObject *op,PyObject *value) { int64_t result=jacpy_array_search(((Array *)op)->native,H(value),0,PY_SSIZE_T_MAX,0); return result<0 ? NULL : PyLong_FromLongLong(result); }
static PyObject *array_remove(PyObject *op,PyObject *value) { return done(jacpy_array_search(((Array *)op)->native,H(value),0,PY_SSIZE_T_MAX,2)); }
static PyObject *array_empty(PyObject *op,PyObject *unused) { return done(jacpy_array_empty(((Array *)op)->native)); }
static PyObject *array_reverse(PyObject *op,PyObject *unused) { jacpy_array_reverse(((Array *)op)->native,0); Py_RETURN_NONE; }
static PyObject *array_byteswap(PyObject *op,PyObject *unused) { jacpy_array_reverse(((Array *)op)->native,1); Py_RETURN_NONE; }
static PyObject *array_tolist(PyObject *op,PyObject *unused) { return O(jacpy_array_tolist(((Array *)op)->native)); }
static PyObject *array_tobytes(PyObject *op,PyObject *unused) { return O(jacpy_array_tobytes(((Array *)op)->native)); }
static PyObject *array_tounicode(PyObject *op,PyObject *unused) { return O(jacpy_array_tounicode(((Array *)op)->native)); }
static PyObject *array_frombytes(PyObject *op,PyObject *value) { return done(append_buffer((Array *)op,value)); }
static PyObject *array_fromlist(PyObject *op,PyObject *value) { if(!PyList_Check(value)) { PyErr_SetString(PyExc_TypeError,"arg must be list"); return NULL; } return done(jacpy_array_fromlist(((Array *)op)->native,H(value))); }
static PyObject *array_fromunicode(PyObject *op,PyObject *value) { if(!PyUnicode_Check(value)) { PyErr_SetString(PyExc_TypeError,"fromunicode() argument must be str"); return NULL; } return done(jacpy_array_fromunicode(((Array *)op)->native,H(value))); }
static PyObject *array_extend(PyObject *op,PyObject *value) { Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; if(is_array(value,m)) return done(jacpy_array_assign_slice(((Array *)op)->native,array_length(op),1,0,((Array *)value)->native)); return done(jacpy_array_extend(((Array *)op)->native,H(value))); }
static PyObject *array_buffer_info(PyObject *op,PyObject *unused) { Array *a=(Array *)op; return Py_BuildValue("Kn",array_length(op) ? (unsigned long long)jacpy_array_address(a->native) : 0ULL,array_length(op)); }
static PyObject *array_sizeof(PyObject *op,PyObject *unused) { return PyLong_FromSsize_t(Py_TYPE(op)->tp_basicsize+jacpy_array_memory(((Array *)op)->native)); }
static PyObject *array_typecode(PyObject *op,void *unused) { return PyUnicode_FromOrdinal((int)jacpy_array_code(((Array *)op)->native)); }
static PyObject *array_itemsize(PyObject *op,void *unused) { return PyLong_FromLongLong(jacpy_array_itemsize(((Array *)op)->native)); }
static int array_getbuffer(PyObject *op,Py_buffer *view,int flags) {
    if(!view) { PyErr_SetString(PyExc_BufferError,"view==NULL argument is obsolete"); return -1; }
    Array *a=(Array *)op; Py_ssize_t width=(Py_ssize_t)jacpy_array_itemsize(a->native); a->shape=array_length(op);
    if(PyBuffer_FillInfo(view,op,(void *)(uintptr_t)jacpy_array_address(a->native),a->shape*width,0,flags)<0) return -1;
    view->itemsize=width; view->format=(flags&PyBUF_FORMAT) ? a->format : NULL;
    view->shape=(flags&PyBUF_ND) ? &a->shape : NULL; view->strides=((flags&PyBUF_STRIDES)==PyBUF_STRIDES) ? &view->itemsize : NULL;
    jacpy_array_export(a->native,1); return 0;
}
static void array_releasebuffer(PyObject *op,Py_buffer *view) { jacpy_array_export(((Array *)op)->native,-1); }
static PyObject *array_fromfile(PyObject *op,PyObject *args) { PyObject *file; Py_ssize_t count; if(!PyArg_ParseTuple(args,"On:fromfile",&file,&count)) return NULL; return done(jacpy_array_fromfile(((Array *)op)->native,H(file),count)); }
static PyObject *array_tofile(PyObject *op,PyObject *file) { return done(jacpy_array_tofile(((Array *)op)->native,H(file))); }
static PyObject *array_reduce(PyObject *op,PyObject *value) {
    if(!PyLong_Check(value)) { PyErr_SetString(PyExc_TypeError,"__reduce_ex__ argument should be an integer"); return NULL; }
    long protocol=PyLong_AsLong(value); if(protocol==-1 && PyErr_Occurred()) return NULL;
    PyObject *module=PyType_GetModuleByDef(Py_TYPE(op),&definition); if(!module) return NULL;
    PyObject *reconstructor=PyObject_GetAttrString(module,"_array_reconstructor"); if(!reconstructor) return NULL;
    PyObject *dictionary=NULL; if(PyObject_GetOptionalAttrString(op,"__dict__",&dictionary)<0) { Py_DECREF(reconstructor); return NULL; }
    if(!dictionary) dictionary=Py_NewRef(Py_None);
    PyObject *result=O(jacpy_array_reduce(((Array *)op)->native,H(Py_TYPE(op)),H(dictionary),H(reconstructor),protocol));
    Py_DECREF(dictionary); Py_DECREF(reconstructor); return result;
}
static PyObject *array_reconstructor(PyObject *module,PyObject *args) {
    PyObject *type,*data; int code,format;
    if(!PyArg_ParseTuple(args,"OCiO:_array_reconstructor",&type,&code,&format,&data)) return NULL;
    Module *m=PyModule_GetState(module);
    if(!PyType_Check(type) || !PyType_IsSubtype((PyTypeObject *)type,(PyTypeObject *)m->array_type)) { PyErr_SetString(PyExc_TypeError,"first argument must be an array subtype"); return NULL; }
    if(!PyBytes_Check(data)) { PyErr_SetString(PyExc_TypeError,"fourth argument should be bytes"); return NULL; }
    return O(jacpy_array_reconstruct_object(H(type),code,format,H(data)));
}
static PyMethodDef module_methods[]={{"_array_reconstructor",array_reconstructor,METH_VARARGS,NULL},{NULL}};
static PyGetSetDef array_getset[]={{"typecode",array_typecode,NULL,NULL,NULL},{"itemsize",array_itemsize,NULL,NULL,NULL},{NULL}};
static PyMethodDef array_methods[]={
    {"fromfile",array_fromfile,METH_VARARGS,NULL},{"tofile",array_tofile,METH_O,NULL},{"__reduce_ex__",array_reduce,METH_O,NULL},
    {"append",array_append,METH_O,NULL},{"insert",array_insert,METH_VARARGS,NULL},{"pop",array_pop,METH_VARARGS,NULL},
    {"index",array_index,METH_VARARGS,NULL},{"count",array_count,METH_O,NULL},{"remove",array_remove,METH_O,NULL},
    {"clear",array_empty,METH_NOARGS,NULL},{"reverse",array_reverse,METH_NOARGS,NULL},{"byteswap",array_byteswap,METH_NOARGS,NULL},
    {"extend",array_extend,METH_O,NULL},{"fromlist",array_fromlist,METH_O,NULL},{"frombytes",array_frombytes,METH_O,NULL},{"fromunicode",array_fromunicode,METH_O,NULL},
    {"tolist",array_tolist,METH_NOARGS,NULL},{"tobytes",array_tobytes,METH_NOARGS,NULL},{"tounicode",array_tounicode,METH_NOARGS,NULL},
    {"buffer_info",array_buffer_info,METH_NOARGS,NULL},{"__sizeof__",array_sizeof,METH_NOARGS,NULL},{"__copy__",array_copy,METH_NOARGS,NULL},{"__deepcopy__",array_copy,METH_O,NULL},
    {"__class_getitem__",Py_GenericAlias,METH_O|METH_CLASS,"See PEP 585"},{NULL}};
static int iterator_clear(PyObject *op) { Iterator *i=(Iterator *)op; if(i->native) jacpy_array_cursor_clear(i->native); return 0; }
static int iterator_traverse(PyObject *op,visitproc visit,void *arg) { Iterator *i=(Iterator *)op; Py_VISIT(Py_TYPE(op)); if(i->native) Py_VISIT(O(jacpy_array_cursor_owner(i->native))); return 0; }
static void iterator_dealloc(PyObject *op) { Iterator *i=(Iterator *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); iterator_clear(op); if(i->native) jac_release(i->native); type->tp_free(op); Py_DECREF(type); }
static PyObject *iterator_next(PyObject *op) { return O(jacpy_array_cursor_next(((Iterator *)op)->native)); }
static PyObject *iterator_setstate(PyObject *op,PyObject *value) { Py_ssize_t index=PyLong_AsSsize_t(value); if(index==-1 && PyErr_Occurred()) return NULL; jacpy_array_cursor_set(((Iterator *)op)->native,index); Py_RETURN_NONE; }
static PyObject *iterator_reduce(PyObject *op,PyObject *unused) {
    PyObject *iterate=PyDict_GetItemString(PyEval_GetBuiltins(),"iter");
    if(!iterate) { PyErr_SetString(PyExc_RuntimeError,"missing builtin iter"); return NULL; }
    return O(jacpy_array_cursor_reduce(((Iterator *)op)->native,H(iterate)));
}
static PyMethodDef iterator_methods[]={{"__reduce__",iterator_reduce,METH_NOARGS,NULL},{"__setstate__",iterator_setstate,METH_O,NULL},{NULL}};
static PyObject *array_iter(PyObject *op) { Module *m=module_for(Py_TYPE(op)); if(!m) return NULL; Iterator *i=(Iterator *)((PyTypeObject *)m->iterator_type)->tp_alloc((PyTypeObject *)m->iterator_type,0); if(!i) return NULL; i->native=jacpy_array_cursor_new(H(op)); return (PyObject *)i; }
static PyType_Slot iterator_slots[]={{Py_tp_dealloc,iterator_dealloc},{Py_tp_traverse,iterator_traverse},{Py_tp_clear,iterator_clear},{Py_tp_iter,PyObject_SelfIter},{Py_tp_iternext,iterator_next},{Py_tp_methods,iterator_methods},{0}};
static PyType_Spec iterator_spec={"array.arrayiterator",sizeof(Iterator),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_IMMUTABLETYPE|Py_TPFLAGS_DISALLOW_INSTANTIATION,iterator_slots};
static PyType_Slot array_slots[]={
    {Py_tp_new,array_new},{Py_tp_dealloc,array_dealloc},{Py_tp_traverse,array_traverse},{Py_tp_clear,array_clear},
    {Py_tp_repr,array_repr},{Py_tp_hash,PyObject_HashNotImplemented},{Py_tp_richcompare,array_richcompare},{Py_tp_iter,array_iter},
    {Py_sq_length,array_length},{Py_sq_item,array_item},{Py_sq_ass_item,array_assign_item},{Py_sq_contains,array_contains},
    {Py_sq_concat,array_concat},{Py_sq_inplace_concat,array_inplace_concat},{Py_sq_repeat,array_repeat},{Py_sq_inplace_repeat,array_inplace_repeat},
    {Py_mp_length,array_length},{Py_mp_subscript,array_subscript},{Py_mp_ass_subscript,array_assign_subscript},
    {Py_bf_getbuffer,array_getbuffer},{Py_bf_releasebuffer,array_releasebuffer},{Py_tp_methods,array_methods},{Py_tp_getset,array_getset},{0}};
static PyType_Spec array_spec={"array.array",sizeof(Array),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_BASETYPE|Py_TPFLAGS_IMMUTABLETYPE|Py_TPFLAGS_SEQUENCE,array_slots};
static int module_traverse(PyObject *op,visitproc visit,void *arg) { Module *m=PyModule_GetState(op); Py_VISIT(m->array_type); Py_VISIT(m->iterator_type); return 0; }
static int module_clear(PyObject *op) { Module *m=PyModule_GetState(op); Py_CLEAR(m->array_type); Py_CLEAR(m->iterator_type); return 0; }
static int module_exec(PyObject *op) {
    Module *m=PyModule_GetState(op);
    m->array_type=PyType_FromModuleAndSpec(op,&array_spec,NULL); if(!m->array_type) return -1;
    ((PyTypeObject *)m->array_type)->tp_weaklistoffset=offsetof(Array,weakrefs);
    m->iterator_type=PyType_FromModuleAndSpec(op,&iterator_spec,NULL); if(!m->iterator_type) return -1;
    if(PyModule_AddObjectRef(op,"array",m->array_type)<0 || PyModule_AddObjectRef(op,"ArrayType",m->array_type)<0 || PyModule_AddStringConstant(op,"typecodes","bBuhHiIlLqQfdw")<0) return -1;
    PyObject *abc=PyImport_ImportModuleAttrString("collections.abc","MutableSequence"); if(!abc) return -1;
    PyObject *registered=PyObject_CallMethod(abc,"register","O",m->array_type); Py_DECREF(abc); if(!registered) return -1; Py_DECREF(registered);
    return 0;
}
static PyModuleDef_Slot slots[]={{Py_mod_exec,module_exec},{Py_mod_multiple_interpreters,Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},{0}};
static PyModuleDef definition={PyModuleDef_HEAD_INIT,"array","Native Jac typed arrays.",sizeof(Module),module_methods,slots,module_traverse,module_clear,NULL};
PyMODINIT_FUNC PyInit_array(void) { return PyModuleDef_Init(&definition); }
