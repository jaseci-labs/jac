import from c {
    obj CFieldScratch {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut CFieldScratch) -> int;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def strlen(text: ptr[u8]) -> u64;  def wcslen(s: ptr[i32]) -> u64;  def NUM_BITS(
        bitsize: i64
    ) -> i64 {
        return bitsize >> 16;
    }  def LOW_BIT(offset: i64) -> i64 {
        return offset & 0xFFFF;
    }  glob:priv PyCField_getset: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("size"),
                 get=PyCField_get_legacy_size,
                 doc=ptr[u8](
                     "size in bytes of this field. For bitfields, this is a legacy packed value; use byte_size instead"
                 )
             ),
             PyGetSetDef(
                 name=ptr[u8]("bit_size"),
                 get=PyCField_get_bit_size,
                 doc=ptr[u8]("size of this field in bits")
             ),
             PyGetSetDef(
                 name=ptr[u8]("is_bitfield"),
                 get=PyCField_is_bitfield,
                 doc=ptr[u8]("true if this is a bitfield")
             ),
             PyGetSetDef(
                 name=ptr[u8]("is_anonymous"),
                 get=PyCField_is_anonymous,
                 doc=ptr[u8]("true if this field is anonymous")
             ),
             PyGetSetDef()
         ],
         PyCField_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("name"),
                 type_=Py_T_OBJECT_EX,
                 offset=CFIELD_NAME,
                 flags=Py_READONLY,
                 doc=ptr[u8]("name of this field")
             ),
             PyMemberDef(
                 name=ptr[u8]("type"),
                 type_=Py_T_OBJECT_EX,
                 offset=CFIELD_PROTO,
                 flags=Py_READONLY,
                 doc=ptr[u8]("type of this field")
             ),
             PyMemberDef(
                 name=ptr[u8]("offset"),
                 type_=Py_T_PYSSIZET,
                 offset=CFIELD_BYTE_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("offset in bytes of this field (same as byte_offset)")
             ),
             PyMemberDef(
                 name=ptr[u8]("byte_offset"),
                 type_=Py_T_PYSSIZET,
                 offset=CFIELD_BYTE_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8](
                     "offset in bytes of this field. For bitfields: excludes bit_offset."
                 )
             ),
             PyMemberDef(
                 name=ptr[u8]("byte_size"),
                 type_=Py_T_PYSSIZET,
                 offset=CFIELD_BYTE_SIZE,
                 flags=Py_READONLY,
                 doc=ptr[u8]("size of this field in bytes")
             ),
             PyMemberDef(
                 name=ptr[u8]("bit_offset"),
                 type_=Py_T_UBYTE,
                 offset=CFIELD_BIT_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8](
                     "additional offset in bits (relative to byte_offset); zero for non-bitfields"
                 )
             ),
             PyMemberDef()
         ],
         cfield_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(PyCField_new_new)),
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(PyCField_dealloc)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(PyCField_repr)),
             PyType_Slot(slot=Py_tp_doc, pfunc=ptr[u8]("Structure/Union member")),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(PyCField_traverse)),
             PyType_Slot(slot=Py_tp_clear, pfunc=ptr(PyCField_clear)),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(PyCField_getset))),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(PyCField_members))),
             PyType_Slot(slot=Py_tp_descr_get, pfunc=ptr(PyCField_get)),
             PyType_Slot(slot=Py_tp_descr_set, pfunc=ptr(PyCField_set)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob cfield_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("ctypes.CField"),
             basicsize=80,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(cfield_slots)
         ); glob:priv fmt_i8: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_u8: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_i16: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_u16: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_i32: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_u32: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_i64: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_u64: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_s: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_b: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_B: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_c: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_d: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_F: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_D: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_G: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_g: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_f: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_h: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_H: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_i: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_I: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_l: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_L: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_q: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_Q: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_P: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_z: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_u: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_U: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_Z: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_X: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_v: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_O: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_bool: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         fmt_nil: fielddesc = fielddesc(
             code=0,
             pffi_type=ptr[ffi_type](),
             setfunc=ptr(),
             getfunc=ptr(),
             setfunc_swapped=ptr(),
             getfunc_swapped=ptr()
         ),
         simple_type_chars: list[u8] = [
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0),
             u8(0)
         ]; def _ctypes_init_fielddesc {
        longdouble_type = addressof(ffi_type_double);
        complex_longdouble_type = addressof(ffi_type_complex_double);
        if not LONG_DOUBLE_IS_DOUBLE {
            longdouble_type = ptr[ffi_type](ffi_type_longdouble_ref());
            complex_longdouble_type = ptr[ffi_type](ffi_type_complex_longdouble_ref());
        }
        set_fielddesc(
            addressof(fmt_i8),
            0,
            addressof(ffi_type_sint8),
            ptr(i8_set),
            ptr(i8_get),
            ptr(i8_set),
            ptr(i8_get)
        );
        set_fielddesc(
            addressof(fmt_u8),
            0,
            addressof(ffi_type_uint8),
            ptr(u8_set),
            ptr(u8_get),
            ptr(u8_set),
            ptr(u8_get)
        );
        set_fielddesc(
            addressof(fmt_i16),
            0,
            addressof(ffi_type_sint16),
            ptr(i16_set),
            ptr(i16_get),
            ptr(i16_set_sw),
            ptr(i16_get_sw)
        );
        set_fielddesc(
            addressof(fmt_u16),
            0,
            addressof(ffi_type_uint16),
            ptr(u16_set),
            ptr(u16_get),
            ptr(u16_set_sw),
            ptr(u16_get_sw)
        );
        set_fielddesc(
            addressof(fmt_i32),
            0,
            addressof(ffi_type_sint32),
            ptr(i32_set),
            ptr(i32_get),
            ptr(i32_set_sw),
            ptr(i32_get_sw)
        );
        set_fielddesc(
            addressof(fmt_u32),
            0,
            addressof(ffi_type_uint32),
            ptr(u32_set),
            ptr(u32_get),
            ptr(u32_set_sw),
            ptr(u32_get_sw)
        );
        set_fielddesc(
            addressof(fmt_i64),
            0,
            addressof(ffi_type_sint64),
            ptr(i64_set),
            ptr(i64_get),
            ptr(i64_set_sw),
            ptr(i64_get_sw)
        );
        set_fielddesc(
            addressof(fmt_u64),
            0,
            addressof(ffi_type_uint64),
            ptr(u64_set),
            ptr(u64_get),
            ptr(u64_set_sw),
            ptr(u64_get_sw)
        );

        copy_fielddesc(addressof(fmt_b), _ctypes_fixint_fielddesc(1, True));
        addressof(fmt_b).view(1)[0].code = 98;
        addressof(fmt_b).view(1)[0].pffi_type = addressof(ffi_type_sint8);
        copy_fielddesc(addressof(fmt_B), _ctypes_fixint_fielddesc(1, False));
        addressof(fmt_B).view(1)[0].code = 66;
        addressof(fmt_B).view(1)[0].pffi_type = addressof(ffi_type_uint8);
        copy_fielddesc(addressof(fmt_h), _ctypes_fixint_fielddesc(2, True));
        addressof(fmt_h).view(1)[0].code = 104;
        addressof(fmt_h).view(1)[0].pffi_type = addressof(ffi_type_sint16);
        copy_fielddesc(addressof(fmt_H), _ctypes_fixint_fielddesc(2, False));
        addressof(fmt_H).view(1)[0].code = 72;
        addressof(fmt_H).view(1)[0].pffi_type = addressof(ffi_type_uint16);
        copy_fielddesc(addressof(fmt_i), _ctypes_fixint_fielddesc(4, True));
        addressof(fmt_i).view(1)[0].code = 105;
        addressof(fmt_i).view(1)[0].pffi_type = addressof(ffi_type_sint32);
        copy_fielddesc(addressof(fmt_I), _ctypes_fixint_fielddesc(4, False));
        addressof(fmt_I).view(1)[0].code = 73;
        addressof(fmt_I).view(1)[0].pffi_type = addressof(ffi_type_uint32);
        copy_fielddesc(addressof(fmt_l), _ctypes_fixint_fielddesc(8, True));
        addressof(fmt_l).view(1)[0].code = 108;
        addressof(fmt_l).view(1)[0].pffi_type = addressof(ffi_type_sint64);
        copy_fielddesc(addressof(fmt_L), _ctypes_fixint_fielddesc(8, False));
        addressof(fmt_L).view(1)[0].code = 76;
        addressof(fmt_L).view(1)[0].pffi_type = addressof(ffi_type_uint64);
        copy_fielddesc(addressof(fmt_q), _ctypes_fixint_fielddesc(8, True));
        addressof(fmt_q).view(1)[0].code = 113;
        copy_fielddesc(addressof(fmt_Q), _ctypes_fixint_fielddesc(8, False));
        addressof(fmt_Q).view(1)[0].code = 81;

        set_fielddesc(
            addressof(fmt_d),
            100,
            addressof(ffi_type_double),
            ptr(d_set),
            ptr(d_get),
            ptr(d_set_sw),
            ptr(d_get_sw)
        );
        if Py_FFI_COMPLEX_AVAILABLE {
            set_fielddesc(
                addressof(fmt_D),
                68,
                addressof(ffi_type_complex_double),
                ptr(D_set),
                ptr(D_get),
                ptr(D_set_sw),
                ptr(D_get_sw)
            );
            set_fielddesc(
                addressof(fmt_F),
                70,
                addressof(ffi_type_complex_float),
                ptr(F_set),
                ptr(F_get),
                ptr(F_set_sw),
                ptr(F_get_sw)
            );
            set_fielddesc(
                addressof(fmt_G),
                71,
                complex_longdouble_type,
                ptr(G_set),
                ptr(G_get),
                ptr(),
                ptr()
            );
        }
        set_fielddesc(
            addressof(fmt_g), 103, longdouble_type, ptr(g_set), ptr(g_get), ptr(), ptr()
        );
        set_fielddesc(
            addressof(fmt_f),
            102,
            addressof(ffi_type_float),
            ptr(f_set),
            ptr(f_get),
            ptr(f_set_sw),
            ptr(f_get_sw)
        );

        set_fielddesc(
            addressof(fmt_v),
            118,
            addressof(ffi_type_sint16),
            ptr(v_set),
            ptr(v_get),
            ptr(),
            ptr()
        );

        set_fielddesc(
            addressof(fmt_c),
            99,
            _ctypes_fixint_fielddesc(1, True).view(1)[0].pffi_type,
            ptr(c_set),
            ptr(c_get),
            ptr(),
            ptr()
        );

        set_fielddesc(
            addressof(fmt_u),
            117,
            _ctypes_fixint_fielddesc(SIZEOF_WCHAR_T, True).view(1)[0].pffi_type,
            ptr(u_set),
            ptr(u_get),
            ptr(),
            ptr()
        );

        set_fielddesc(
            addressof(fmt_s),
            115,
            addressof(ffi_type_pointer),
            ptr(s_set),
            ptr(s_get),
            ptr(),
            ptr()
        );
        set_fielddesc(
            addressof(fmt_P),
            80,
            addressof(ffi_type_pointer),
            ptr(P_set),
            ptr(P_get),
            ptr(),
            ptr()
        );
        set_fielddesc(
            addressof(fmt_z),
            122,
            addressof(ffi_type_pointer),
            ptr(z_set),
            ptr(z_get),
            ptr(),
            ptr()
        );
        set_fielddesc(
            addressof(fmt_U),
            85,
            addressof(ffi_type_pointer),
            ptr(U_set),
            ptr(U_get),
            ptr(),
            ptr()
        );
        set_fielddesc(
            addressof(fmt_Z),
            90,
            addressof(ffi_type_pointer),
            ptr(Z_set),
            ptr(Z_get),
            ptr(),
            ptr()
        );
        set_fielddesc(
            addressof(fmt_O),
            79,
            addressof(ffi_type_pointer),
            ptr(O_set),
            ptr(O_get),
            ptr(),
            ptr()
        );

        copy_fielddesc(addressof(fmt_bool), _ctypes_fixint_fielddesc(1, False));
        addressof(fmt_bool).view(1)[0].code = 63;
        addressof(fmt_bool).view(1)[0].setfunc = ptr(bool_set);
        addressof(fmt_bool).view(1)[0].getfunc = ptr(bool_get);

        chars = ptr[u8](addressof(simple_type_chars));
        i: i64 = 0;
        i = add_simple_type_char(chars, i, addressof(fmt_c), 99);
        i = add_simple_type_char(chars, i, addressof(fmt_b), 98);
        i = add_simple_type_char(chars, i, addressof(fmt_B), 66);
        i = add_simple_type_char(chars, i, addressof(fmt_h), 104);
        i = add_simple_type_char(chars, i, addressof(fmt_H), 72);
        i = add_simple_type_char(chars, i, addressof(fmt_i), 105);
        i = add_simple_type_char(chars, i, addressof(fmt_I), 73);
        i = add_simple_type_char(chars, i, addressof(fmt_l), 108);
        i = add_simple_type_char(chars, i, addressof(fmt_L), 76);
        i = add_simple_type_char(chars, i, addressof(fmt_d), 100);
        i = add_simple_type_char(chars, i, addressof(fmt_D), 68);
        i = add_simple_type_char(chars, i, addressof(fmt_F), 70);
        i = add_simple_type_char(chars, i, addressof(fmt_G), 71);
        i = add_simple_type_char(chars, i, addressof(fmt_f), 102);
        i = add_simple_type_char(chars, i, addressof(fmt_u), 117);
        i = add_simple_type_char(chars, i, addressof(fmt_z), 122);
        i = add_simple_type_char(chars, i, addressof(fmt_Z), 90);
        i = add_simple_type_char(chars, i, addressof(fmt_q), 113);
        i = add_simple_type_char(chars, i, addressof(fmt_Q), 81);
        i = add_simple_type_char(chars, i, addressof(fmt_P), 80);
        i = add_simple_type_char(chars, i, addressof(fmt_X), 88);
        i = add_simple_type_char(chars, i, addressof(fmt_O), 79);
        i = add_simple_type_char(chars, i, addressof(fmt_v), 118);
        i = add_simple_type_char(chars, i, addressof(fmt_bool), 63);
        i = add_simple_type_char(chars, i, addressof(fmt_g), 103);
        (chars + i).view(1)[0] = 0;
    }  def _ctypes_get_simple_type_chars -> ptr[u8] {
        return ptr[u8](addressof(simple_type_chars));
    }  def _ctypes_get_fielddesc(fmt: ptr[u8]) -> ptr[fielddesc] {
        result = ptr[fielddesc]();
        code = fmt.view(1)[0];
        if code == 115 {
            result = addressof(fmt_s);
        } elif code == 98 {
            result = addressof(fmt_b);
        } elif code == 66 {
            result = addressof(fmt_B);
        } elif code == 99 {
            result = addressof(fmt_c);
        } elif code == 100 {
            result = addressof(fmt_d);
        } elif code == 68 {
            result = addressof(fmt_D);
        } elif code == 70 {
            result = addressof(fmt_F);
        } elif code == 71 {
            result = addressof(fmt_G);
        } elif code == 103 {
            result = addressof(fmt_g);
        } elif code == 102 {
            result = addressof(fmt_f);
        } elif code == 104 {
            result = addressof(fmt_h);
        } elif code == 72 {
            result = addressof(fmt_H);
        } elif code == 105 {
            result = addressof(fmt_i);
        } elif code == 73 {
            result = addressof(fmt_I);
        } elif code == 108 {
            result = addressof(fmt_l);
        } elif code == 76 {
            result = addressof(fmt_L);
        } elif code == 113 {
            result = addressof(fmt_q);
        } elif code == 81 {
            result = addressof(fmt_Q);
        } elif code == 80 {
            result = addressof(fmt_P);
        } elif code == 122 {
            result = addressof(fmt_z);
        } elif code == 117 {
            result = addressof(fmt_u);
        } elif code == 85 {
            result = addressof(fmt_U);
        } elif code == 90 {
            result = addressof(fmt_Z);
        } elif code == 88 {
            result = addressof(fmt_X);
        } elif code == 118 {
            result = addressof(fmt_v);
        } elif code == 79 {
            result = addressof(fmt_O);
        } elif code == 63 {
            result = addressof(fmt_bool);
        }
        if not result {
            return ptr[fielddesc]();
        }
        if result.view(1)[0].code == 0 {
            return ptr[fielddesc]();
        }
        return result;
    }
}

glob:priv CFIELD_ASNATIVEBYTES_FLAGS: Final[i32] = 19,
     SIZEOF_WCHAR_T: Final[i64] = 4,
     PY_SSIZE_T_MAX_DIV_8: Final[i64] = 1152921504606846975,
     VARIANT_FALSE: Final[i16] = 0,
     VARIANT_TRUE: Final[i16] = -1;

def pymem_destructor(capsule: ptr[PyObject]);

def PyCField_new_impl(
    type: ptr[PyObject],
    name: ptr[PyObject],
    proto: ptr[PyObject],
    byte_size: i64,
    byte_offset: i64,
    index: i64,
    _internal_use: bool,
    bit_size_obj: ptr[PyObject],
    bit_offset_obj: ptr[PyObject]
) -> ptr[PyObject];

def _pack_legacy_size(field: ptr[CFieldObject]) -> i64;

def PyCField_set_lock_held(
    op: ptr[PyObject], inst: ptr[PyObject], value: ptr[PyObject]
) -> i32;

def PyCField_set(op: ptr[PyObject], inst: ptr[PyObject], value: ptr[PyObject]) -> i32;

def PyCField_get(
    op: ptr[PyObject], inst: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject];

def PyCField_get_legacy_size(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def PyCField_get_bit_size(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def PyCField_is_bitfield(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def PyCField_is_anonymous(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def PyCField_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def PyCField_clear(op: ptr[PyObject]) -> i32;

def PyCField_dealloc(self_: ptr[PyObject]);

def PyCField_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def load_bits(src: ptr, nbytes: i64) -> u64;

def store_bits(dst: ptr, nbytes: i64, bits: u64);

def load_f64(src: ptr) -> f64;

def store_f64(dst: ptr, value: f64);

def load_f32(src: ptr) -> f32;

def store_f32(dst: ptr, value: f32);

def low_mask(nbits: i64) -> u64;

def set_bits(prev: u64, v: u64, size: i64, width: i64) -> u64;

def get_bits_unsigned(v: u64, size: i64) -> u64;

def sign_extend(v: u64, nbits: i64) -> i64;

def get_bits_signed(v: u64, size: i64, width: i64) -> i64;

def bswap16(v: u64) -> u64;

def bswap32(v: u64) -> u64;

def bswap64(v: u64) -> u64;

def fixint_value(value: ptr[PyObject], nbytes: i64) -> tuple[i32, u64];

def fixint_set(
    ptr_: ptr, value: ptr[PyObject], size_arg: i64, nbytes: i64
) -> ptr[PyObject];

def i8_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i8_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u8_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u8_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i16_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i16_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i16_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i16_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u16_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u16_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u16_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u16_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i32_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i32_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i32_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i32_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u32_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u32_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u32_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u32_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i64_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i64_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def i64_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def i64_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u64_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u64_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def u64_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject];

def u64_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject];

def v_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def v_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def bool_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def bool_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def g_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def g_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def d_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def d_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def D_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def D_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def D_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def D_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject];

def F_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def F_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def F_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def F_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject];

def G_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def G_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def d_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def d_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject];

def f_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def f_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def f_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def f_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject];

def O_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def O_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def c_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def c_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def u_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def u_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def U_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def U_set(ptr_: ptr, value: ptr[PyObject], length: i64) -> ptr[PyObject];

def s_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def s_set(ptr_: ptr, value: ptr[PyObject], length: i64) -> ptr[PyObject];

def z_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def z_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def Z_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def Z_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def P_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject];

def P_get(ptr_: ptr, size: i64) -> ptr[PyObject];

def _ctypes_fixint_fielddesc(nbytes: i64, is_signed: bool) -> ptr[fielddesc];

def set_fielddesc(
    fd: ptr[fielddesc],
    code: u8,
    pffi_type: ptr[ffi_type],
    setfunc: ptr,
    getfunc: ptr,
    setfunc_swapped: ptr,
    getfunc_swapped: ptr
);

def copy_fielddesc(dst: ptr[fielddesc], src: ptr[fielddesc]);

def add_simple_type_char(chars: ptr[u8], i: i64, fd: ptr[fielddesc], code: u8) -> i64;

impl pymem_destructor(capsule: ptr[PyObject]) {
    p = PyCapsule_GetPointer(capsule, ptr[u8]("_ctypes/cfield.c pymem"));
    if p {
        PyMem_Free(p);
    }
}

impl PyCField_new_impl(
    type: ptr[PyObject],
    name: ptr[PyObject],
    proto: ptr[PyObject],
    byte_size: i64,
    byte_offset: i64,
    index: i64,
    _internal_use: bool,
    bit_size_obj: ptr[PyObject],
    bit_offset_obj: ptr[PyObject]
) -> ptr[PyObject] {
    if not _internal_use {
        PyErr_Format(PyExc_TypeError, ptr[u8]("cannot create %T object"), type);
        return NULL;
    }
    if byte_size < 0 {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("byte size of field %R must not be negative, got %zd"),
            name,
            byte_size
        );
        return NULL;
    }

    st = get_module_state_by_class(ptr[PyTypeObject](type));
    (res, info) = PyStgInfo_FromType(st, proto);
    if res < 0 {
        return NULL;
    }
    if not info {
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("type of field %R must be a C type"), name
        );
        return NULL;
    }
    info_size = info.view(1)[0].size;
    if byte_size != info_size {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("byte size of field %R (%zd) does not match type size (%zd)"),
            name,
            byte_size,
            info_size
        );
        return NULL;
    }

    bitfield_size: i64 = 0;
    bit_offset: i64 = 0;
    if bit_size_obj != Py_None {
        ffi_kind = stginfo_ffi_type(info).view(1)[0].type;
        allowed = False;
        if ffi_kind == FFI_TYPE_UINT8
            or ffi_kind == FFI_TYPE_UINT16
            or ffi_kind == FFI_TYPE_UINT32
            or ffi_kind == FFI_TYPE_SINT64
            or ffi_kind == FFI_TYPE_UINT64 {
            allowed = True;
        } elif ffi_kind == FFI_TYPE_SINT8
            or ffi_kind == FFI_TYPE_SINT16
            or ffi_kind == FFI_TYPE_SINT32 {
            getfunc = int(info.view(1)[0].getfunc);
            char_getfunc = int(_ctypes_get_fielddesc(ptr[u8]("c")).view(1)[0].getfunc);
            wchar_getfunc = int(_ctypes_get_fielddesc(ptr[u8]("u")).view(1)[0].getfunc);
            if getfunc != char_getfunc and getfunc != wchar_getfunc {
                allowed = True;
            }
        }
        if not allowed {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("bit fields not allowed for type %s"),
                ptr[PyTypeObject](proto).view(1)[0].tp_name
            );
            return NULL;
        }

        if byte_size > 100 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("bit field %R size too large, got %zd"),
                name,
                byte_size
            );
            return NULL;
        }
        bitfield_size = PyLong_AsSsize_t(bit_size_obj);
        if bitfield_size <= 0 or bitfield_size > 255 {
            if not PyErr_Occurred() {
                PyErr_Format(
                    PyExc_ValueError,
                    ptr[u8]("bit size of field %R out of range, got %zd"),
                    name,
                    bitfield_size
                );
            }
            return NULL;
        }
        bit_offset = PyLong_AsSsize_t(bit_offset_obj);
        if bit_offset < 0 or bit_offset > 255 {
            if not PyErr_Occurred() {
                PyErr_Format(
                    PyExc_ValueError,
                    ptr[u8]("bit offset of field %R out of range, got %zd"),
                    name,
                    bit_offset
                );
            }
            return NULL;
        }
        total_bits = byte_size * 8;
        if (bitfield_size + bit_offset) > total_bits {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("bit field %R overflows its type (%zd + %zd > %zd)"),
                name,
                bit_offset,
                bitfield_size,
                total_bits
            );
            return NULL;
        }
    } elif bit_offset_obj != Py_None {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("field %R: bit_offset must be specified if bit_size is"),
            name
        );
        return NULL;
    }

    tp = ptr[PyTypeObject](type);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        return NULL;
    }
    self_ = ptr[CFieldObject](op);
    field_name = PyUnicode_FromObject(name);
    self_.view(1)[0].name = field_name;
    if not field_name {
        object_decref(op);
        return NULL;
    }

    self_.view(1)[0].proto = object_new_ref(proto);
    self_.view(1)[0].byte_size = byte_size;
    self_.view(1)[0].byte_offset = byte_offset;
    self_.view(1)[0].bitfield_size = u8.wrap(bitfield_size);
    self_.view(1)[0].bit_offset = u8.wrap(bit_offset);

    self_.view(1)[0].index = index;

    self_.view(1)[0].setfunc = ptr();
    self_.view(1)[0].getfunc = ptr();
    if PyCArrayTypeObject_Check(st, proto) {
        (ares, ainfo) = PyStgInfo_FromType(st, proto);
        if ares < 0 {
            object_decref(op);
            return NULL;
        }
        if ainfo and ainfo.view(1)[0].proto {
            (ires, iinfo) = PyStgInfo_FromType(st, ainfo.view(1)[0].proto);
            if ires < 0 {
                object_decref(op);
                return NULL;
            }
            if not iinfo {
                PyErr_SetString(PyExc_TypeError, ptr[u8]("has no _stginfo_"));
                object_decref(op);
                return NULL;
            }
            item_getfunc = int(iinfo.view(1)[0].getfunc);
            if item_getfunc
                == int(_ctypes_get_fielddesc(ptr[u8]("c")).view(1)[0].getfunc) {
                fd = _ctypes_get_fielddesc(ptr[u8]("s"));
                self_.view(1)[0].getfunc = fd.view(1)[0].getfunc;
                self_.view(1)[0].setfunc = fd.view(1)[0].setfunc;
            }
            if item_getfunc
                == int(_ctypes_get_fielddesc(ptr[u8]("u")).view(1)[0].getfunc) {
                wfd = _ctypes_get_fielddesc(ptr[u8]("U"));
                self_.view(1)[0].getfunc = wfd.view(1)[0].getfunc;
                self_.view(1)[0].setfunc = wfd.view(1)[0].setfunc;
            }
        }
    }

    return op;
}

impl _pack_legacy_size(field: ptr[CFieldObject]) -> i64 {
    if field.view(1)[0].bitfield_size != 0 {
        bit_offset = i64(field.view(1)[0].bit_offset);
        return (i64(field.view(1)[0].bitfield_size) << 16) | bit_offset;
    }
    return field.view(1)[0].byte_size;
}

impl PyCField_set_lock_held(
    op: ptr[PyObject], inst: ptr[PyObject], value: ptr[PyObject]
) -> i32 {
    self_ = ptr[CFieldObject](op);
    st = get_module_state_by_class(object_type(op));
    if not CDataObject_Check(st, inst) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("not a ctype instance"));
        return -1;
    }
    dst = ptr[CDataObject](inst);
    adr = dst.view(1)[0].b_ptr + self_.view(1)[0].byte_offset;
    if not value {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("can't delete attribute"));
        return -1;
    }
    return PyCData_set(
        st,
        inst,
        self_.view(1)[0].proto,
        self_.view(1)[0].setfunc,
        value,
        self_.view(1)[0].index,
        _pack_legacy_size(self_),
        adr
    );
}

impl PyCField_set(op: ptr[PyObject], inst: ptr[PyObject], value: ptr[PyObject]) -> i32 {
    return PyCField_set_lock_held(op, inst, value);
}

impl PyCField_get(
    op: ptr[PyObject], inst: ptr[PyObject], type: ptr[PyObject]
) -> ptr[PyObject] {
    self_ = ptr[CFieldObject](op);
    if not inst {
        return object_new_ref(op);
    }
    st = get_module_state_by_class(object_type(op));
    if not CDataObject_Check(st, inst) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("not a ctype instance"));
        return NULL;
    }
    src = ptr[CDataObject](inst);
    return PyCData_get(
        st,
        self_.view(1)[0].proto,
        self_.view(1)[0].getfunc,
        inst,
        self_.view(1)[0].index,
        _pack_legacy_size(self_),
        src.view(1)[0].b_ptr + self_.view(1)[0].byte_offset
    );
}

impl PyCField_get_legacy_size(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyLong_FromSsize_t(_pack_legacy_size(ptr[CFieldObject](self_)));
}

impl PyCField_get_bit_size(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    field = ptr[CFieldObject](self_);
    if field.view(1)[0].bitfield_size != 0 {
        return PyLong_FromSsize_t(i64(field.view(1)[0].bitfield_size));
    }
    if field.view(1)[0].byte_size < PY_SSIZE_T_MAX_DIV_8 {
        return PyLong_FromSsize_t(field.view(1)[0].byte_size * 8);
    }

    byte_size_obj = PyLong_FromSsize_t(field.view(1)[0].byte_size);
    if not byte_size_obj {
        return NULL;
    }
    eight = PyLong_FromLong(8);
    if not eight {
        object_decref(byte_size_obj);
        return NULL;
    }
    result = PyNumber_Multiply(byte_size_obj, eight);
    object_decref(byte_size_obj);
    object_decref(eight);
    return result;
}

impl PyCField_is_bitfield(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyBool_FromLong(i64(ptr[CFieldObject](self_).view(1)[0].bitfield_size));
}

impl PyCField_is_anonymous(self_: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return PyBool_FromLong(i64(ptr[CFieldObject](self_).view(1)[0].anonymous));
}

impl PyCField_traverse(op: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    self_ = ptr[CFieldObject](op);
    status = visit_reference(ptr[PyObject](object_type(op)), visitor, arg);
    if status != 0 {
        return status;
    }
    status = visit_reference(self_.view(1)[0].proto, visitor, arg);
    if status != 0 {
        return status;
    }
    return 0;
}

impl PyCField_clear(op: ptr[PyObject]) -> i32 {
    self_ = ptr[CFieldObject](op);
    proto = self_.view(1)[0].proto;
    self_.view(1)[0].proto = NULL;
    object_xdecref(proto);
    name = self_.view(1)[0].name;
    self_.view(1)[0].name = NULL;
    object_xdecref(name);
    return 0;
}

impl PyCField_dealloc(self_: ptr[PyObject]) {
    tp = object_type(self_);
    PyObject_GC_UnTrack(ptr(self_));
    PyCField_clear(self_);
    object_type(self_).view(1)[0].tp_free(ptr(self_));
    object_decref(ptr[PyObject](tp));
}

impl PyCField_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    field = ptr[CFieldObject](self_);
    tp_name = ptr[PyTypeObject](field.view(1)[0].proto).view(1)[0].tp_name;
    byte_offset = field.view(1)[0].byte_offset;
    if field.view(1)[0].bitfield_size != 0 {
        bitfield_size = i64(field.view(1)[0].bitfield_size);
        bit_offset = i64(field.view(1)[0].bit_offset);
        return PyUnicode_FromFormat(
            "<%T %R type=%s, ofs=%zd, bit_size=%zd, bit_offset=%zd>",
            self_,
            field.view(1)[0].name,
            tp_name,
            byte_offset,
            bitfield_size,
            bit_offset
        );
    }
    byte_size = field.view(1)[0].byte_size;
    return PyUnicode_FromFormat(
        "<%T %R type=%s, ofs=%zd, size=%zd>",
        self_,
        field.view(1)[0].name,
        tp_name,
        byte_offset,
        byte_size
    );
}

impl load_bits(src: ptr, nbytes: i64) -> u64 {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    memcpy(ptr(tmp), src, u64(nbytes));
    return ptr[u64](tmp).view(1)[0];
}

impl store_bits(dst: ptr, nbytes: i64, bits: u64) {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    ptr[u64](tmp).view(1)[0] = bits;
    memcpy(dst, ptr(tmp), u64(nbytes));
}

impl load_f64(src: ptr) -> f64 {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    memcpy(ptr(tmp), src, u64(8));
    return ptr[f64](tmp).view(1)[0];
}

impl store_f64(dst: ptr, value: f64) {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    ptr[f64](tmp).view(1)[0] = value;
    memcpy(dst, ptr(tmp), u64(8));
}

impl load_f32(src: ptr) -> f32 {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    memcpy(ptr(tmp), src, u64(4));
    return ptr[f32](tmp).view(1)[0];
}

impl store_f32(dst: ptr, value: f32) {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    ptr[f32](tmp).view(1)[0] = value;
    memcpy(dst, ptr(tmp), u64(4));
}

impl low_mask(nbits: i64) -> u64 {
    if nbits >= 64 {
        return ~u64(0);
    }
    return wrapping_shl(u64(1), u64(nbits)) - u64(1);
}

impl set_bits(prev: u64, v: u64, size: i64, width: i64) -> u64 {
    nbits = NUM_BITS(size);
    if nbits == 0 {
        return v & low_mask(width);
    }
    mask = low_mask(nbits);
    low = u64(LOW_BIT(size));
    result = (prev & ~wrapping_shl(mask, low)) | wrapping_shl(v & mask, low);
    return result & low_mask(width);
}

impl get_bits_unsigned(v: u64, size: i64) -> u64 {
    nbits = NUM_BITS(size);
    if nbits == 0 {
        return v;
    }
    return (v >> u64(LOW_BIT(size))) & low_mask(nbits);
}

impl sign_extend(v: u64, nbits: i64) -> i64 {
    if nbits >= 64 {
        return i64.wrap(v);
    }
    if ((v >> u64(nbits - 1)) & u64(1)) != u64(0) {
        return i64.wrap(v | ~low_mask(nbits));
    }
    return i64.wrap(v & low_mask(nbits));
}

impl get_bits_signed(v: u64, size: i64, width: i64) -> i64 {
    nbits = NUM_BITS(size);
    if nbits == 0 {
        return sign_extend(v, width);
    }
    return sign_extend((v >> u64(LOW_BIT(size))) & low_mask(nbits), nbits);
}

impl bswap16(v: u64) -> u64 {
    return ((v & u64(0xFF)) << u64(8)) | ((v >> u64(8)) & u64(0xFF));
}

impl bswap32(v: u64) -> u64 {
    return ((v & u64(0xFF)) << u64(24))
        | ((v & u64(0xFF00)) << u64(8))
        | ((v >> u64(8)) & u64(0xFF00))
        | ((v >> u64(24)) & u64(0xFF));
}

impl bswap64(v: u64) -> u64 {
    return ((v & u64(0xFF)) << u64(56))
        | ((v & u64(0xFF00)) << u64(40))
        | ((v & u64(0xFF0000)) << u64(24))
        | ((v & u64(0xFF000000)) << u64(8))
        | ((v >> u64(8)) & u64(0xFF000000))
        | ((v >> u64(24)) & u64(0xFF0000))
        | ((v >> u64(40)) & u64(0xFF00))
        | ((v >> u64(56)) & u64(0xFF));
}

impl fixint_value(value: ptr[PyObject], nbytes: i64) -> tuple[i32, u64] {
    if long_check(value) and PyUnstable_Long_IsCompact(ptr[PyLongObject](value)) != 0 {
        compact = PyUnstable_Long_CompactValue(ptr[PyLongObject](value));
        return (i32(0), u64.wrap(compact));
    }
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = PyLong_AsNativeBytes(value, ptr(tmp), nbytes, CFIELD_ASNATIVEBYTES_FLAGS);
    if res < 0 {
        return (i32(-1), u64(0));
    }
    return (i32(0), ptr[u64](tmp).view(1)[0] & low_mask(nbytes * 8));
}

impl fixint_set(
    ptr_: ptr, value: ptr[PyObject], size_arg: i64, nbytes: i64
) -> ptr[PyObject] {
    (status, val) = fixint_value(value, nbytes);
    if status < 0 {
        return NULL;
    }
    prev = load_bits(ptr_, nbytes);
    store_bits(ptr_, nbytes, set_bits(prev, val, size_arg, nbytes * 8));
    return object_new_ref(Py_None);
}

impl i8_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 1);
}

impl i8_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_signed(load_bits(ptr_, 1), size_arg, 8);
    return PyLong_FromInt32(i32.wrap(val));
}

impl u8_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 1);
}

impl u8_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_unsigned(load_bits(ptr_, 1), size_arg);
    return PyLong_FromUInt32(u32.wrap(val));
}

impl i16_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 2);
}

impl i16_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_signed(load_bits(ptr_, 2), size_arg, 16);
    return PyLong_FromInt32(i32.wrap(val));
}

impl i16_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = i16_set(ptr(tmp), value, 2);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 2);
    field = bswap16(load_bits(ptr_, 2));
    field = set_bits(field, val, size_arg, 16);
    field = bswap16(field);
    store_bits(ptr_, 2, field);
    return object_new_ref(Py_None);
}

impl i16_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_signed(bswap16(load_bits(ptr_, 2)), size_arg, 16);
    return PyLong_FromInt32(i32.wrap(val));
}

impl u16_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 2);
}

impl u16_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_unsigned(load_bits(ptr_, 2), size_arg);
    return PyLong_FromUInt32(u32.wrap(val));
}

impl u16_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = u16_set(ptr(tmp), value, 2);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 2);
    field = bswap16(load_bits(ptr_, 2));
    field = set_bits(field, val, size_arg, 16);
    field = bswap16(field);
    store_bits(ptr_, 2, field);
    return object_new_ref(Py_None);
}

impl u16_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_unsigned(bswap16(load_bits(ptr_, 2)), size_arg);
    return PyLong_FromUInt32(u32.wrap(val));
}

impl i32_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 4);
}

impl i32_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_signed(load_bits(ptr_, 4), size_arg, 32);
    return PyLong_FromInt32(i32.wrap(val));
}

impl i32_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = i32_set(ptr(tmp), value, 4);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 4);
    field = bswap32(load_bits(ptr_, 4));
    field = set_bits(field, val, size_arg, 32);
    field = bswap32(field);
    store_bits(ptr_, 4, field);
    return object_new_ref(Py_None);
}

impl i32_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_signed(bswap32(load_bits(ptr_, 4)), size_arg, 32);
    return PyLong_FromInt32(i32.wrap(val));
}

impl u32_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 4);
}

impl u32_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_unsigned(load_bits(ptr_, 4), size_arg);
    return PyLong_FromUInt32(u32.wrap(val));
}

impl u32_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = u32_set(ptr(tmp), value, 4);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 4);
    field = bswap32(load_bits(ptr_, 4));
    field = set_bits(field, val, size_arg, 32);
    field = bswap32(field);
    store_bits(ptr_, 4, field);
    return object_new_ref(Py_None);
}

impl u32_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    val = get_bits_unsigned(bswap32(load_bits(ptr_, 4)), size_arg);
    return PyLong_FromUInt32(u32.wrap(val));
}

impl i64_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 8);
}

impl i64_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    return PyLong_FromInt64(get_bits_signed(load_bits(ptr_, 8), size_arg, 64));
}

impl i64_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = i64_set(ptr(tmp), value, 8);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 8);
    field = bswap64(load_bits(ptr_, 8));
    field = set_bits(field, val, size_arg, 64);
    field = bswap64(field);
    store_bits(ptr_, 8, field);
    return object_new_ref(Py_None);
}

impl i64_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    return PyLong_FromInt64(get_bits_signed(bswap64(load_bits(ptr_, 8)), size_arg, 64));
}

impl u64_set(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    return fixint_set(ptr_, value, size_arg, 8);
}

impl u64_get(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    return PyLong_FromUInt64(get_bits_unsigned(load_bits(ptr_, 8), size_arg));
}

impl u64_set_sw(ptr_: ptr, value: ptr[PyObject], size_arg: i64) -> ptr[PyObject] {
    slots: own CFieldScratch = CFieldScratch();
    tmp = ptr[u8](jacpy_stack_address(&mut slots));
    res = u64_set(ptr(tmp), value, 8);
    if not res {
        return NULL;
    }
    object_decref(res);
    val = load_bits(ptr(tmp), 8);
    field = bswap64(load_bits(ptr_, 8));
    field = set_bits(field, val, size_arg, 64);
    field = bswap64(field);
    store_bits(ptr_, 8, field);
    return object_new_ref(Py_None);
}

impl u64_get_sw(ptr_: ptr, size_arg: i64) -> ptr[PyObject] {
    return PyLong_FromUInt64(get_bits_unsigned(bswap64(load_bits(ptr_, 8)), size_arg));
}

impl v_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    truth = PyObject_IsTrue(value);
    if truth == -1 {
        return NULL;
    }
    if truth == 0 {
        ptr[i16](ptr_).view(1)[0] = VARIANT_FALSE;
    } else {
        ptr[i16](ptr_).view(1)[0] = VARIANT_TRUE;
    }
    return object_new_ref(Py_None);
}

impl v_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyBool_FromLong(i64(ptr[i16](ptr_).view(1)[0]));
}

impl bool_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    truth = PyObject_IsTrue(value);
    if truth == -1 {
        return NULL;
    }
    if truth == 0 {
        ptr[u8](ptr_).view(1)[0] = 0;
    } else {
        ptr[u8](ptr_).view(1)[0] = 1;
    }
    return object_new_ref(Py_None);
}

impl bool_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyBool_FromLong(i64(ptr[u8](ptr_).view(1)[0]));
}

impl g_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    x = PyFloat_AsDouble(value);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    long_double_store(ptr_, x);
    return object_new_ref(Py_None);
}

impl g_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(long_double_load(ptr_));
}

impl d_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    x = PyFloat_AsDouble(value);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    store_f64(ptr_, x);
    return object_new_ref(Py_None);
}

impl d_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(load_f64(ptr_));
}

impl D_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    c = PyComplex_AsCComplex(value);
    if c.real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    store_f64(ptr_, c.real);
    store_f64(ptr(ptr[u8](ptr_) + 8), c.imag);
    return object_new_ref(Py_None);
}

impl D_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    real = load_f64(ptr_);
    imag = load_f64(ptr(ptr[u8](ptr_) + 8));
    return PyComplex_FromDoubles(real, imag);
}

impl D_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    c = PyComplex_AsCComplex(value);
    if c.real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    if PyFloat_Pack8(c.real, ptr[u8](ptr_), 0) != 0
        or PyFloat_Pack8(c.imag, ptr[u8](ptr_) + 8, 0) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl D_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject] {
    real = PyFloat_Unpack8(ptr[u8](ptr_), 0);
    imag = PyFloat_Unpack8(ptr[u8](ptr_) + 8, 0);
    return PyComplex_FromDoubles(real, imag);
}

impl F_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    c = PyComplex_AsCComplex(value);
    if c.real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    store_f32(ptr_, f32(c.real));
    store_f32(ptr(ptr[u8](ptr_) + 4), f32(c.imag));
    return object_new_ref(Py_None);
}

impl F_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    real = f64(load_f32(ptr_));
    imag = f64(load_f32(ptr(ptr[u8](ptr_) + 4)));
    return PyComplex_FromDoubles(real, imag);
}

impl F_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    c = PyComplex_AsCComplex(value);
    if c.real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    if PyFloat_Pack4(c.real, ptr[u8](ptr_), 0) != 0
        or PyFloat_Pack4(c.imag, ptr[u8](ptr_) + 4, 0) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl F_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject] {
    real = PyFloat_Unpack4(ptr[u8](ptr_), 0);
    imag = PyFloat_Unpack4(ptr[u8](ptr_) + 4, 0);
    return PyComplex_FromDoubles(real, imag);
}

impl G_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    c = PyComplex_AsCComplex(value);
    if c.real == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    long_double_store(ptr_, c.real);
    long_double_store(ptr(ptr[u8](ptr_) + SIZEOF_LONG_DOUBLE), c.imag);
    return object_new_ref(Py_None);
}

impl G_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    real = long_double_load(ptr_);
    imag = long_double_load(ptr(ptr[u8](ptr_) + SIZEOF_LONG_DOUBLE));
    return PyComplex_FromDoubles(real, imag);
}

impl d_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    x = PyFloat_AsDouble(value);
    if x == -1.0 and PyErr_Occurred() {
        return NULL;
    }
    if PyFloat_Pack8(x, ptr[u8](ptr_), 0) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl d_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(PyFloat_Unpack8(ptr[u8](ptr_), 0));
}

impl f_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    x = f32(PyFloat_AsDouble(value));
    if x == f32(-1.0) and PyErr_Occurred() {
        return NULL;
    }
    store_f32(ptr_, x);
    return object_new_ref(Py_None);
}

impl f_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(f64(load_f32(ptr_)));
}

impl f_set_sw(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    x = f32(PyFloat_AsDouble(value));
    if x == f32(-1.0) and PyErr_Occurred() {
        return NULL;
    }
    if PyFloat_Pack4(f64(x), ptr[u8](ptr_), 0) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl f_get_sw(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyFloat_FromDouble(PyFloat_Unpack4(ptr[u8](ptr_), 0));
}

impl O_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    ob = ptr[ptr[PyObject]](ptr_).view(1)[0];
    if not ob {
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("PyObject is NULL"));
        }
        return NULL;
    }
    return object_new_ref(ob);
}

impl O_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    ptr[ptr[PyObject]](ptr_).view(1)[0] = value;
    return object_new_ref(value);
}

impl c_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if bytes_check(value) {
        length = object_size(value);
        if length != 1 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "one character bytes, bytearray, or an integer in range(256) expected, not bytes of length %zd"
                ),
                length
            );
            return NULL;
        }
        ptr[u8](ptr_).view(1)[0] = PyBytes_AsString(value).view(1)[0];
        return object_new_ref(Py_None);
    }
    if bytearray_check(value) {
        array_length = object_size(value);
        if array_length != 1 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "one character bytes, bytearray, or an integer in range(256) expected, not bytearray of length %zd"
                ),
                array_length
            );
            return NULL;
        }
        ptr[u8](ptr_).view(1)[0] = PyByteArray_AsString(value).view(1)[0];
        return object_new_ref(Py_None);
    }
    if long_check(value) {
        overflow: i32 = 0;
        longval = PyLong_AsLongAndOverflow(value, &mut overflow);
        if longval == -1 and PyErr_Occurred() {
            return NULL;
        }
        if overflow != 0 or longval < 0 or longval >= 256 {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("integer not in range(256)"));
            return NULL;
        }
        ptr[u8](ptr_).view(1)[0] = u8.wrap(longval);
        return object_new_ref(Py_None);
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8](
            "one character bytes, bytearray, or an integer in range(256) expected, not %T"
        ),
        value
    );
    return NULL;
}

impl c_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyBytes_FromStringAndSize(ptr[u8](ptr_), 1);
}

impl u_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("a unicode character expected, not instance of %T"),
            value
        );
        return NULL;
    }

    slots: own CFieldScratch = CFieldScratch();
    chars = ptr[i32](jacpy_stack_address(&mut slots));
    count = PyUnicode_AsWideChar(value, chars, 2);
    if count != 1 {
        length = unicode_length(value);
        if length != 1 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("a unicode character expected, not a string of length %zd"),
                length
            );
        } else {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "the string %A cannot be converted to a single wchar_t character"
                ),
                value
            );
        }
        return NULL;
    }

    ptr[i32](ptr_).view(1)[0] = chars.view(1)[0];
    return object_new_ref(Py_None);
}

impl u_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    return PyUnicode_FromWideChar(ptr[i32](ptr_), 1);
}

impl U_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    count = size // SIZEOF_WCHAR_T;
    p = ptr[i32](ptr_);
    length: i64 = 0;
    while length < count {
        if (p + length).view(1)[0] == 0 {
            break;
        }
        length += 1;
    }
    return PyUnicode_FromWideChar(p, length);
}

impl U_set(ptr_: ptr, value: ptr[PyObject], length: i64) -> ptr[PyObject] {
    count = length // SIZEOF_WCHAR_T;

    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("unicode string expected instead of %s instance"),
            object_type(value).view(1)[0].tp_name
        );
        return NULL;
    }

    size = PyUnicode_AsWideChar(value, ptr[i32](), 0);
    if size < 0 {
        return NULL;
    }

    size -= 1;
    if size > count {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("string too long (%zd, maximum length %zd)"),
            size,
            count
        );
        return NULL;
    }
    if PyUnicode_AsWideChar(value, ptr[i32](ptr_), count) == -1 {
        return NULL;
    }

    return object_new_ref(value);
}

impl s_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    p = ptr[u8](ptr_);
    i: i64 = 0;
    while i < size {
        if (p + i).view(1)[0] == 0 {
            break;
        }
        i += 1;
    }
    return PyBytes_FromStringAndSize(p, i);
}

impl s_set(ptr_: ptr, value: ptr[PyObject], length: i64) -> ptr[PyObject] {
    if not bytes_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("expected bytes, %s found"),
            object_type(value).view(1)[0].tp_name
        );
        return NULL;
    }

    data = PyBytes_AsString(value);

    size = i64(strlen(data));

    if size < length {
        size += 1;
    } elif size > length {
        PyErr_Format(
            PyExc_ValueError,
            ptr[u8]("bytes too long (%zd, maximum length %zd)"),
            size,
            length
        );
        return NULL;
    }
    memcpy(ptr_, ptr(data), u64(size));

    return object_new_ref(Py_None);
}

impl z_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if value == Py_None {
        ptr[u64](ptr_).view(1)[0] = 0;
        return object_new_ref(value);
    }
    if bytes_check(value) {
        ptr[ptr[u8]](ptr_).view(1)[0] = PyBytes_AsString(value);
        return object_new_ref(value);
    } elif long_check(value) {
        ptr[u64](ptr_).view(1)[0] = PyLong_AsUnsignedLongLongMask(value);
        return object_new_ref(Py_None);
    }
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("bytes or integer address expected instead of %s instance"),
        object_type(value).view(1)[0].tp_name
    );
    return NULL;
}

impl z_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    p = ptr[ptr[u8]](ptr_).view(1)[0];
    if p {
        return PyBytes_FromStringAndSize(p, i64(strlen(p)));
    }
    return object_new_ref(Py_None);
}

impl Z_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if value == Py_None {
        ptr[u64](ptr_).view(1)[0] = 0;
        return object_new_ref(value);
    }
    if long_check(value) {
        ptr[u64](ptr_).view(1)[0] = PyLong_AsUnsignedLongLongMask(value);
        return object_new_ref(Py_None);
    }
    if not unicode_check(value) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "unicode string or integer address expected instead of %s instance"
            ),
            object_type(value).view(1)[0].tp_name
        );
        return NULL;
    }

    bsize: i64 = 0;
    buffer = PyUnicode_AsWideCharString(value, &mut bsize);
    if not buffer {
        return NULL;
    }
    keep = PyCapsule_New(
        ptr(buffer), ptr[u8]("_ctypes/cfield.c pymem"), ptr(pymem_destructor)
    );
    if not keep {
        PyMem_Free(ptr(buffer));
        return NULL;
    }
    ptr[ptr[i32]](ptr_).view(1)[0] = buffer;
    return keep;
}

impl Z_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    p = ptr[ptr[i32]](ptr_).view(1)[0];
    if p {
        return PyUnicode_FromWideChar(p, i64(wcslen(p)));
    }
    return object_new_ref(Py_None);
}

impl P_set(ptr_: ptr, value: ptr[PyObject], size: i64) -> ptr[PyObject] {
    if value == Py_None {
        ptr[u64](ptr_).view(1)[0] = 0;
        return object_new_ref(Py_None);
    }

    if not long_check(value) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("cannot be converted to pointer"));
        return NULL;
    }

    v = PyLong_AsUnsignedLongMask(value);
    if PyErr_Occurred() {
        return NULL;
    }

    ptr[u64](ptr_).view(1)[0] = v;
    return object_new_ref(Py_None);
}

impl P_get(ptr_: ptr, size: i64) -> ptr[PyObject] {
    p = ptr[ptr](ptr_).view(1)[0];
    if not p {
        return object_new_ref(Py_None);
    }
    return PyLong_FromVoidPtr(p);
}

impl _ctypes_fixint_fielddesc(nbytes: i64, is_signed: bool) -> ptr[fielddesc] {
    if nbytes == 1 {
        if is_signed {
            return addressof(fmt_i8);
        }
        return addressof(fmt_u8);
    }
    if nbytes == 2 {
        if is_signed {
            return addressof(fmt_i16);
        }
        return addressof(fmt_u16);
    }
    if nbytes == 4 {
        if is_signed {
            return addressof(fmt_i32);
        }
        return addressof(fmt_u32);
    }
    if nbytes == 8 {
        if is_signed {
            return addressof(fmt_i64);
        }
        return addressof(fmt_u64);
    }

    Py_FatalError(
        ptr[u8](
            "We've reached an unreachable state. Anything is possible.\nThe limits were in our heads all along. Follow your dreams.\nhttps://xkcd.com/2200"
        )
    );
    return ptr[fielddesc]();
}

impl set_fielddesc(
    fd: ptr[fielddesc],
    code: u8,
    pffi_type: ptr[ffi_type],
    setfunc: ptr,
    getfunc: ptr,
    setfunc_swapped: ptr,
    getfunc_swapped: ptr
) {
    fd.view(1)[0].code = code;
    fd.view(1)[0].pffi_type = pffi_type;
    fd.view(1)[0].setfunc = setfunc;
    fd.view(1)[0].getfunc = getfunc;
    fd.view(1)[0].setfunc_swapped = setfunc_swapped;
    fd.view(1)[0].getfunc_swapped = getfunc_swapped;
}

impl copy_fielddesc(dst: ptr[fielddesc], src: ptr[fielddesc]) {
    set_fielddesc(
        dst,
        src.view(1)[0].code,
        src.view(1)[0].pffi_type,
        src.view(1)[0].setfunc,
        src.view(1)[0].getfunc,
        src.view(1)[0].setfunc_swapped,
        src.view(1)[0].getfunc_swapped
    );
}

impl add_simple_type_char(chars: ptr[u8], i: i64, fd: ptr[fielddesc], code: u8) -> i64 {
    if fd.view(1)[0].code != 0 {
        (chars + i).view(1)[0] = code;
        return i + 1;
    }
    return i;
}
