/* Python callable layouts, GC visitation and signatures for native functools. */
#include <Python.h>
#include <stddef.h>
#include <stdint.h>
#define H(p) ((uint64_t)(uintptr_t)(p))
#define O(h) ((PyObject *)(uintptr_t)(h))
#define KW(fn) (PyCFunction)(void (*)(void))(fn)
typedef struct { PyObject *partial, *key, *lru, *hashed, *placeholder_type, *placeholder, *marker; } Module;
typedef struct { PyObject_HEAD void *native; PyObject *dict, *weakrefs; } Callable;
typedef struct { PyObject_HEAD PyObject *compare, *object; } Key;
typedef struct { PyObject_HEAD PyObject *key; Py_hash_t hash; } Hashed;
static PyModuleDef definition;
extern void jac_release(void *);
extern uint64_t jacpy_reduce(uint64_t,uint64_t,uint64_t), jacpy_cmp_key(uint64_t,uint64_t,uint64_t,int64_t);
extern void *jacpy_partial_new(void), *jacpy_lru_new(void);
extern uint64_t jacpy_partial_field(void *,int64_t), jacpy_lru_field(void *,int64_t);
extern void jacpy_partial_clear(void *), jacpy_lru_destroy(void *);
extern int64_t jacpy_partial_init(void *,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t,uint64_t);
extern uint64_t jacpy_partial_call(void *,uint64_t,uint64_t), jacpy_partial_restore(void *,uint64_t), jacpy_partial_repr(void *,uint64_t);
extern int64_t jacpy_lru_init(void *,uint64_t,int64_t,int64_t,uint64_t,uint64_t,uint64_t), jacpy_lru_clear(void *);
extern uint64_t jacpy_lru_call(void *,uint64_t,uint64_t), jacpy_lru_info(void *);
static Module *module_for(PyTypeObject *type) {
    PyObject *m=PyType_GetModuleByDef(type,&definition); return m ? PyModule_GetState(m) : NULL;
}
static PyObject *bind(PyObject *self,PyObject *object,PyObject *type) {
    return !object || object==Py_None ? Py_NewRef(self) : PyMethod_New(self,object);
}
static int partial_clear(PyObject *op) {
    Callable *self=(Callable *)op; if(self->native) jacpy_partial_clear(self->native); Py_CLEAR(self->dict); return 0;
}
static int lru_clear(PyObject *op) {
    Callable *self=(Callable *)op; if(self->native) jacpy_lru_destroy(self->native); Py_CLEAR(self->dict); return 0;
}
static int partial_traverse(PyObject *op,visitproc visit,void *arg) {
    Callable *self=(Callable *)op; Py_VISIT(Py_TYPE(op)); Py_VISIT(self->dict);
    if(self->native) for(int i=0;i<4;i++) Py_VISIT(O(jacpy_partial_field(self->native,i))); return 0;
}
static int lru_traverse(PyObject *op,visitproc visit,void *arg) {
    Callable *self=(Callable *)op; Py_VISIT(Py_TYPE(op)); Py_VISIT(self->dict);
    if(self->native) for(int i=0;i<7;i++) Py_VISIT(O(jacpy_lru_field(self->native,i))); return 0;
}
static void callable_dealloc(PyObject *op) {
    Callable *self=(Callable *)op; PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op);
    if(self->weakrefs) PyObject_ClearWeakRefs(op);
    type->tp_clear(op); if(self->native) jac_release(self->native); type->tp_free(op); Py_DECREF(type);
}
static PyMemberDef callable_members[]={
    {"__dictoffset__",Py_T_PYSSIZET,offsetof(Callable,dict),Py_READONLY},
    {"__weaklistoffset__",Py_T_PYSSIZET,offsetof(Callable,weakrefs),Py_READONLY},{NULL}};
static PyObject *partial_field(PyObject *op,void *field) {
    return Py_NewRef(O(jacpy_partial_field(((Callable *)op)->native,(intptr_t)field)));
}
static PyGetSetDef partial_getset[]={
    {"func",partial_field,NULL,"function object to use in future partial calls",(void *)0},
    {"args",partial_field,NULL,"tuple of arguments to future partial calls",(void *)1},
    {"keywords",partial_field,NULL,"dictionary of keyword arguments to future partial calls",(void *)2},
    {"__dict__",PyObject_GenericGetDict,PyObject_GenericSetDict},{NULL}};
static PyGetSetDef lru_getset[]={
    {"__dict__",PyObject_GenericGetDict,PyObject_GenericSetDict},{NULL}};
static PyObject *partial_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    Py_ssize_t n=PyTuple_GET_SIZE(args);
    if(n<1) { PyErr_SetString(PyExc_TypeError,"type 'partial' takes at least one argument"); return NULL; }
    PyObject *fn=PyTuple_GET_ITEM(args,0);
    if(!PyCallable_Check(fn)) { PyErr_SetString(PyExc_TypeError,"the first argument must be callable"); return NULL; }
    Module *m=module_for(type); if(!m) return NULL;
    PyObject *old_args=NULL,*old_kw=NULL;
    if(PyObject_TypeCheck(fn,(PyTypeObject *)m->partial) && !((Callable *)fn)->dict) {
        void *state=((Callable *)fn)->native;
        old_args=O(jacpy_partial_field(state,1)); old_kw=O(jacpy_partial_field(state,2)); fn=O(jacpy_partial_field(state,0));
    }
    /* Hold every borrowed field over allocation, which may run cyclic GC. */
    Py_INCREF(fn); Py_XINCREF(old_args); Py_XINCREF(old_kw);
    PyObject *tail=PyTuple_GetSlice(args,1,n); Callable *self=NULL;
    if(tail) self=(Callable *)type->tp_alloc(type,0);
    if(self) {
        self->native=jacpy_partial_new();
        if(jacpy_partial_init(self->native,H(fn),H(tail),H(kw),H(old_args),H(old_kw),H(m->placeholder))<0) Py_CLEAR(self);
    }
    Py_XDECREF(tail); Py_DECREF(fn); Py_XDECREF(old_args); Py_XDECREF(old_kw); return (PyObject *)self;
}
static PyObject *partial_call(PyObject *op,PyObject *args,PyObject *kw) {
    if(Py_EnterRecursiveCall(" while calling a Python object")) return NULL;
    PyObject *result=O(jacpy_partial_call(((Callable *)op)->native,H(args),H(kw))); Py_LeaveRecursiveCall(); return result;
}
static PyObject *partial_repr(PyObject *op) { return O(jacpy_partial_repr(((Callable *)op)->native,H(op))); }
static PyObject *partial_reduce(PyObject *op,PyObject *unused) {
    Callable *self=(Callable *)op; void *s=self->native;
    return Py_BuildValue("O(O)(OOOO)",Py_TYPE(op),O(jacpy_partial_field(s,0)),O(jacpy_partial_field(s,0)),
        O(jacpy_partial_field(s,1)),O(jacpy_partial_field(s,2)),self->dict ? self->dict : Py_None);
}
static PyObject *partial_setstate(PyObject *op,PyObject *state) {
    Callable *self=(Callable *)op; PyObject *dictionary=O(jacpy_partial_restore(self->native,H(state)));
    if(!dictionary) return NULL;
    if(dictionary==Py_None) { Py_DECREF(dictionary); dictionary=NULL; }
    Py_XSETREF(self->dict,dictionary); Py_RETURN_NONE;
}
static PyMethodDef partial_methods[]={
    {"__reduce__",partial_reduce,METH_NOARGS},{"__setstate__",partial_setstate,METH_O},
    {"__class_getitem__",Py_GenericAlias,METH_O|METH_CLASS,"partial is generic over the wrapped function's return type"},{NULL}};
static PyType_Slot partial_slots[]={
    {Py_tp_new,partial_new},{Py_tp_dealloc,callable_dealloc},{Py_tp_call,partial_call},
    {Py_tp_traverse,partial_traverse},{Py_tp_clear,partial_clear},{Py_tp_repr,partial_repr},
    {Py_tp_descr_get,bind},{Py_tp_members,callable_members},{Py_tp_getset,partial_getset},{Py_tp_methods,partial_methods},
    {Py_tp_doc,"partial(func, /, *args, **keywords)\n--\n\nCreate a new function with partial application of the given arguments\nand keywords."},{0}};
static PyType_Spec partial_spec={"functools.partial",sizeof(Callable),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_BASETYPE|Py_TPFLAGS_IMMUTABLETYPE,partial_slots};

static int key_clear(PyObject *op) { Key *self=(Key *)op; Py_CLEAR(self->compare); Py_CLEAR(self->object); return 0; }
static int key_traverse(PyObject *op,visitproc visit,void *arg) { Key *self=(Key *)op; Py_VISIT(Py_TYPE(op)); Py_VISIT(self->compare); Py_VISIT(self->object); return 0; }
static void key_dealloc(PyObject *op) { PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); key_clear(op); type->tp_free(op); Py_DECREF(type); }
static PyObject *key_new(PyTypeObject *type,PyObject *compare,PyObject *object) {
    Key *self=(Key *)type->tp_alloc(type,0); if(!self) return NULL;
    self->compare=Py_NewRef(compare); self->object=Py_XNewRef(object); return (PyObject *)self;
}
static PyObject *key_call(PyObject *op,PyObject *args,PyObject *kw) {
    static char *names[]={"obj",NULL}; PyObject *value;
    if(!PyArg_ParseTupleAndKeywords(args,kw,"O:K",names,&value)) return NULL;
    return key_new(Py_TYPE(op),((Key *)op)->compare,value);
}
static PyObject *key_compare(PyObject *op,PyObject *other,int comparison) {
    if(Py_TYPE(op)!=Py_TYPE(other)) { PyErr_SetString(PyExc_TypeError,"other argument must be K instance"); return NULL; }
    Key *a=(Key *)op,*b=(Key *)other;
    if(!a->object || !b->object) { PyErr_SetString(PyExc_AttributeError,"object"); return NULL; }
    return O(jacpy_cmp_key(H(a->compare),H(a->object),H(b->object),comparison));
}
static PyObject *key_signature(PyObject *op,void *unused) { return PyUnicode_FromString("(obj)"); }
static PyMemberDef key_members[]={{"obj",_Py_T_OBJECT,offsetof(Key,object),0,"Value wrapped by a key function."},{NULL}};
static PyGetSetDef key_getset[]={{"__text_signature__",key_signature,NULL},{NULL}};
static PyType_Slot key_slots[]={
    {Py_tp_dealloc,key_dealloc},{Py_tp_call,key_call},{Py_tp_traverse,key_traverse},{Py_tp_clear,key_clear},
    {Py_tp_richcompare,key_compare},{Py_tp_hash,PyObject_HashNotImplemented},{Py_tp_members,key_members},{Py_tp_getset,key_getset},{0}};
static PyType_Spec key_spec={"functools.KeyWrapper",sizeof(Key),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_DISALLOW_INSTANTIATION|Py_TPFLAGS_IMMUTABLETYPE,key_slots};

/* Cached hash is object representation, not cache policy. User __hash__ runs
 * once per lookup even when the retained mapping subsequently moves a key. */
static int hashed_clear(PyObject *op) { Py_CLEAR(((Hashed *)op)->key); return 0; }
static int hashed_traverse(PyObject *op,visitproc visit,void *arg) { Py_VISIT(Py_TYPE(op)); Py_VISIT(((Hashed *)op)->key); return 0; }
static void hashed_dealloc(PyObject *op) { PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); hashed_clear(op); type->tp_free(op); Py_DECREF(type); }
static Py_hash_t hashed_hash(PyObject *op) { return ((Hashed *)op)->hash; }
static PyObject *hashed_compare(PyObject *a,PyObject *b,int operation) {
    if(Py_TYPE(a)!=Py_TYPE(b)) Py_RETURN_NOTIMPLEMENTED;
    return PyObject_RichCompare(((Hashed *)a)->key,((Hashed *)b)->key,operation);
}
static PyType_Slot hashed_slots[]={
    {Py_tp_dealloc,hashed_dealloc},{Py_tp_traverse,hashed_traverse},{Py_tp_clear,hashed_clear},
    {Py_tp_hash,hashed_hash},{Py_tp_richcompare,hashed_compare},{0}};
static PyType_Spec hashed_spec={"functools._CacheKey",sizeof(Hashed),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_DISALLOW_INSTANTIATION|Py_TPFLAGS_IMMUTABLETYPE,hashed_slots};
uint64_t jacpy_functools_key(uint64_t type_handle,uint64_t key,int64_t hash) {
    PyTypeObject *type=(PyTypeObject *)O(type_handle); Hashed *self=(Hashed *)type->tp_alloc(type,0);
    if(!self) return 0; self->key=Py_NewRef(O(key)); self->hash=(Py_hash_t)hash; return H(self);
}
static PyObject *lru_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    static char *names[]={"user_function","maxsize","typed","cache_info_type",NULL};
    PyObject *fn,*size,*info; int typed;
    if(!PyArg_ParseTupleAndKeywords(args,kw,"OOpO:lru_cache",names,&fn,&size,&typed,&info)) return NULL;
    if(!PyCallable_Check(fn)) { PyErr_SetString(PyExc_TypeError,"the first argument must be callable"); return NULL; }
    Py_ssize_t maximum=-1;
    if(size!=Py_None) {
        if(!PyIndex_Check(size)) { PyErr_SetString(PyExc_TypeError,"maxsize should be integer or None"); return NULL; }
        maximum=PyNumber_AsSsize_t(size,PyExc_OverflowError); if(maximum==-1 && PyErr_Occurred()) return NULL;
        if(maximum<0) maximum=0;
    }
    Module *m=module_for(type); if(!m) return NULL;
    Callable *self=(Callable *)type->tp_alloc(type,0); if(!self) return NULL;
    self->native=jacpy_lru_new();
    if(jacpy_lru_init(self->native,H(fn),maximum,typed,H(info),H(m->hashed),H(m->marker))<0) { Py_DECREF(self); return NULL; }
    return (PyObject *)self;
}
static PyObject *lru_call(PyObject *op,PyObject *args,PyObject *kw) {
    if(Py_EnterRecursiveCall(" while calling a Python object")) return NULL;
    PyObject *result=O(jacpy_lru_call(((Callable *)op)->native,H(args),H(kw))); Py_LeaveRecursiveCall(); return result;
}
static PyObject *lru_cache_clear(PyObject *op,PyObject *unused) { if(jacpy_lru_clear(((Callable *)op)->native)<0) return NULL; Py_RETURN_NONE; }
static PyObject *lru_cache_info(PyObject *op,PyObject *unused) { return O(jacpy_lru_info(((Callable *)op)->native)); }
static PyObject *lru_reduce(PyObject *op,PyObject *unused) { return PyObject_GetAttrString(op,"__qualname__"); }
static PyObject *lru_copy(PyObject *op,PyObject *unused) { return Py_NewRef(op); }
static PyMethodDef lru_methods[]={
    {"cache_clear",lru_cache_clear,METH_NOARGS,"cache_clear($self, /)\n--\n\nClear the cache and cache statistics"},
    {"cache_info",lru_cache_info,METH_NOARGS,"cache_info($self, /)\n--\n\nReport cache statistics"},
    {"__reduce__",lru_reduce,METH_NOARGS},{"__copy__",lru_copy,METH_VARARGS},{"__deepcopy__",lru_copy,METH_VARARGS},{NULL}};
static PyType_Slot lru_slots[]={
    {Py_tp_new,lru_new},{Py_tp_dealloc,callable_dealloc},{Py_tp_call,lru_call},{Py_tp_traverse,lru_traverse},
    {Py_tp_clear,lru_clear},{Py_tp_methods,lru_methods},{Py_tp_members,callable_members},{Py_tp_getset,lru_getset},
    {Py_tp_descr_get,bind},{Py_tp_doc,"Create a cached callable that wraps another function."},{0}};
static PyType_Spec lru_spec={"functools._lru_cache_wrapper",sizeof(Callable),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_BASETYPE|Py_TPFLAGS_IMMUTABLETYPE,lru_slots};

static PyObject *placeholder_new(PyTypeObject *type,PyObject *args,PyObject *kw) {
    if(PyTuple_GET_SIZE(args) || (kw && PyDict_GET_SIZE(kw))) { PyErr_SetString(PyExc_TypeError,"Placeholder takes no arguments"); return NULL; }
    Module *m=module_for(type); return m ? Py_NewRef(m->placeholder) : NULL;
}
static PyObject *placeholder_repr(PyObject *op) { return PyUnicode_FromString("Placeholder"); }
static PyObject *placeholder_reduce(PyObject *op,PyObject *unused) { return PyUnicode_FromString("Placeholder"); }
static int placeholder_traverse(PyObject *op,visitproc visit,void *arg) { Py_VISIT(Py_TYPE(op)); return 0; }
static void placeholder_dealloc(PyObject *op) { PyTypeObject *type=Py_TYPE(op); PyObject_GC_UnTrack(op); type->tp_free(op); Py_DECREF(type); }
static PyMethodDef placeholder_methods[]={{"__reduce__",placeholder_reduce,METH_NOARGS},{NULL}};
static PyType_Slot placeholder_slots[]={
    {Py_tp_new,placeholder_new},{Py_tp_repr,placeholder_repr},{Py_tp_methods,placeholder_methods},
    {Py_tp_traverse,placeholder_traverse},{Py_tp_dealloc,placeholder_dealloc},{0}};
static PyType_Spec placeholder_spec={"functools._PlaceholderType",sizeof(PyObject),0,Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_GC|Py_TPFLAGS_IMMUTABLETYPE,placeholder_slots};
static PyObject *reduce_method(PyObject *module,PyObject *args,PyObject *kw) {
    static char *names[]={"","","initial",NULL}; PyObject *fn,*iterable,*initial=NULL;
    if(!PyArg_ParseTupleAndKeywords(args,kw,"OO|O:reduce",names,&fn,&iterable,&initial)) return NULL;
    return O(jacpy_reduce(H(fn),H(iterable),H(initial)));
}
static PyObject *cmp_method(PyObject *module,PyObject *args,PyObject *kw) {
    static char *names[]={"mycmp",NULL}; PyObject *compare;
    if(!PyArg_ParseTupleAndKeywords(args,kw,"O:cmp_to_key",names,&compare)) return NULL;
    Module *m=PyModule_GetState(module); return key_new((PyTypeObject *)m->key,compare,NULL);
}
static PyMethodDef methods[]={
    {"reduce",KW(reduce_method),METH_VARARGS|METH_KEYWORDS,"reduce($module, function, iterable, /, initial=<unrepresentable>)\n--\n\nApply a function of two arguments cumulatively to the items of an iterable."},
    {"cmp_to_key",KW(cmp_method),METH_VARARGS|METH_KEYWORDS,"cmp_to_key($module, /, mycmp)\n--\n\nConvert a cmp= function into a key= function."},{NULL}};
static int module_traverse(PyObject *op,visitproc visit,void *arg) {
    Module *m=PyModule_GetState(op); Py_VISIT(m->partial); Py_VISIT(m->key); Py_VISIT(m->lru);
    Py_VISIT(m->hashed); Py_VISIT(m->placeholder_type); Py_VISIT(m->placeholder); Py_VISIT(m->marker); return 0;
}
static int module_clear(PyObject *op) {
    Module *m=PyModule_GetState(op); Py_CLEAR(m->partial); Py_CLEAR(m->key); Py_CLEAR(m->lru);
    Py_CLEAR(m->hashed); Py_CLEAR(m->placeholder_type); Py_CLEAR(m->placeholder); Py_CLEAR(m->marker); return 0;
}
static int module_exec(PyObject *op) {
    Module *m=PyModule_GetState(op);
    m->partial=PyType_FromModuleAndSpec(op,&partial_spec,NULL); if(!m->partial) return -1;
    m->key=PyType_FromModuleAndSpec(op,&key_spec,NULL); if(!m->key) return -1;
    m->lru=PyType_FromModuleAndSpec(op,&lru_spec,NULL); if(!m->lru) return -1;
    m->hashed=PyType_FromModuleAndSpec(op,&hashed_spec,NULL); if(!m->hashed) return -1;
    m->placeholder_type=PyType_FromModuleAndSpec(op,&placeholder_spec,NULL); if(!m->placeholder_type) return -1;
    m->placeholder=((PyTypeObject *)m->placeholder_type)->tp_alloc((PyTypeObject *)m->placeholder_type,0); if(!m->placeholder) return -1;
    m->marker=PyObject_CallNoArgs((PyObject *)&PyBaseObject_Type); if(!m->marker) return -1;
    if(PyModule_AddObjectRef(op,"partial",m->partial)<0 || PyModule_AddObjectRef(op,"_lru_cache_wrapper",m->lru)<0 || PyModule_AddObjectRef(op,"Placeholder",m->placeholder)<0) return -1;
    return 0;
}
static PyModuleDef_Slot module_slots[]={{Py_mod_exec,module_exec},{Py_mod_multiple_interpreters,Py_MOD_PER_INTERPRETER_GIL_SUPPORTED},{0}};
static PyModuleDef definition={PyModuleDef_HEAD_INIT,"_functools","Native Jac callable policies.",sizeof(Module),methods,module_slots,module_traverse,module_clear,NULL};
PyMODINIT_FUNC PyInit__functools(void) { return PyModuleDef_Init(&definition); }
