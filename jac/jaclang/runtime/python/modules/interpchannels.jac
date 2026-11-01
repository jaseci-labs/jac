import from c {
    def _PyXIData_New -> ptr[_PyXIData_t];  def _PyXIData_InitWithSize(
        xidata: ptr[_PyXIData_t],
        interp: ptr[u8],
        size: u64,
        obj_: ptr[PyObject],
        new_object: ptr
    ) -> i32;  def _PyObject_GetXIData(
        tstate: ptr[PyThreadState],
        obj_: ptr[PyObject],
        fallback: i32,
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXIData_NewObject(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];  def _PyXIData_Release(
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXIData_ReleaseAndRawFree(xidata: ptr[_PyXIData_t]) -> i32;  def PyInterpreterState_GetID(
        interp: ptr[u8]
    ) -> i64;  def PyInterpreterState_Head -> ptr[u8];  def PyInterpreterState_Next(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyInterpreterState_GetIDObject(
        interp: ptr[u8]
    ) -> ptr[PyObject];  def PyUnstable_AtExit(
        interp: ptr[u8], func: ptr, data: ptr
    ) -> i32;  def PyThread_acquire_lock_timed_with_retries(
        lock: ptr, timeout: i64
    ) -> i32;  def PyThread_ParseTimeoutArg(
        arg: ptr[PyObject], blocking: i32, timeout_p: ptr[i64]
    ) -> i32;  def PyModule_GetState(m: ptr[PyObject]) -> ptr;  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def sched_yield -> i32;  def jacpy_stack_address(
        slots: &mut ChannelsStack
    ) -> int;  obj ChannelsStack {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0);
    }  obj module_state {
        has send_channel_type: ptr[PyTypeObject],
            recv_channel_type: ptr[PyTypeObject],
            ChannelInfoType: ptr[PyTypeObject],
            ChannelIDType: ptr[PyTypeObject],
            ChannelError: ptr[PyObject],
            ChannelNotFoundError: ptr[PyObject],
            ChannelClosedError: ptr[PyObject],
            ChannelEmptyError: ptr[PyObject],
            ChannelNotEmptyError: ptr[PyObject];
    }  obj _waiting_t {
        has mutex: ptr,
            status: i32,
            received: i32,
            itemid: u64;
    }  obj _channelitem {
        has interpid: i64,
            data: ptr[_PyXIData_t],
            waiting: ptr[_waiting_t],
            unboundop: i32,
            next: ptr[_channelitem];
    }  obj _channelqueue {
        has count: i64,
            first: ptr[_channelitem],
            last: ptr[_channelitem];
    }  obj _channelend {
        has next: ptr[_channelend],
            interpid: i64,
            open: i32;
    }  obj _channelends {
        has numsendopen: i64,
            numrecvopen: i64,
            send: ptr[_channelend],
            recv: ptr[_channelend];
    }  obj _channel_state {
        has mutex: ptr,
            queue: ptr[_channelqueue],
            ends: ptr[_channelends],
            defaults_unboundop: i32,
            defaults_fallback: i32,
            open: i32,
            closing: ptr[_channel_closing];
    }  obj _channel_closing {
        has ref: ptr[_channelref];
    }  obj _channelref {
        has cid: i64,
            chan: ptr[_channel_state],
            next: ptr[_channelref],
            objcount: i64;
    }  obj _channels {
        has mutex: ptr,
            head: ptr[_channelref],
            numopen: i64,
            next_id: i64;
    }  obj channel_id_and_info {
        has id: i64,
            defaults_unboundop: i32,
            defaults_fallback: i32;
    }  obj channel_info {
        has closed: i32,
            nsend_only: i64,
            nsend_only_released: i64,
            nrecv_only: i64,
            nrecv_only_released: i64,
            nboth: i64,
            nboth_released: i64,
            nboth_send_released: i64,
            nboth_recv_released: i64,
            cur_send: i32,
            cur_recv: i32,
            count: i64;
    }  obj channelid {
        has ob_base: _object,
            cid: i64,
            end: i32,
            resolve: i32,
            channels: ptr[_channels];
    }  obj channel_id_converter_data {
        has module: ptr[PyObject],
            cid: i64,
            end: i32;
    }  obj _channelid_xid {
        has cid: i64,
            end: i32,
            resolve: i32;
    }  obj channels_globals {
        has mutex: u8,
            module_count: i32,
            channels_mutex: ptr,
            channels_head: ptr[_channelref],
            channels_numopen: i64,
            channels_next_id: i64;
    }  glob:priv _globals: channels_globals = channels_globals();
}

glob:priv XID_IGNORE_EXC: Final[i32] = 1,
     XID_FREE: Final[i32] = 2,
     WAIT_LOCK: Final[i32] = 1,
     NOWAIT_LOCK: Final[i32] = 0,
     CHANNEL_SEND: Final[i32] = 1,
     CHANNEL_BOTH: Final[i32] = 0,
     CHANNEL_RECV: Final[i32] = -1,
     ERR_CHANNEL_NOT_FOUND: Final[i32] = -2,
     ERR_CHANNEL_CLOSED: Final[i32] = -3,
     ERR_CHANNEL_INTERP_CLOSED: Final[i32] = -4,
     ERR_CHANNEL_EMPTY: Final[i32] = -5,
     ERR_CHANNEL_NOT_EMPTY: Final[i32] = -6,
     ERR_CHANNEL_MUTEX_INIT: Final[i32] = -7,
     ERR_CHANNELS_MUTEX_INIT: Final[i32] = -8,
     ERR_NO_NEXT_CHANNEL_ID: Final[i32] = -9,
     ERR_CHANNEL_CLOSED_WAITING: Final[i32] = -10,
     WAITING_NO_STATUS: Final[i32] = 0,
     WAITING_ACQUIRED: Final[i32] = 1,
     WAITING_RELEASING: Final[i32] = 2,
     WAITING_RELEASED: Final[i32] = 3,
     WAITING_T_STATUS: Final[i64] = 8,
     WAITING_T_RECEIVED: Final[i64] = 12,
     CHANNELITEM_SIZE: Final[u64] = 40,
     CHANNELQUEUE_SIZE: Final[u64] = 24,
     CHANNELEND_SIZE: Final[u64] = 24,
     CHANNELENDS_SIZE: Final[u64] = 32,
     CHANNEL_STATE_SIZE: Final[u64] = 48,
     CHANNEL_CLOSING_SIZE: Final[u64] = 8,
     CHANNELREF_SIZE: Final[u64] = 32,
     CHANNEL_ID_AND_INFO_SIZE: Final[i64] = 16,
     CHANNELID_XID_SIZE: Final[u64] = 16,
     CHANNELID_SIZE: Final[i32] = 40,
     MODULE_STATE_SIZE: Final[i64] = 72,
     GLOBALS_CHANNELS: Final[i64] = 8,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     Py_nb_index: Final[i32] = 13;

def _release_xid_data(data: ptr[_PyXIData_t], flags: i32) -> i32;

def _get_current_interp -> ptr[u8];

def _get_current_module -> ptr[PyObject];

def get_module_from_owned_type(cls: ptr[PyTypeObject]) -> ptr[PyObject];

def get_module_from_type(cls: ptr[PyTypeObject]) -> ptr[PyObject];

def add_new_exception(
    mod: ptr[PyObject], name: ptr[u8], base: ptr[PyObject]
) -> ptr[PyObject];

def wait_for_lock(mutex: ptr, timeout: i64) -> i32;

def ensure_highlevel_module_loaded -> i32;

def get_module_state(mod: ptr[PyObject]) -> ptr[module_state];

def _get_current_module_state -> ptr[module_state];

def clear_state_slot(slot: ptr[ptr[PyObject]]);

def state_slot(state: ptr[module_state], index: i64) -> ptr[ptr[PyObject]];

def traverse_module_state(state: ptr[module_state], visitor: ptr, arg: ptr) -> i32;

def clear_xid_types(state: ptr[module_state]);

def clear_module_state(state: ptr[module_state]) -> i32;

def exceptions_init(mod: ptr[PyObject]) -> i32;

def handle_channel_error(err: i32, mod: ptr[PyObject], cid: i64) -> i32;

def _waiting_init(waiting: ptr[_waiting_t]) -> i32;

def _waiting_clear(waiting: ptr[_waiting_t]);

def _waiting_get_itemid(waiting: ptr[_waiting_t]) -> u64;

def _waiting_status(waiting: ptr[_waiting_t]) -> i32;

def _waiting_acquire(waiting: ptr[_waiting_t]);

def _waiting_release(waiting: ptr[_waiting_t], received: i32);

def _waiting_finish_releasing(waiting: ptr[_waiting_t]);

def _channelitem_ID(item: ptr[_channelitem]) -> u64;

def _channelitem_init(
    item: ptr[_channelitem],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
);

def _channelitem_clear_data(item: ptr[_channelitem], removed: i32);

def _channelitem_clear(item: ptr[_channelitem]);

def _channelitem_new(
    interpid: i64, data: ptr[_PyXIData_t], waiting: ptr[_waiting_t], unboundop: i32
) -> ptr[_channelitem];

def _channelitem_free(item: ptr[_channelitem]);

def _channelitem_free_all(item: ptr[_channelitem]);

def _channelitem_popped(
    item: ptr[_channelitem]
) -> tuple[ptr[_PyXIData_t], ptr[_waiting_t], i32];

def _channelitem_clear_interpreter(item: ptr[_channelitem]) -> i32;

def _channelqueue_new -> ptr[_channelqueue];

def _channelqueue_clear(queue: ptr[_channelqueue]);

def _channelqueue_free(queue: ptr[_channelqueue]);

def _channelqueue_put(
    queue: ptr[_channelqueue],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
) -> i32;

def _channelqueue_get(
    queue: ptr[_channelqueue]
) -> tuple[i32, ptr[_PyXIData_t], ptr[_waiting_t], i32];

def _channelqueue_find(
    queue: ptr[_channelqueue], itemid: u64
) -> tuple[i32, ptr[_channelitem], ptr[_channelitem]];

def _channelqueue_remove(
    queue: ptr[_channelqueue], itemid: u64
) -> tuple[ptr[_PyXIData_t], ptr[_waiting_t]];

def _channelqueue_clear_interpreter(queue: ptr[_channelqueue], interpid: i64);

def _channelend_new(interpid: i64) -> ptr[_channelend];

def _channelend_free(end: ptr[_channelend]);

def _channelend_free_all(end: ptr[_channelend]);

def _channelend_find(
    first: ptr[_channelend], interpid: i64
) -> tuple[ptr[_channelend], ptr[_channelend]];

def _channelends_new -> ptr[_channelends];

def _channelends_clear(ends: ptr[_channelends]);

def _channelends_free(ends: ptr[_channelends]);

def _channelends_add(
    ends: ptr[_channelends], prev: ptr[_channelend], interpid: i64, send: i32
) -> ptr[_channelend];

def _channelends_associate(ends: ptr[_channelends], interpid: i64, send: i32) -> i32;

def _channelends_is_open(ends: ptr[_channelends]) -> i32;

def _channelends_release_end(
    ends: ptr[_channelends], end: ptr[_channelend], send: i32
);

def _channelends_release_interpreter(
    ends: ptr[_channelends], interpid: i64, which: i32
) -> i32;

def _channelends_release_all(ends: ptr[_channelends], which: i32, force: i32);

def _channelends_clear_interpreter(ends: ptr[_channelends], interpid: i64);

def _channel_new(mutex: ptr, unboundop: i32, fallback: i32) -> ptr[_channel_state];

def _channel_free(chan: ptr[_channel_state]);

def _channel_add(
    chan: ptr[_channel_state],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
) -> i32;

def _channel_next(
    chan: ptr[_channel_state], interpid: i64
) -> tuple[i32, ptr[_PyXIData_t], ptr[_waiting_t], i32];

def _channel_remove(chan: ptr[_channel_state], itemid: u64);

def _channel_release_interpreter(
    chan: ptr[_channel_state], interpid: i64, end: i32
) -> i32;

def _channel_release_all(chan: ptr[_channel_state], end: i32, force: i32) -> i32;

def _channel_clear_interpreter(chan: ptr[_channel_state], interpid: i64);

def _channelref_new(cid: i64, chan: ptr[_channel_state]) -> ptr[_channelref];

def _channelref_free(ref: ptr[_channelref]);

def _channelref_find(
    first: ptr[_channelref], cid: i64
) -> tuple[ptr[_channelref], ptr[_channelref]];

def _channels_init(channels: ptr[_channels], mutex: ptr);

def _channels_fini(channels: ptr[_channels]) -> ptr;

def _channels_next_id(channels: ptr[_channels]) -> i64;

def _channels_lookup(
    channels: ptr[_channels], cid: i64, want_mutex: bool
) -> tuple[i32, ptr, ptr[_channel_state]];

def _channels_add(channels: ptr[_channels], chan: ptr[_channel_state]) -> i64;

def _channels_close(
    channels: ptr[_channels], cid: i64, want_chan: bool, end: i32, force: i32
) -> tuple[i32, ptr[_channel_state]];

def _channels_remove_ref(
    channels: ptr[_channels], ref: ptr[_channelref], prev: ptr[_channelref]
) -> ptr[_channel_state];

def _channels_remove(
    channels: ptr[_channels], cid: i64
) -> tuple[i32, ptr[_channel_state]];

def _channels_add_id_object(channels: ptr[_channels], cid: i64) -> i32;

def _channels_release_cid_object(channels: ptr[_channels], cid: i64);

def _channels_list_all(
    channels: ptr[_channels]
) -> tuple[ptr[channel_id_and_info], i64];

def _channels_clear_interpreter(channels: ptr[_channels], interpid: i64);

def _channel_set_closing(ref: ptr[_channelref], mutex: ptr) -> i32;

def _channel_clear_closing(chan: ptr[_channel_state]);

def _channel_finish_closing(chan: ptr[_channel_state]);

def channel_create(channels: ptr[_channels], unboundop: i32, fallback: i32) -> i64;

def channel_destroy(channels: ptr[_channels], cid: i64) -> i32;

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def channel_send(
    channels: ptr[_channels],
    cid: i64,
    obj_: ptr[PyObject],
    waiting: ptr[_waiting_t],
    unboundop: i32,
    fallback: i32
) -> i32;

def channel_clear_sent(channels: ptr[_channels], cid: i64, waiting: ptr[_waiting_t]);

def channel_send_wait(
    channels: ptr[_channels],
    cid: i64,
    obj_: ptr[PyObject],
    unboundop: i32,
    timeout: i64,
    fallback: i32
) -> i32;

def channel_recv(channels: ptr[_channels], cid: i64) -> tuple[i32, ptr[PyObject], i32];

def channel_release(channels: ptr[_channels], cid: i64, send: i32, recv: i32) -> i32;

def channel_close(channels: ptr[_channels], cid: i64, end: i32, force: i32) -> i32;

def channel_is_associated(
    channels: ptr[_channels], cid: i64, interpid: i64, send: i32
) -> i32;

def channel_get_defaults(channels: ptr[_channels], cid: i64) -> tuple[i32, i32, i32];

def _channel_get_count(channels: ptr[_channels], cid: i64) -> tuple[i32, i64];

def _channel_get_info(
    channels: ptr[_channels], cid: i64, info: ptr[channel_info]
) -> i32;

def info_bool(cond: bool) -> ptr[PyObject];

def info_set_count(self_: ptr[PyObject], pos: i64, val: i64) -> bool;

def new_channel_info(mod: ptr[PyObject], info: ptr[channel_info]) -> ptr[PyObject];

def channel_id_converter(arg: ptr[PyObject], ptr_: ptr) -> i32;

def newchannelid(
    cls: ptr[PyTypeObject],
    cid: i64,
    end: i32,
    channels: ptr[_channels],
    force: i32,
    resolve: i32
) -> tuple[i32, ptr[PyObject]];

def _global_channels -> ptr[_channels];

def converter_data(
    slots: ptr[u8], mod: ptr[PyObject]
) -> ptr[channel_id_converter_data];

def _channelid_new(
    mod: ptr[PyObject], cls: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelid_dealloc(op: ptr[PyObject]);

def channelid_repr(self_: ptr[PyObject]) -> ptr[PyObject];

def channelid_str(self_: ptr[PyObject]) -> ptr[PyObject];

def channelid_int(self_: ptr[PyObject]) -> ptr[PyObject];

def channelid_hash(self_: ptr[PyObject]) -> i64;

def channelid_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

def _channelobj_from_cidobj(cidobj: ptr[PyObject], end: i32) -> ptr[PyObject];

def _channelid_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject];

def _channelid_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32;

def channelid_end(self_: ptr[PyObject], end: ptr) -> ptr[PyObject];

def add_channelid_type(mod: ptr[PyObject]) -> ptr[PyTypeObject];

def _get_current_channelend_type(end: i32) -> ptr[PyTypeObject];

def _channelend_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject];

def _channelend_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32;

def set_channelend_types(
    mod: ptr[PyObject], send: ptr[PyTypeObject], recv: ptr[PyTypeObject]
) -> i32;

def _globals_init -> i32;

def _globals_fini;

def clear_interpreter(data: ptr);

def channelsmod_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_list_all(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_list_interpreters(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_send_common(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], as_buffer: bool
) -> ptr[PyObject];

def channelsmod_send(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_send_buffer(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_recv(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_close(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_release(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_get_count(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_get_info(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod_get_channel_defaults(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod__channel_id(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def channelsmod__register_end_types(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def module_exec(mod: ptr[PyObject]) -> i32;

def module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def module_clear(mod: ptr[PyObject]) -> i32;

def module_free(mod: ptr);

import from c {
    glob:priv channelid_new_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("send"),
             ptr[u8]("recv"),
             ptr[u8]("force"),
             ptr[u8]("_resolve"),
             ptr[u8]()
         ],
         create_kwlist: list[ptr[u8]] = [
             ptr[u8]("unboundop"),
             ptr[u8]("fallback"),
             ptr[u8]()
         ],
         cid_kwlist: list[ptr[u8]] = [ptr[u8]("cid"), ptr[u8]()],
         list_interpreters_kwlist: list[ptr[u8]] = [
             ptr[u8]("cid"),
             ptr[u8]("send"),
             ptr[u8]()
         ],
         send_kwlist: list[ptr[u8]] = [
             ptr[u8]("cid"),
             ptr[u8]("obj"),
             ptr[u8]("unboundop"),
             ptr[u8]("fallback"),
             ptr[u8]("blocking"),
             ptr[u8]("timeout"),
             ptr[u8]()
         ],
         recv_kwlist: list[ptr[u8]] = [ptr[u8]("cid"), ptr[u8]("default"), ptr[u8]()],
         close_kwlist: list[ptr[u8]] = [
             ptr[u8]("cid"),
             ptr[u8]("send"),
             ptr[u8]("recv"),
             ptr[u8]("force"),
             ptr[u8]()
         ],
         register_end_types_kwlist: list[ptr[u8]] = [
             ptr[u8]("send"),
             ptr[u8]("recv"),
             ptr[u8]()
         ],
         channel_info_fields: list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("open"), doc=ptr[u8]("both ends are open")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("closing"),
                 doc=ptr[u8]("send is closed, recv is non-empty")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("closed"), doc=ptr[u8]("both ends are closed")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("count"), doc=ptr[u8]("queued objects")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_send"),
                 doc=ptr[u8]("interpreters bound to the send end")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_send_released"),
                 doc=ptr[u8]("interpreters bound to the send end and released")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_recv"),
                 doc=ptr[u8]("interpreters bound to the send end")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_recv_released"),
                 doc=ptr[u8]("interpreters bound to the send end and released")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_both"),
                 doc=ptr[u8]("interpreters bound to both ends")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_both_released"),
                 doc=ptr[u8]("interpreters bound to both ends and released_from_both")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_both_send_released"),
                 doc=ptr[u8](
                     "interpreters bound to both ends and released_from_the send end"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("num_interp_both_recv_released"),
                 doc=ptr[u8](
                     "interpreters bound to both ends and released_from_the recv end"
                 )
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("send_associated"),
                 doc=ptr[u8]("current interpreter is bound to the send end")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("send_released"),
                 doc=ptr[u8]("current interpreter *was* bound to the send end")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("recv_associated"),
                 doc=ptr[u8]("current interpreter is bound to the recv end")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("recv_released"),
                 doc=ptr[u8]("current interpreter *was* bound to the recv end")
             ),
             PyStructSequence_Field(name=ptr[u8](), doc=ptr[u8]())
         ],
         channel_info_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("_interpchannels.ChannelInfo"),
             doc=ptr[u8]("ChannelInfo\n\nA named tuple of a channel's state."),
             fields=addressof(channel_info_fields),
             n_in_sequence=8
         ),
         _channelid_end_send: list[i32] = [CHANNEL_SEND],
         _channelid_end_recv: list[i32] = [CHANNEL_RECV],
         channelid_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("end"),
                 get=channelid_end,
                 doc=ptr[u8]("'send', 'recv', or 'both'")
             ),
             PyGetSetDef(
                 name=ptr[u8]("send"),
                 get=channelid_end,
                 doc=ptr[u8]("the 'send' end of the channel"),
                 closure=ptr(addressof(_channelid_end_send))
             ),
             PyGetSetDef(
                 name=ptr[u8]("recv"),
                 get=channelid_end,
                 doc=ptr[u8]("the 'recv' end of the channel"),
                 closure=ptr(addressof(_channelid_end_recv))
             ),
             PyGetSetDef(name=ptr[u8]())
         ],
         channelid_typeslots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(channelid_dealloc)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "A channel ID identifies a channel and may be used as an int."
                 )
             ),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(channelid_repr)),
             PyType_Slot(slot=Py_tp_str, pfunc=ptr(channelid_str)),
             PyType_Slot(slot=Py_tp_hash, pfunc=ptr(channelid_hash)),
             PyType_Slot(slot=Py_tp_richcompare, pfunc=ptr(channelid_richcompare)),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(channelid_getsets))),
             PyType_Slot(slot=Py_nb_int, pfunc=ptr(channelid_int)),
             PyType_Slot(slot=Py_nb_index, pfunc=ptr(channelid_int)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         channelid_typespec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_interpchannels.ChannelID"),
             basicsize=CHANNELID_SIZE,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(channelid_typeslots)
         ),
         module_functions: list[PyMethodDef] = [
             PyMethodDef(
                 ml_name=ptr[u8]("create"),
                 ml_meth=ptr(channelsmod_create),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_create(unboundop) -> cid\n\nCreate a new cross-interpreter channel and return a unique generated ID."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("destroy"),
                 ml_meth=ptr(channelsmod_destroy),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_destroy(cid)\n\nClose and finalize the channel.  Afterward attempts to use the channel\nwill behave as though it never existed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("list_all"),
                 ml_meth=ptr(channelsmod_list_all),
                 ml_flags=METH_NOARGS,
                 ml_doc=ptr[u8](
                     "channel_list_all() -> [cid]\n\nReturn the list of all IDs for active channels."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("list_interpreters"),
                 ml_meth=ptr(channelsmod_list_interpreters),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_list_interpreters(cid, *, send) -> [id]\n\nReturn the list of all interpreter IDs associated with an end of the channel.\n\nThe 'send' argument should be a boolean indicating whether to use the send or\nreceive end."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("send"),
                 ml_meth=ptr(channelsmod_send),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_send(cid, obj, *, blocking=True, timeout=None)\n\nAdd the object's data to the channel's queue.\nBy default this waits for the object to be received."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("send_buffer"),
                 ml_meth=ptr(channelsmod_send_buffer),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_send_buffer(cid, obj, *, blocking=True, timeout=None)\n\nAdd the object's buffer to the channel's queue.\nBy default this waits for the object to be received."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("recv"),
                 ml_meth=ptr(channelsmod_recv),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_recv(cid, [default]) -> (obj, unboundop)\n\nReturn a new object from the data at the front of the channel's queue.\n\nIf there is nothing to receive then raise ChannelEmptyError, unless\na default value is provided.  In that case return it."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("close"),
                 ml_meth=ptr(channelsmod_close),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_close(cid, *, send=None, recv=None, force=False)\n\nClose the channel for all interpreters.\n\nIf the channel is empty then the keyword args are ignored and both\nends are immediately closed.  Otherwise, if 'force' is True then\nall queued items are released and both ends are immediately\nclosed.\n\nIf the channel is not empty *and* 'force' is False then following\nhappens:\n\n * recv is True (regardless of send):\n   - raise ChannelNotEmptyError\n * recv is None and send is None:\n   - raise ChannelNotEmptyError\n * send is True and recv is not True:\n   - fully close the 'send' end\n   - close the 'recv' end to interpreters not already receiving\n   - fully close it once empty\n\nClosing an already closed channel results in a ChannelClosedError.\n\nOnce the channel's ID has no more ref counts in any interpreter\nthe channel will be destroyed."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("release"),
                 ml_meth=ptr(channelsmod_release),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "channel_release(cid, *, send=None, recv=None, force=True)\n\nClose the channel for the current interpreter.  'send' and 'recv'\n(bool) may be used to indicate the ends to close.  By default both\nends are closed.  Closing an already closed end is a noop."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_count"),
                 ml_meth=ptr(channelsmod_get_count),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_count(cid)\n\nReturn the number of items in the channel."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_info"),
                 ml_meth=ptr(channelsmod_get_info),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]("get_info(cid)\n\nReturn details about the channel.")
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("get_channel_defaults"),
                 ml_meth=ptr(channelsmod_get_channel_defaults),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8](
                     "get_channel_defaults(cid)\n\nReturn the channel's default values, set when it was created."
                 )
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_channel_id"),
                 ml_meth=ptr(channelsmod__channel_id),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(
                 ml_name=ptr[u8]("_register_end_types"),
                 ml_meth=ptr(channelsmod__register_end_types),
                 ml_flags=METH_VARARGS | METH_KEYWORDS,
                 ml_doc=ptr[u8]()
             ),
             PyMethodDef(ml_name=ptr[u8](), ml_meth=ptr(), ml_flags=0, ml_doc=ptr[u8]())
         ],
         module_slots: list[PyModuleDef_Slot] = [
             PyModuleDef_Slot(slot=Py_mod_exec, value=ptr(module_exec)),
             PyModuleDef_Slot(slot=Py_mod_multiple_interpreters, value=ptr(2)),
             PyModuleDef_Slot(slot=Py_mod_gil, value=ptr(1)),
             PyModuleDef_Slot(slot=0, value=ptr())
         ]; glob interpchannels_moduledef: ModuleDef = ModuleDef(
             m_base=PyModuleDef_Base(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 m_index=0,
                 m_copy=ptr[PyObject]()
             ),
             m_name=ptr[u8]("_interpchannels"),
             m_doc=ptr[u8](
                 "This module provides primitive operations to manage Python interpreters.\nThe 'interpreters' module provides a more convenient interface."
             ),
             m_size=MODULE_STATE_SIZE,
             m_methods=addressof(module_functions),
             m_slots=addressof(module_slots)
         );
}

impl _release_xid_data(data: ptr[_PyXIData_t], flags: i32) -> i32 {
    ignoreexc = flags & XID_IGNORE_EXC;
    exc = NULL;
    if ignoreexc != 0 {
        exc = PyErr_GetRaisedException();
    }
    res: i32 = 0;
    if (flags & XID_FREE) != 0 {
        res = _PyXIData_ReleaseAndRawFree(data);
    } else {
        res = _PyXIData_Release(data);
    }
    if res < 0 {
        if ignoreexc != 0 {
            PyErr_Clear();
        }
    }
    if ignoreexc != 0 {
        PyErr_SetRaisedException(exc);
    }
    return res;
}

impl _get_current_interp -> ptr[u8] {
    return current_interp();
}

impl _get_current_module -> ptr[PyObject] {
    name = PyUnicode_FromString(ptr[u8]("_interpchannels"));
    if not name {
        return NULL;
    }
    mod = PyImport_GetModule(name);
    object_decref(name);
    if not mod {
        return NULL;
    }
    return mod;
}

impl get_module_from_owned_type(cls: ptr[PyTypeObject]) -> ptr[PyObject] {
    return _get_current_module();
}

impl get_module_from_type(cls: ptr[PyTypeObject]) -> ptr[PyObject] {
    return _get_current_module();
}

impl add_new_exception(
    mod: ptr[PyObject], name: ptr[u8], base: ptr[PyObject]
) -> ptr[PyObject] {
    exctype = PyErr_NewException(name, base, NULL);
    if not exctype {
        return NULL;
    }
    res = PyModule_AddType(mod, exctype);
    if res < 0 {
        object_decref(exctype);
        return NULL;
    }
    return exctype;
}

impl wait_for_lock(mutex: ptr, timeout: i64) -> i32 {
    res = PyThread_acquire_lock_timed_with_retries(mutex, timeout);
    if res == PY_LOCK_INTR {
        return -1;
    } elif res == PY_LOCK_FAILURE {
        PyErr_SetString(PyExc_TimeoutError, ptr[u8]("timed out"));
        return -1;
    }
    PyThread_release_lock(mutex);
    return 0;
}

impl ensure_highlevel_module_loaded -> i32 {
    highlevel = PyImport_ImportModule(ptr[u8]("concurrent.interpreters._channels"));
    if not highlevel {
        PyErr_Clear();
        highlevel = PyImport_ImportModule(ptr[u8]("test.support.channels"));
        if not highlevel {
            return -1;
        }
    }
    object_decref(highlevel);
    return 0;
}

impl get_module_state(mod: ptr[PyObject]) -> ptr[module_state] {
    return ptr[module_state](PyModule_GetState(mod));
}

impl _get_current_module_state -> ptr[module_state] {
    mod = _get_current_module();
    if not mod {
        mod = PyImport_ImportModule(ptr[u8]("_interpchannels"));
        if not mod {
            return ptr[module_state]();
        }
    }
    state = get_module_state(mod);
    object_decref(mod);
    return state;
}

impl clear_state_slot(slot: ptr[ptr[PyObject]]) {
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
}

impl state_slot(state: ptr[module_state], index: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](state) + index;
}

impl traverse_module_state(state: ptr[module_state], visitor: ptr, arg: ptr) -> i32 {
    st = state.view(1);
    vret = visit_reference(ptr[PyObject](st[0].send_channel_type), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](st[0].recv_channel_type), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](st[0].ChannelInfoType), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(ptr[PyObject](st[0].ChannelIDType), visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(st[0].ChannelError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(st[0].ChannelNotFoundError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(st[0].ChannelClosedError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(st[0].ChannelEmptyError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    vret = visit_reference(st[0].ChannelNotEmptyError, visitor, arg);
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl clear_xid_types(state: ptr[module_state]) {
    st = state.view(1);
    if st[0].send_channel_type {
        clear_xid_class(st[0].send_channel_type);
        clear_state_slot(state_slot(state, 0));
    }
    if st[0].recv_channel_type {
        clear_xid_class(st[0].recv_channel_type);
        clear_state_slot(state_slot(state, 1));
    }
    if st[0].ChannelIDType {
        clear_xid_class(st[0].ChannelIDType);
        clear_state_slot(state_slot(state, 3));
    }
}

impl clear_module_state(state: ptr[module_state]) -> i32 {
    clear_xid_types(state);
    clear_state_slot(state_slot(state, 2));
    clear_state_slot(state_slot(state, 4));
    clear_state_slot(state_slot(state, 5));
    clear_state_slot(state_slot(state, 6));
    clear_state_slot(state_slot(state, 7));
    clear_state_slot(state_slot(state, 8));
    return 0;
}

impl exceptions_init(mod: ptr[PyObject]) -> i32 {
    state = get_module_state(mod);
    if not state {
        return -1;
    }
    st = state.view(1);
    st[0].ChannelError = add_new_exception(
        mod, ptr[u8]("_interpchannels.ChannelError"), PyExc_RuntimeError
    );
    if not st[0].ChannelError {
        return -1;
    }
    st[0].ChannelNotFoundError = add_new_exception(
        mod, ptr[u8]("_interpchannels.ChannelNotFoundError"), st[0].ChannelError
    );
    if not st[0].ChannelNotFoundError {
        return -1;
    }
    st[0].ChannelClosedError = add_new_exception(
        mod, ptr[u8]("_interpchannels.ChannelClosedError"), st[0].ChannelError
    );
    if not st[0].ChannelClosedError {
        return -1;
    }
    st[0].ChannelEmptyError = add_new_exception(
        mod, ptr[u8]("_interpchannels.ChannelEmptyError"), st[0].ChannelError
    );
    if not st[0].ChannelEmptyError {
        return -1;
    }
    st[0].ChannelNotEmptyError = add_new_exception(
        mod, ptr[u8]("_interpchannels.ChannelNotEmptyError"), st[0].ChannelError
    );
    if not st[0].ChannelNotEmptyError {
        return -1;
    }
    return 0;
}

impl handle_channel_error(err: i32, mod: ptr[PyObject], cid: i64) -> i32 {
    if err == 0 {
        return 0;
    }
    st = get_module_state(mod).view(1);
    if err == ERR_CHANNEL_NOT_FOUND {
        PyErr_Format(st[0].ChannelNotFoundError, ptr[u8]("channel %ld not found"), cid);
    } elif err == ERR_CHANNEL_CLOSED {
        PyErr_Format(st[0].ChannelClosedError, ptr[u8]("channel %ld is closed"), cid);
    } elif err == ERR_CHANNEL_CLOSED_WAITING {
        PyErr_Format(st[0].ChannelClosedError, ptr[u8]("channel %ld has closed"), cid);
    } elif err == ERR_CHANNEL_INTERP_CLOSED {
        PyErr_Format(
            st[0].ChannelClosedError, ptr[u8]("channel %ld is already closed"), cid
        );
    } elif err == ERR_CHANNEL_EMPTY {
        PyErr_Format(st[0].ChannelEmptyError, ptr[u8]("channel %ld is empty"), cid);
    } elif err == ERR_CHANNEL_NOT_EMPTY {
        PyErr_Format(
            st[0].ChannelNotEmptyError,
            ptr[u8]("channel %ld may not be closed if not empty (try force=True)"),
            cid
        );
    } elif err == ERR_CHANNEL_MUTEX_INIT {
        PyErr_SetString(
            st[0].ChannelError, ptr[u8]("can't initialize mutex for new channel")
        );
    } elif err == ERR_CHANNELS_MUTEX_INIT {
        PyErr_SetString(
            st[0].ChannelError, ptr[u8]("can't initialize mutex for channel management")
        );
    } elif err == ERR_NO_NEXT_CHANNEL_ID {
        PyErr_SetString(st[0].ChannelError, ptr[u8]("failed to get a channel ID"));
    }
    return 1;
}

impl _waiting_init(waiting: ptr[_waiting_t]) -> i32 {
    mutex = PyThread_allocate_lock();
    if not mutex {
        PyErr_NoMemory();
        return -1;
    }
    w = waiting.view(1);
    w[0].mutex = mutex;
    w[0].status = WAITING_NO_STATUS;
    w[0].received = 0;
    w[0].itemid = 0;
    return 0;
}

impl _waiting_clear(waiting: ptr[_waiting_t]) {
    w = waiting.view(1);
    if w[0].mutex {
        PyThread_free_lock(w[0].mutex);
        w[0].mutex = ptr();
    }
}

impl _waiting_get_itemid(waiting: ptr[_waiting_t]) -> u64 {
    return waiting.view(1)[0].itemid;
}

impl _waiting_status(waiting: ptr[_waiting_t]) -> i32 {
    return __atomic_load_i32(int(waiting) + WAITING_T_STATUS, 5);
}

impl _waiting_acquire(waiting: ptr[_waiting_t]) {
    w = waiting.view(1);
    PyThread_acquire_lock(w[0].mutex, NOWAIT_LOCK);
    __atomic_store_i32(int(waiting) + WAITING_T_STATUS, WAITING_ACQUIRED, 5);
}

impl _waiting_release(waiting: ptr[_waiting_t], received: i32) {
    w = waiting.view(1);
    __atomic_store_i32(int(waiting) + WAITING_T_STATUS, WAITING_RELEASING, 5);
    if w[0].received != received {
        __atomic_store_i32(int(waiting) + WAITING_T_RECEIVED, received, 5);
    }
    __atomic_store_i32(int(waiting) + WAITING_T_STATUS, WAITING_RELEASED, 5);
    PyThread_release_lock(w[0].mutex);
}

impl _waiting_finish_releasing(waiting: ptr[_waiting_t]) {
    while _waiting_status(waiting) == WAITING_RELEASING {
        sched_yield();
    }
}

impl _channelitem_ID(item: ptr[_channelitem]) -> u64 {
    return u64(int(item));
}

impl _channelitem_init(
    item: ptr[_channelitem],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
) {
    if interpid < 0 {
        interpid = get_interpid(data);
    }
    it = item.view(1);
    it[0].interpid = interpid;
    it[0].data = data;
    it[0].waiting = waiting;
    it[0].unboundop = unboundop;
    it[0].next = ptr[_channelitem]();
    if waiting {
        waiting.view(1)[0].itemid = _channelitem_ID(item);
    }
}

impl _channelitem_clear_data(item: ptr[_channelitem], removed: i32) {
    it = item.view(1);
    if it[0].data {
        _release_xid_data(it[0].data, XID_IGNORE_EXC | XID_FREE);
        it[0].data = ptr[_PyXIData_t]();
    }

    if it[0].waiting and removed != 0 {
        if _waiting_status(it[0].waiting) == WAITING_ACQUIRED {
            _waiting_release(it[0].waiting, 0);
        }
        it[0].waiting = ptr[_waiting_t]();
    }
}

impl _channelitem_clear(item: ptr[_channelitem]) {
    item.view(1)[0].next = ptr[_channelitem]();
    _channelitem_clear_data(item, 1);
}

impl _channelitem_new(
    interpid: i64, data: ptr[_PyXIData_t], waiting: ptr[_waiting_t], unboundop: i32
) -> ptr[_channelitem] {
    item = ptr[_channelitem](PyMem_RawMalloc(CHANNELITEM_SIZE));
    if not item {
        PyErr_NoMemory();
        return ptr[_channelitem]();
    }
    _channelitem_init(item, interpid, data, waiting, unboundop);
    return item;
}

impl _channelitem_free(item: ptr[_channelitem]) {
    _channelitem_clear(item);
    PyMem_RawFree(ptr(item));
}

impl _channelitem_free_all(item: ptr[_channelitem]) {
    while item {
        last = item;
        item = item.view(1)[0].next;
        _channelitem_free(last);
    }
}

impl _channelitem_popped(
    item: ptr[_channelitem]
) -> tuple[ptr[_PyXIData_t], ptr[_waiting_t], i32] {
    it = item.view(1);
    data = it[0].data;
    waiting = it[0].waiting;
    unboundop = it[0].unboundop;
    it[0].data = ptr[_PyXIData_t]();
    it[0].waiting = ptr[_waiting_t]();
    _channelitem_free(item);
    return (data, waiting, unboundop);
}

impl _channelitem_clear_interpreter(item: ptr[_channelitem]) -> i32 {
    it = item.view(1);
    if not it[0].data {
        return 0;
    }
    op = it[0].unboundop;
    if op == UNBOUND_REMOVE {
        return 1;
    } elif op == UNBOUND_ERROR or op == UNBOUND_REPLACE {
        _channelitem_clear_data(item, 0);
        return 0;
    }
    _Py_FatalErrorFunc(
        ptr[u8]("_channelitem_clear_interpreter"), ptr[u8]("not reachable")
    );
    return -1;
}

impl _channelqueue_new -> ptr[_channelqueue] {
    queue = ptr[_channelqueue](PyMem_RawMalloc(CHANNELQUEUE_SIZE));
    if not queue {
        PyErr_NoMemory();
        return ptr[_channelqueue]();
    }
    q = queue.view(1);
    q[0].count = 0;
    q[0].first = ptr[_channelitem]();
    q[0].last = ptr[_channelitem]();
    return queue;
}

impl _channelqueue_clear(queue: ptr[_channelqueue]) {
    q = queue.view(1);
    _channelitem_free_all(q[0].first);
    q[0].count = 0;
    q[0].first = ptr[_channelitem]();
    q[0].last = ptr[_channelitem]();
}

impl _channelqueue_free(queue: ptr[_channelqueue]) {
    _channelqueue_clear(queue);
    PyMem_RawFree(ptr(queue));
}

impl _channelqueue_put(
    queue: ptr[_channelqueue],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
) -> i32 {
    item = _channelitem_new(interpid, data, waiting, unboundop);
    if not item {
        return -1;
    }

    q = queue.view(1);
    q[0].count += 1;
    if not q[0].first {
        q[0].first = item;
    } else {
        q[0].last.view(1)[0].next = item;
    }
    q[0].last = item;

    if waiting {
        _waiting_acquire(waiting);
    }

    return 0;
}

impl _channelqueue_get(
    queue: ptr[_channelqueue]
) -> tuple[i32, ptr[_PyXIData_t], ptr[_waiting_t], i32] {
    q = queue.view(1);
    item = q[0].first;
    if not item {
        return (ERR_CHANNEL_EMPTY, ptr[_PyXIData_t](), ptr[_waiting_t](), i32(0));
    }
    q[0].first = item.view(1)[0].next;
    if q[0].last == item {
        q[0].last = ptr[_channelitem]();
    }
    q[0].count -= 1;

    (data, waiting, unboundop) = _channelitem_popped(item);
    return (i32(0), data, waiting, unboundop);
}

impl _channelqueue_find(
    queue: ptr[_channelqueue], itemid: u64
) -> tuple[i32, ptr[_channelitem], ptr[_channelitem]] {
    prev = ptr[_channelitem]();
    item = ptr[_channelitem]();
    q = queue.view(1);
    if q[0].first {
        if _channelitem_ID(q[0].first) == itemid {
            item = q[0].first;
        } else {
            prev = q[0].first;
            while prev.view(1)[0].next {
                if _channelitem_ID(prev.view(1)[0].next) == itemid {
                    item = prev.view(1)[0].next;
                    break;
                }
                prev = prev.view(1)[0].next;
            }
            if not item {
                prev = ptr[_channelitem]();
            }
        }
    }
    found: i32 = 0;
    if item {
        found = 1;
    }
    return (found, item, prev);
}

impl _channelqueue_remove(
    queue: ptr[_channelqueue], itemid: u64
) -> tuple[ptr[_PyXIData_t], ptr[_waiting_t]] {
    (found, item, prev) = _channelqueue_find(queue, itemid);
    if found == 0 {
        return (ptr[_PyXIData_t](), ptr[_waiting_t]());
    }

    q = queue.view(1);
    if not prev {
        q[0].first = item.view(1)[0].next;
    } else {
        prev.view(1)[0].next = item.view(1)[0].next;
    }
    item.view(1)[0].next = ptr[_channelitem]();

    if q[0].last == item {
        q[0].last = prev;
    }
    q[0].count -= 1;

    (data, waiting, unboundop) = _channelitem_popped(item);
    return (data, waiting);
}

impl _channelqueue_clear_interpreter(queue: ptr[_channelqueue], interpid: i64) {
    q = queue.view(1);
    prev = ptr[_channelitem]();
    next = q[0].first;
    while next {
        item = next;
        next = item.view(1)[0].next;
        remove: i32 = 0;
        if item.view(1)[0].interpid == interpid {
            remove = _channelitem_clear_interpreter(item);
        }
        if remove != 0 {
            _channelitem_free(item);
            if not prev {
                q[0].first = next;
            } else {
                prev.view(1)[0].next = next;
            }
            q[0].count -= 1;
        } else {
            prev = item;
        }
    }
}

impl _channelend_new(interpid: i64) -> ptr[_channelend] {
    end = ptr[_channelend](PyMem_RawMalloc(CHANNELEND_SIZE));
    if not end {
        PyErr_NoMemory();
        return ptr[_channelend]();
    }
    e = end.view(1);
    e[0].next = ptr[_channelend]();
    e[0].interpid = interpid;
    e[0].open = 1;
    return end;
}

impl _channelend_free(end: ptr[_channelend]) {
    PyMem_RawFree(ptr(end));
}

impl _channelend_free_all(end: ptr[_channelend]) {
    while end {
        last = end;
        end = end.view(1)[0].next;
        _channelend_free(last);
    }
}

impl _channelend_find(
    first: ptr[_channelend], interpid: i64
) -> tuple[ptr[_channelend], ptr[_channelend]] {
    prev = ptr[_channelend]();
    end = first;
    while end {
        if end.view(1)[0].interpid == interpid {
            break;
        }
        prev = end;
        end = end.view(1)[0].next;
    }
    return (end, prev);
}

impl _channelends_new -> ptr[_channelends] {
    ends = ptr[_channelends](PyMem_RawMalloc(CHANNELENDS_SIZE));
    if not ends {
        return ptr[_channelends]();
    }
    e = ends.view(1);
    e[0].numsendopen = 0;
    e[0].numrecvopen = 0;
    e[0].send = ptr[_channelend]();
    e[0].recv = ptr[_channelend]();
    return ends;
}

impl _channelends_clear(ends: ptr[_channelends]) {
    e = ends.view(1);
    _channelend_free_all(e[0].send);
    e[0].send = ptr[_channelend]();
    e[0].numsendopen = 0;

    _channelend_free_all(e[0].recv);
    e[0].recv = ptr[_channelend]();
    e[0].numrecvopen = 0;
}

impl _channelends_free(ends: ptr[_channelends]) {
    _channelends_clear(ends);
    PyMem_RawFree(ptr(ends));
}

impl _channelends_add(
    ends: ptr[_channelends], prev: ptr[_channelend], interpid: i64, send: i32
) -> ptr[_channelend] {
    end = _channelend_new(interpid);
    if not end {
        return ptr[_channelend]();
    }

    e = ends.view(1);
    if not prev {
        if send != 0 {
            e[0].send = end;
        } else {
            e[0].recv = end;
        }
    } else {
        prev.view(1)[0].next = end;
    }
    if send != 0 {
        e[0].numsendopen += 1;
    } else {
        e[0].numrecvopen += 1;
    }
    return end;
}

impl _channelends_associate(ends: ptr[_channelends], interpid: i64, send: i32) -> i32 {
    e = ends.view(1);
    first = e[0].recv;
    if send != 0 {
        first = e[0].send;
    }
    (end, prev) = _channelend_find(first, interpid);
    if end {
        if end.view(1)[0].open == 0 {
            return ERR_CHANNEL_CLOSED;
        }
        return 0;
    }
    if not _channelends_add(ends, prev, interpid, send) {
        return -1;
    }
    return 0;
}

impl _channelends_is_open(ends: ptr[_channelends]) -> i32 {
    e = ends.view(1);
    if e[0].numsendopen != 0 or e[0].numrecvopen != 0 {
        return 1;
    }
    if not e[0].send and not e[0].recv {
        return 1;
    }
    return 0;
}

impl _channelends_release_end(
    ends: ptr[_channelends], end: ptr[_channelend], send: i32
) {
    end.view(1)[0].open = 0;
    e = ends.view(1);
    if send != 0 {
        e[0].numsendopen -= 1;
    } else {
        e[0].numrecvopen -= 1;
    }
}

impl _channelends_release_interpreter(
    ends: ptr[_channelends], interpid: i64, which: i32
) -> i32 {
    e = ends.view(1);
    if which >= 0 {
        (end, prev) = _channelend_find(e[0].send, interpid);
        if not end {
            end = _channelends_add(ends, prev, interpid, 1);
            if not end {
                return -1;
            }
        }
        _channelends_release_end(ends, end, 1);
    }
    if which <= 0 {
        (rend, rprev) = _channelend_find(e[0].recv, interpid);
        if not rend {
            rend = _channelends_add(ends, rprev, interpid, 0);
            if not rend {
                return -1;
            }
        }
        _channelends_release_end(ends, rend, 0);
    }
    return 0;
}

impl _channelends_release_all(ends: ptr[_channelends], which: i32, force: i32) {
    e = ends.view(1);
    end = e[0].send;
    while end {
        _channelends_release_end(ends, end, 1);
        end = end.view(1)[0].next;
    }

    end = e[0].recv;
    while end {
        _channelends_release_end(ends, end, 0);
        end = end.view(1)[0].next;
    }
}

impl _channelends_clear_interpreter(ends: ptr[_channelends], interpid: i64) {
    e = ends.view(1);
    (end, prev) = _channelend_find(e[0].send, interpid);
    if end {
        _channelends_release_end(ends, end, 1);
    }
    (rend, rprev) = _channelend_find(e[0].recv, interpid);
    if rend {
        _channelends_release_end(ends, rend, 0);
    }
}

impl _channel_new(mutex: ptr, unboundop: i32, fallback: i32) -> ptr[_channel_state] {
    chan = ptr[_channel_state](PyMem_RawMalloc(CHANNEL_STATE_SIZE));
    if not chan {
        return ptr[_channel_state]();
    }
    c = chan.view(1);
    c[0].mutex = mutex;
    c[0].queue = _channelqueue_new();
    if not c[0].queue {
        PyMem_RawFree(ptr(chan));
        return ptr[_channel_state]();
    }
    c[0].ends = _channelends_new();
    if not c[0].ends {
        _channelqueue_free(c[0].queue);
        PyMem_RawFree(ptr(chan));
        return ptr[_channel_state]();
    }
    c[0].defaults_unboundop = unboundop;
    c[0].defaults_fallback = fallback;
    c[0].open = 1;
    c[0].closing = ptr[_channel_closing]();
    return chan;
}

impl _channel_free(chan: ptr[_channel_state]) {
    _channel_clear_closing(chan);
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);
    _channelqueue_free(c[0].queue);
    _channelends_free(c[0].ends);
    PyThread_release_lock(c[0].mutex);

    PyThread_free_lock(c[0].mutex);
    PyMem_RawFree(ptr(chan));
}

impl _channel_add(
    chan: ptr[_channel_state],
    interpid: i64,
    data: ptr[_PyXIData_t],
    waiting: ptr[_waiting_t],
    unboundop: i32
) -> i32 {
    res: i32 = -1;
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);

    if c[0].open == 0 {
        res = ERR_CHANNEL_CLOSED;
    } elif _channelends_associate(c[0].ends, interpid, 1) != 0 {
        res = ERR_CHANNEL_INTERP_CLOSED;
    } elif _channelqueue_put(c[0].queue, interpid, data, waiting, unboundop) == 0 {
        res = 0;
    }

    PyThread_release_lock(c[0].mutex);
    return res;
}

impl _channel_next(
    chan: ptr[_channel_state], interpid: i64
) -> tuple[i32, ptr[_PyXIData_t], ptr[_waiting_t], i32] {
    err: i32 = 0;
    data = ptr[_PyXIData_t]();
    waiting = ptr[_waiting_t]();
    unboundop: i32 = 0;
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);

    if c[0].open == 0 {
        err = ERR_CHANNEL_CLOSED;
    } elif _channelends_associate(c[0].ends, interpid, 0) != 0 {
        err = ERR_CHANNEL_INTERP_CLOSED;
    } else {
        (empty, data, waiting, unboundop) = _channelqueue_get(c[0].queue);
        if empty != 0 {
            if c[0].closing {
                c[0].open = 0;
            }
            err = ERR_CHANNEL_EMPTY;
        }
    }

    PyThread_release_lock(c[0].mutex);
    if c[0].queue.view(1)[0].count == 0 {
        _channel_finish_closing(chan);
    }
    return (err, data, waiting, unboundop);
}

impl _channel_remove(chan: ptr[_channel_state], itemid: u64) {
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);
    (data, waiting) = _channelqueue_remove(c[0].queue, itemid);
    PyThread_release_lock(c[0].mutex);

    _release_xid_data(data, XID_IGNORE_EXC | XID_FREE);
    if waiting {
        _waiting_release(waiting, 0);
    }

    if c[0].queue.view(1)[0].count == 0 {
        _channel_finish_closing(chan);
    }
}

impl _channel_release_interpreter(
    chan: ptr[_channel_state], interpid: i64, end: i32
) -> i32 {
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);

    res: i32 = -1;
    if c[0].open == 0 {
        res = ERR_CHANNEL_CLOSED;
    } elif _channelends_release_interpreter(c[0].ends, interpid, end) == 0 {
        c[0].open = _channelends_is_open(c[0].ends);
        res = 0;
    }

    PyThread_release_lock(c[0].mutex);
    return res;
}

impl _channel_release_all(chan: ptr[_channel_state], end: i32, force: i32) -> i32 {
    res: i32 = -1;
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);

    if c[0].open == 0 {
        res = ERR_CHANNEL_CLOSED;
    } elif force == 0 and c[0].queue.view(1)[0].count > 0 {
        res = ERR_CHANNEL_NOT_EMPTY;
    } else {
        c[0].open = 0;
        _channelends_release_all(c[0].ends, end, force);
        res = 0;
    }

    PyThread_release_lock(c[0].mutex);
    return res;
}

impl _channel_clear_interpreter(chan: ptr[_channel_state], interpid: i64) {
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);

    _channelqueue_clear_interpreter(c[0].queue, interpid);
    _channelends_clear_interpreter(c[0].ends, interpid);
    c[0].open = _channelends_is_open(c[0].ends);

    PyThread_release_lock(c[0].mutex);
}

impl _channelref_new(cid: i64, chan: ptr[_channel_state]) -> ptr[_channelref] {
    ref = ptr[_channelref](PyMem_RawMalloc(CHANNELREF_SIZE));
    if not ref {
        return ptr[_channelref]();
    }
    r = ref.view(1);
    r[0].cid = cid;
    r[0].chan = chan;
    r[0].next = ptr[_channelref]();
    r[0].objcount = 0;
    return ref;
}

impl _channelref_free(ref: ptr[_channelref]) {
    if ref.view(1)[0].chan {
        _channel_clear_closing(ref.view(1)[0].chan);
    }
    PyMem_RawFree(ptr(ref));
}

impl _channelref_find(
    first: ptr[_channelref], cid: i64
) -> tuple[ptr[_channelref], ptr[_channelref]] {
    prev = ptr[_channelref]();
    ref = first;
    while ref {
        if ref.view(1)[0].cid == cid {
            break;
        }
        prev = ref;
        ref = ref.view(1)[0].next;
    }
    return (ref, prev);
}

impl _channels_init(channels: ptr[_channels], mutex: ptr) {
    ch = channels.view(1);
    ch[0].mutex = mutex;
    ch[0].head = ptr[_channelref]();
    ch[0].numopen = 0;
    ch[0].next_id = 0;
}

impl _channels_fini(channels: ptr[_channels]) -> ptr {
    ch = channels.view(1);
    mutex = ch[0].mutex;

    PyThread_acquire_lock(mutex, WAIT_LOCK);
    ch[0].mutex = ptr();
    ch[0].head = ptr[_channelref]();
    ch[0].numopen = 0;
    ch[0].next_id = 0;
    PyThread_release_lock(mutex);

    return mutex;
}

impl _channels_next_id(channels: ptr[_channels]) -> i64 {
    ch = channels.view(1);
    cid = ch[0].next_id;
    if cid < 0 {
        return -1;
    }
    ch[0].next_id = wrapping_add(cid, i64(1));
    return cid;
}

impl _channels_lookup(
    channels: ptr[_channels], cid: i64, want_mutex: bool
) -> tuple[i32, ptr, ptr[_channel_state]] {
    err: i32 = -1;
    chan = ptr[_channel_state]();
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);
    pmutex = ptr();

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if not ref {
        err = ERR_CHANNEL_NOT_FOUND;
    } elif not ref.view(1)[0].chan or ref.view(1)[0].chan.view(1)[0].open == 0 {
        err = ERR_CHANNEL_CLOSED;
    } else {
        if want_mutex {
            pmutex = ch[0].mutex;
        }
        chan = ref.view(1)[0].chan;
        err = 0;
    }

    if not want_mutex or not pmutex {
        PyThread_release_lock(ch[0].mutex);
    }
    return (err, pmutex, chan);
}

impl _channels_add(channels: ptr[_channels], chan: ptr[_channel_state]) -> i64 {
    cid: i64 = -1;
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    _cid = _channels_next_id(channels);
    if _cid < 0 {
        cid = i64(ERR_NO_NEXT_CHANNEL_ID);
    } else {
        ref = _channelref_new(_cid, chan);
        if ref {
            ref.view(1)[0].next = ch[0].head;
            ch[0].head = ref;
            ch[0].numopen += 1;
            cid = _cid;
        }
    }

    PyThread_release_lock(ch[0].mutex);
    return cid;
}

impl _channels_close(
    channels: ptr[_channels], cid: i64, want_chan: bool, end: i32, force: i32
) -> tuple[i32, ptr[_channel_state]] {
    res: i32 = -1;
    pchan = ptr[_channel_state]();
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if not ref {
        res = ERR_CHANNEL_NOT_FOUND;
    } elif not ref.view(1)[0].chan {
        res = ERR_CHANNEL_CLOSED;
    } elif force == 0
        and end == CHANNEL_SEND
        and ref.view(1)[0].chan.view(1)[0].closing {
        res = ERR_CHANNEL_CLOSED;
    } else {
        err = _channel_release_all(ref.view(1)[0].chan, end, force);
        if err != 0 {
            if end == CHANNEL_SEND and err == ERR_CHANNEL_NOT_EMPTY {
                if ref.view(1)[0].chan.view(1)[0].closing {
                    res = ERR_CHANNEL_CLOSED;
                } else {
                    PyErr_Clear();
                    err2 = _channel_set_closing(ref, ch[0].mutex);
                    if err2 != 0 {
                        res = err2;
                    } else {
                        if want_chan {
                            pchan = ref.view(1)[0].chan;
                        }
                        res = 0;
                    }
                }
            } else {
                res = err;
            }
        } else {
            if want_chan {
                pchan = ref.view(1)[0].chan;
            } else {
                _channel_free(ref.view(1)[0].chan);
            }
            ref.view(1)[0].chan = ptr[_channel_state]();
            res = 0;
        }
    }

    PyThread_release_lock(ch[0].mutex);
    return (res, pchan);
}

impl _channels_remove_ref(
    channels: ptr[_channels], ref: ptr[_channelref], prev: ptr[_channelref]
) -> ptr[_channel_state] {
    ch = channels.view(1);
    if ref == ch[0].head {
        ch[0].head = ref.view(1)[0].next;
    } else {
        prev.view(1)[0].next = ref.view(1)[0].next;
    }
    ch[0].numopen -= 1;

    pchan = ref.view(1)[0].chan;
    _channelref_free(ref);
    return pchan;
}

impl _channels_remove(
    channels: ptr[_channels], cid: i64
) -> tuple[i32, ptr[_channel_state]] {
    res: i32 = -1;
    pchan = ptr[_channel_state]();
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if not ref {
        res = ERR_CHANNEL_NOT_FOUND;
    } else {
        pchan = _channels_remove_ref(channels, ref, prev);
        res = 0;
    }

    PyThread_release_lock(ch[0].mutex);
    return (res, pchan);
}

impl _channels_add_id_object(channels: ptr[_channels], cid: i64) -> i32 {
    res: i32 = -1;
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if not ref {
        res = ERR_CHANNEL_NOT_FOUND;
    } else {
        ref.view(1)[0].objcount += 1;
        res = 0;
    }

    PyThread_release_lock(ch[0].mutex);
    return res;
}

impl _channels_release_cid_object(channels: ptr[_channels], cid: i64) {
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if ref {
        ref.view(1)[0].objcount -= 1;

        if ref.view(1)[0].objcount == 0 {
            chan = _channels_remove_ref(channels, ref, prev);
            if chan {
                _channel_free(chan);
            }
        }
    }

    PyThread_release_lock(ch[0].mutex);
}

impl _channels_list_all(
    channels: ptr[_channels]
) -> tuple[ptr[channel_id_and_info], i64] {
    cids = ptr[channel_id_and_info]();
    count: i64 = 0;
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);
    numopen = ch[0].numopen;
    ids = ptr[channel_id_and_info]();
    if numopen <= PY_SSIZE_T_MAX // CHANNEL_ID_AND_INFO_SIZE {
        ids = ptr[channel_id_and_info](
            PyMem_Malloc(u64(numopen * CHANNEL_ID_AND_INFO_SIZE))
        );
    }
    if ids {
        i: i64 = 0;
        ref = ch[0].head;
        while ref {
            chan = ref.view(1)[0].chan;
            if chan {
                slot = (ids + i).view(1);
                slot[0].id = ref.view(1)[0].cid;
                slot[0].defaults_unboundop = chan.view(1)[0].defaults_unboundop;
                slot[0].defaults_fallback = chan.view(1)[0].defaults_fallback;
                i += 1;
            }
            ref = ref.view(1)[0].next;
        }
        count = i;
        cids = ids;
    }
    PyThread_release_lock(ch[0].mutex);
    return (cids, count);
}

impl _channels_clear_interpreter(channels: ptr[_channels], interpid: i64) {
    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    ref = ch[0].head;
    while ref {
        if ref.view(1)[0].chan {
            _channel_clear_interpreter(ref.view(1)[0].chan, interpid);
        }
        ref = ref.view(1)[0].next;
    }

    PyThread_release_lock(ch[0].mutex);
}

impl _channel_set_closing(ref: ptr[_channelref], mutex: ptr) -> i32 {
    chan = ref.view(1)[0].chan;
    if not chan {
        return 0;
    }
    res: i32 = -1;
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);
    if c[0].closing {
        res = ERR_CHANNEL_CLOSED;
    } else {
        c[0].closing = ptr[_channel_closing](PyMem_RawMalloc(CHANNEL_CLOSING_SIZE));
        if c[0].closing {
            c[0].closing.view(1)[0].ref = ref;
            res = 0;
        }
    }
    PyThread_release_lock(c[0].mutex);
    return res;
}

impl _channel_clear_closing(chan: ptr[_channel_state]) {
    c = chan.view(1);
    PyThread_acquire_lock(c[0].mutex, WAIT_LOCK);
    if c[0].closing {
        PyMem_RawFree(ptr(c[0].closing));
        c[0].closing = ptr[_channel_closing]();
    }
    PyThread_release_lock(c[0].mutex);
}

impl _channel_finish_closing(chan: ptr[_channel_state]) {
    closing = chan.view(1)[0].closing;
    if not closing {
        return;
    }
    ref = closing.view(1)[0].ref;
    _channel_clear_closing(chan);
    ref.view(1)[0].chan = ptr[_channel_state]();
    _channel_free(chan);
}

impl channel_create(channels: ptr[_channels], unboundop: i32, fallback: i32) -> i64 {
    mutex = PyThread_allocate_lock();
    if not mutex {
        return i64(ERR_CHANNEL_MUTEX_INIT);
    }
    chan = _channel_new(mutex, unboundop, fallback);
    if not chan {
        PyThread_free_lock(mutex);
        return -1;
    }
    cid = _channels_add(channels, chan);
    if cid < 0 {
        _channel_free(chan);
    }
    return cid;
}

impl channel_destroy(channels: ptr[_channels], cid: i64) -> i32 {
    (err, chan) = _channels_remove(channels, cid);
    if err != 0 {
        return err;
    }
    if chan {
        _channel_free(chan);
    }
    return 0;
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl channel_send(
    channels: ptr[_channels],
    cid: i64,
    obj_: ptr[PyObject],
    waiting: ptr[_waiting_t],
    unboundop: i32,
    fallback: i32
) -> i32 {
    tstate = thread_state();
    interp = tstate_interp(tstate);
    interpid = PyInterpreterState_GetID(interp);

    (err, mutex, chan) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return err;
    }

    if chan.view(1)[0].closing {
        PyThread_release_lock(mutex);
        return ERR_CHANNEL_CLOSED;
    }

    data = _PyXIData_New();
    if not data {
        PyThread_release_lock(mutex);
        return -1;
    }
    if _PyObject_GetXIData(tstate, obj_, fallback, data) != 0 {
        PyThread_release_lock(mutex);
        PyMem_RawFree(ptr(data));
        return -1;
    }

    res = _channel_add(chan, interpid, data, waiting, unboundop);
    PyThread_release_lock(mutex);
    if res != 0 {
        _release_xid_data(data, 0);
        PyMem_RawFree(ptr(data));
        return res;
    }

    return 0;
}

impl channel_clear_sent(channels: ptr[_channels], cid: i64, waiting: ptr[_waiting_t]) {
    (err, mutex, chan) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return;
    }

    itemid = _waiting_get_itemid(waiting);
    _channel_remove(chan, itemid);

    PyThread_release_lock(mutex);
}

impl channel_send_wait(
    channels: ptr[_channels],
    cid: i64,
    obj_: ptr[PyObject],
    unboundop: i32,
    timeout: i64,
    fallback: i32
) -> i32 {
    slots: own ChannelsStack = ChannelsStack();
    waiting = ptr[_waiting_t](jacpy_stack_address(&mut slots));
    if _waiting_init(waiting) < 0 {
        return -1;
    }

    res = channel_send(channels, cid, obj_, waiting, unboundop, fallback);
    if res < 0 {
        _waiting_clear(waiting);
        return res;
    }

    if wait_for_lock(waiting.view(1)[0].mutex, timeout) < 0 {
        _waiting_finish_releasing(waiting);
        channel_clear_sent(channels, cid, waiting);
        if __atomic_load_i32(int(waiting) + WAITING_T_RECEIVED, 5) == 0 {
            _waiting_clear(waiting);
            return -1;
        }
        PyErr_Clear();
    } else {
        _waiting_finish_releasing(waiting);
        if __atomic_load_i32(int(waiting) + WAITING_T_RECEIVED, 5) == 0 {
            _waiting_clear(waiting);
            return ERR_CHANNEL_CLOSED_WAITING;
        }
    }

    _waiting_clear(waiting);
    return 0;
}

impl channel_recv(
    channels: ptr[_channels], cid: i64
) -> tuple[i32, ptr[PyObject], i32] {
    interp = _get_current_interp();
    if not interp {
        if PyErr_Occurred() {
            return (i32(-1), NULL, i32(0));
        }
        return (i32(0), NULL, i32(0));
    }
    interpid = PyInterpreterState_GetID(interp);

    (err, mutex, chan) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return (err, NULL, i32(0));
    }

    (err2, data, waiting, unboundop) = _channel_next(chan, interpid);
    PyThread_release_lock(mutex);
    if err2 != 0 {
        return (err2, NULL, unboundop);
    } elif not data {
        return (i32(0), NULL, unboundop);
    }

    obj_ = _PyXIData_NewObject(data);
    if not obj_ {
        _release_xid_data(data, XID_IGNORE_EXC | XID_FREE);
        if waiting {
            _waiting_release(waiting, 0);
        }
        return (i32(-1), NULL, unboundop);
    }
    release_res = _release_xid_data(data, XID_FREE);
    if release_res < 0 {
        object_decref(obj_);
        if waiting {
            _waiting_release(waiting, 0);
        }
        return (i32(-1), NULL, unboundop);
    }

    if waiting {
        _waiting_release(waiting, 1);
    }

    return (i32(0), obj_, unboundop);
}

impl channel_release(channels: ptr[_channels], cid: i64, send: i32, recv: i32) -> i32 {
    interp = _get_current_interp();
    if not interp {
        return -1;
    }
    interpid = PyInterpreterState_GetID(interp);

    (err, mutex, chan) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return err;
    }

    res = _channel_release_interpreter(chan, interpid, send - recv);
    PyThread_release_lock(mutex);
    return res;
}

impl channel_close(channels: ptr[_channels], cid: i64, end: i32, force: i32) -> i32 {
    (res, pchan) = _channels_close(channels, cid, False, end, force);
    return res;
}

impl channel_is_associated(
    channels: ptr[_channels], cid: i64, interpid: i64, send: i32
) -> i32 {
    (err, mutex, chan) = _channels_lookup(channels, cid, False);
    if err != 0 {
        return err;
    } elif send != 0 and chan.view(1)[0].closing {
        return ERR_CHANNEL_CLOSED;
    }

    ends = chan.view(1)[0].ends.view(1);
    first = ends[0].recv;
    if send != 0 {
        first = ends[0].send;
    }
    (end, prev) = _channelend_find(first, interpid);

    if end and end.view(1)[0].open != 0 {
        return 1;
    }
    return 0;
}

impl channel_get_defaults(channels: ptr[_channels], cid: i64) -> tuple[i32, i32, i32] {
    (err, mutex, channel) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return (err, i32(0), i32(0));
    }
    unboundop = channel.view(1)[0].defaults_unboundop;
    fallback = channel.view(1)[0].defaults_fallback;
    PyThread_release_lock(mutex);
    return (i32(0), unboundop, fallback);
}

impl _channel_get_count(channels: ptr[_channels], cid: i64) -> tuple[i32, i64] {
    (err, mutex, chan) = _channels_lookup(channels, cid, True);
    if err != 0 {
        return (err, i64(-1));
    }
    count = chan.view(1)[0].queue.view(1)[0].count;
    PyThread_release_lock(mutex);

    return (i32(0), count);
}

impl _channel_get_info(
    channels: ptr[_channels], cid: i64, info: ptr[channel_info]
) -> i32 {
    err: i32 = 0;
    inf = info.view(1);
    inf[0].closed = 0;
    inf[0].nsend_only = 0;
    inf[0].nsend_only_released = 0;
    inf[0].nrecv_only = 0;
    inf[0].nrecv_only_released = 0;
    inf[0].nboth = 0;
    inf[0].nboth_released = 0;
    inf[0].nboth_send_released = 0;
    inf[0].nboth_recv_released = 0;
    inf[0].cur_send = 0;
    inf[0].cur_recv = 0;
    inf[0].count = 0;

    interp = _get_current_interp();
    if not interp {
        return -1;
    }
    interpid = PyInterpreterState_GetID(interp);

    ch = channels.view(1);
    PyThread_acquire_lock(ch[0].mutex, WAIT_LOCK);

    (ref, prev) = _channelref_find(ch[0].head, cid);
    if not ref {
        PyThread_release_lock(ch[0].mutex);
        return ERR_CHANNEL_NOT_FOUND;
    }
    chan = ref.view(1)[0].chan;

    if not chan {
        inf[0].closed = 1;
        PyThread_release_lock(ch[0].mutex);
        return err;
    }
    c = chan.view(1);
    if c[0].open == 0 {
        inf[0].closed = 1;
        PyThread_release_lock(ch[0].mutex);
        return err;
    }
    if c[0].closing {
        inf[0].closed = -1;
    } else {
        inf[0].closed = 0;
    }

    inf[0].count = c[0].queue.view(1)[0].count;

    send = c[0].ends.view(1)[0].send;
    while send {
        s = send.view(1);
        if s[0].interpid == interpid {
            if s[0].open != 0 {
                inf[0].cur_send = 1;
            } else {
                inf[0].cur_send = -1;
            }
        }

        if s[0].open != 0 {
            inf[0].nsend_only += 1;
        } else {
            inf[0].nsend_only_released += 1;
        }
        send = s[0].next;
    }
    recv = c[0].ends.view(1)[0].recv;
    while recv {
        r = recv.view(1);
        if r[0].interpid == interpid {
            if r[0].open != 0 {
                inf[0].cur_recv = 1;
            } else {
                inf[0].cur_recv = -1;
            }
        }

        match_send = c[0].ends.view(1)[0].send;
        while match_send {
            if match_send.view(1)[0].interpid == r[0].interpid {
                break;
            }
            match_send = match_send.view(1)[0].next;
        }
        if not match_send {
            if r[0].open != 0 {
                inf[0].nrecv_only += 1;
            } else {
                inf[0].nrecv_only_released += 1;
            }
        } else {
            if r[0].open != 0 {
                if match_send.view(1)[0].open != 0 {
                    inf[0].nboth += 1;
                    inf[0].nsend_only -= 1;
                } else {
                    inf[0].nboth_recv_released += 1;
                    inf[0].nsend_only_released -= 1;
                }
            } else {
                if match_send.view(1)[0].open != 0 {
                    inf[0].nboth_send_released += 1;
                    inf[0].nsend_only -= 1;
                } else {
                    inf[0].nboth_released += 1;
                    inf[0].nsend_only_released -= 1;
                }
            }
        }
        recv = r[0].next;
    }

    PyThread_release_lock(ch[0].mutex);
    return err;
}

impl info_bool(cond: bool) -> ptr[PyObject] {
    if cond {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl info_set_count(self_: ptr[PyObject], pos: i64, val: i64) -> bool {
    obj_ = PyLong_FromLongLong(val);
    if not obj_ {
        return False;
    }
    PyStructSequence_SetItem(self_, pos, obj_);
    return True;
}

impl new_channel_info(mod: ptr[PyObject], info: ptr[channel_info]) -> ptr[PyObject] {
    state = get_module_state(mod);
    if not state {
        return NULL;
    }

    self_ = PyStructSequence_New(ptr[PyObject](state.view(1)[0].ChannelInfoType));
    if not self_ {
        return NULL;
    }

    inf = info.view(1);
    PyStructSequence_SetItem(self_, 0, info_bool(inf[0].closed == 0));
    PyStructSequence_SetItem(self_, 1, info_bool(inf[0].closed == -1));
    PyStructSequence_SetItem(self_, 2, info_bool(inf[0].closed == 1));
    if not info_set_count(self_, 3, inf[0].count)
        or not info_set_count(self_, 4, inf[0].nsend_only)
        or not info_set_count(self_, 5, inf[0].nsend_only_released)
        or not info_set_count(self_, 6, inf[0].nrecv_only)
        or not info_set_count(self_, 7, inf[0].nrecv_only_released)
        or not info_set_count(self_, 8, inf[0].nboth)
        or not info_set_count(self_, 9, inf[0].nboth_released)
        or not info_set_count(self_, 10, inf[0].nboth_send_released)
        or not info_set_count(self_, 11, inf[0].nboth_recv_released) {
        object_decref(self_);
        return NULL;
    }
    PyStructSequence_SetItem(self_, 12, info_bool(inf[0].cur_send == 1));
    PyStructSequence_SetItem(self_, 13, info_bool(inf[0].cur_send == -1));
    PyStructSequence_SetItem(self_, 14, info_bool(inf[0].cur_recv == 1));
    PyStructSequence_SetItem(self_, 15, info_bool(inf[0].cur_recv == -1));
    return self_;
}

impl channel_id_converter(arg: ptr[PyObject], ptr_: ptr) -> i32 {
    cid: i64 = 0;
    end: i32 = 0;
    data = ptr[channel_id_converter_data](ptr_).view(1);
    state = get_module_state(data[0].module);
    if object_type_check(arg, state.view(1)[0].ChannelIDType) {
        cid = ptr[channelid](arg).view(1)[0].cid;
        end = ptr[channelid](arg).view(1)[0].end;
    } elif PyIndex_Check(arg) != 0 {
        cid = PyLong_AsLongLong(arg);
        if cid == -1 and PyErr_Occurred() {
            return 0;
        }
        if cid < 0 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("channel ID must be a non-negative int, got %R"),
                arg
            );
            return 0;
        }
    } else {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("channel ID must be an int, got %.100s"),
            object_type(arg).view(1)[0].tp_name
        );
        return 0;
    }
    data[0].cid = cid;
    data[0].end = end;
    return 1;
}

impl newchannelid(
    cls: ptr[PyTypeObject],
    cid: i64,
    end: i32,
    channels: ptr[_channels],
    force: i32,
    resolve: i32
) -> tuple[i32, ptr[PyObject]] {
    self_ = _PyObject_New(ptr[PyObject](cls));
    if not self_ {
        return (i32(-1), NULL);
    }
    s = ptr[channelid](self_).view(1);
    s[0].cid = cid;
    s[0].end = end;
    s[0].resolve = resolve;
    s[0].channels = channels;

    err = _channels_add_id_object(channels, cid);
    if err != 0 {
        if not (force != 0 and err == ERR_CHANNEL_NOT_FOUND) {
            object_decref(self_);
            return (err, NULL);
        }
    }

    return (i32(0), self_);
}

impl _global_channels -> ptr[_channels] {
    return ptr[_channels](ptr[u8](addressof(_globals)) + GLOBALS_CHANNELS);
}

impl converter_data(
    slots: ptr[u8], mod: ptr[PyObject]
) -> ptr[channel_id_converter_data] {
    data = ptr[channel_id_converter_data](slots);
    data.view(1)[0].module = mod;
    data.view(1)[0].cid = 0;
    data.view(1)[0].end = 0;
    return data;
}

impl _channelid_new(
    mod: ptr[PyObject], cls: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), mod);
    send = i32(-1);
    recv = i32(-1);
    force = i32(0);
    resolve = i32(0);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&|$pppp:ChannelID.__new__"),
        ptr(addressof(channelid_new_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data),
        &mut send,
        &mut recv,
        &mut force,
        &mut resolve
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;
    end = cid_data.view(1)[0].end;

    if send == 0 and recv == 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("'send' and 'recv' cannot both be False")
        );
        return NULL;
    } elif send == 1 {
        if recv == 0 or recv == -1 {
            end = CHANNEL_SEND;
        } else {
            end = 0;
        }
    } elif recv == 1 {
        end = CHANNEL_RECV;
    }

    (err, cidobj) = newchannelid(cls, cid, end, _global_channels(), force, resolve);
    if handle_channel_error(err, mod, cid) != 0 {
        return NULL;
    }
    return cidobj;
}

impl channelid_dealloc(op: ptr[PyObject]) {
    s = ptr[channelid](op).view(1);
    cid = s[0].cid;
    channels = s[0].channels;

    tp = object_type(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));

    _channels_release_cid_object(channels, cid);
}

impl channelid_repr(self_: ptr[PyObject]) -> ptr[PyObject] {
    type = object_type(self_);
    name = _PyType_Name(ptr[PyObject](type));

    cidobj = ptr[channelid](self_).view(1);
    cid = cidobj[0].cid;
    if cidobj[0].end == CHANNEL_SEND {
        return PyUnicode_FromFormat("%s(%ld, send=True)", name, cid);
    } elif cidobj[0].end == CHANNEL_RECV {
        return PyUnicode_FromFormat("%s(%ld, recv=True)", name, cid);
    }
    return PyUnicode_FromFormat("%s(%ld)", name, cid);
}

impl channelid_str(self_: ptr[PyObject]) -> ptr[PyObject] {
    cid = ptr[channelid](self_).view(1)[0].cid;
    return PyUnicode_FromFormat("%ld", cid);
}

impl channelid_int(self_: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLongLong(ptr[channelid](self_).view(1)[0].cid);
}

impl channelid_hash(self_: ptr[PyObject]) -> i64 {
    pyid = PyLong_FromLongLong(ptr[channelid](self_).view(1)[0].cid);
    if not pyid {
        return -1;
    }
    hash = PyObject_Hash(pyid);
    object_decref(pyid);
    return hash;
}

impl channelid_richcompare(
    self_: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    res = NULL;
    if op != Py_EQ and op != Py_NE {
        return object_new_ref(Py_NotImplemented);
    }

    mod = get_module_from_type(object_type(self_));
    if not mod {
        return NULL;
    }
    state = get_module_state(mod);
    if not state {
        object_decref(mod);
        return res;
    }
    idtype = state.view(1)[0].ChannelIDType;

    if not object_type_check(self_, idtype) {
        object_decref(mod);
        return object_new_ref(Py_NotImplemented);
    }

    cidobj = ptr[channelid](self_).view(1);
    equal = False;
    if object_type_check(other, idtype) {
        othercidobj = ptr[channelid](other).view(1);
        equal = cidobj[0].end == othercidobj[0].end
            and cidobj[0].cid == othercidobj[0].cid;
    } elif long_check(other) {
        overflow: i32 = 0;
        othercid = PyLong_AsLongLongAndOverflow(other, &mut overflow);
        if othercid == -1 and PyErr_Occurred() {
            object_decref(mod);
            return res;
        }
        equal = overflow == 0 and othercid >= 0 and cidobj[0].cid == othercid;
    } elif PyNumber_Check(other) != 0 {
        pyid = PyLong_FromLongLong(cidobj[0].cid);
        if not pyid {
            object_decref(mod);
            return res;
        }
        res = PyObject_RichCompare(pyid, other, op);
        object_decref(pyid);
        object_decref(mod);
        return res;
    } else {
        object_decref(mod);
        return object_new_ref(Py_NotImplemented);
    }

    if (op == Py_EQ and equal) or (op == Py_NE and not equal) {
        res = PyBool_FromLong(1);
    } else {
        res = PyBool_FromLong(0);
    }

    object_decref(mod);
    return res;
}

impl _channelobj_from_cidobj(cidobj: ptr[PyObject], end: i32) -> ptr[PyObject] {
    cls = ptr[PyObject](_get_current_channelend_type(end));
    if not cls {
        return NULL;
    }
    chan = PyObject_CallFunctionObjArgs(cls, cidobj, NULL);
    object_decref(cls);
    if not chan {
        return NULL;
    }
    return chan;
}

impl _channelid_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject] {
    xid = ptr[_channelid_xid](data.view(1)[0].data).view(1);

    mod = PyImport_ImportModule(ptr[u8]("_interpchannels"));
    if not mod {
        return NULL;
    }
    state = get_module_state(mod);
    if not state {
        object_decref(mod);
        return NULL;
    }

    (err, cidobj) = newchannelid(
        state.view(1)[0].ChannelIDType, xid[0].cid, xid[0].end, _global_channels(), 0, 0
    );
    if err != 0 {
        handle_channel_error(err, mod, xid[0].cid);
        object_decref(mod);
        return cidobj;
    }
    if xid[0].end == 0 or xid[0].resolve == 0 {
        object_decref(mod);
        return cidobj;
    }

    chan = _channelobj_from_cidobj(cidobj, xid[0].end);
    if not chan {
        PyErr_Clear();
        object_decref(mod);
        return cidobj;
    }
    object_decref(cidobj);

    object_decref(mod);
    return chan;
}

impl _channelid_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32 {
    if _PyXIData_InitWithSize(
        data, tstate_interp(tstate), CHANNELID_XID_SIZE, obj_, ptr(_channelid_from_xid)
    )
        < 0 {
        return -1;
    }
    xid = ptr[_channelid_xid](data.view(1)[0].data).view(1);
    cidobj = ptr[channelid](obj_).view(1);
    xid[0].cid = cidobj[0].cid;
    xid[0].end = cidobj[0].end;
    xid[0].resolve = cidobj[0].resolve;
    return 0;
}

impl channelid_end(self_: ptr[PyObject], end: ptr) -> ptr[PyObject] {
    force: i32 = 1;
    cidobj = ptr[channelid](self_).view(1);
    if end {
        (err, obj_) = newchannelid(
            object_type(self_),
            cidobj[0].cid,
            ptr[i32](end).view(1)[0],
            cidobj[0].channels,
            force,
            cidobj[0].resolve
        );
        if err != 0 {
            mod = get_module_from_type(object_type(self_));
            if not mod {
                return NULL;
            }
            handle_channel_error(err, mod, cidobj[0].cid);
            object_decref(mod);
            return NULL;
        }
        return obj_;
    }

    if cidobj[0].end == CHANNEL_SEND {
        return PyUnicode_InternFromString(ptr[u8]("send"));
    }
    if cidobj[0].end == CHANNEL_RECV {
        return PyUnicode_InternFromString(ptr[u8]("recv"));
    }
    return PyUnicode_InternFromString(ptr[u8]("both"));
}

impl add_channelid_type(mod: ptr[PyObject]) -> ptr[PyTypeObject] {
    cls = PyType_FromModuleAndSpec(mod, addressof(channelid_typespec), NULL);
    if not cls {
        return ptr[PyTypeObject]();
    }
    if PyModule_AddType(mod, cls) < 0 {
        object_decref(cls);
        return ptr[PyTypeObject]();
    }
    if ensure_xid_class(ptr[PyTypeObject](cls), ptr(_channelid_shared)) < 0 {
        object_decref(cls);
        return ptr[PyTypeObject]();
    }
    return ptr[PyTypeObject](cls);
}

impl _get_current_channelend_type(end: i32) -> ptr[PyTypeObject] {
    state = _get_current_module_state();
    if not state {
        return ptr[PyTypeObject]();
    }
    st = state.view(1);
    cls = st[0].recv_channel_type;
    if end == CHANNEL_SEND {
        cls = st[0].send_channel_type;
    }
    if not cls {
        if ensure_highlevel_module_loaded() < 0 {
            return ptr[PyTypeObject]();
        }
        if end == CHANNEL_SEND {
            cls = st[0].send_channel_type;
        } else {
            cls = st[0].recv_channel_type;
        }
    }
    return cls;
}

impl _channelend_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject] {
    cidobj = _channelid_from_xid(data);
    if not cidobj {
        return NULL;
    }
    cls = _get_current_channelend_type(ptr[channelid](cidobj).view(1)[0].end);
    if not cls {
        object_decref(cidobj);
        return NULL;
    }
    obj_ = PyObject_CallOneArg(ptr[PyObject](cls), cidobj);
    object_decref(cidobj);
    return obj_;
}

impl _channelend_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32 {
    cidobj = PyObject_GetAttrString(obj_, ptr[u8]("_id"));
    if not cidobj {
        return -1;
    }
    res = _channelid_shared(tstate, cidobj, data);
    object_decref(cidobj);
    if res < 0 {
        return -1;
    }
    data.view(1)[0].new_object = int(ptr(_channelend_from_xid));
    return 0;
}

impl set_channelend_types(
    mod: ptr[PyObject], send: ptr[PyTypeObject], recv: ptr[PyTypeObject]
) -> i32 {
    state = get_module_state(mod);
    if not state {
        return -1;
    }
    st = state.view(1);

    if st[0].send_channel_type {
        clear_xid_class(st[0].send_channel_type);
        clear_state_slot(state_slot(state, 0));
    }
    if st[0].recv_channel_type {
        clear_xid_class(st[0].recv_channel_type);
        clear_state_slot(state_slot(state, 1));
    }

    st[0].send_channel_type = ptr[PyTypeObject](object_new_ref(ptr[PyObject](send)));
    st[0].recv_channel_type = ptr[PyTypeObject](object_new_ref(ptr[PyObject](recv)));
    if ensure_xid_class(send, ptr(_channelend_shared)) < 0 {
        clear_state_slot(state_slot(state, 0));
        clear_state_slot(state_slot(state, 1));
        return -1;
    }
    if ensure_xid_class(recv, ptr(_channelend_shared)) < 0 {
        clear_xid_class(st[0].send_channel_type);
        clear_state_slot(state_slot(state, 0));
        clear_state_slot(state_slot(state, 1));
        return -1;
    }

    return 0;
}

impl _globals_init -> i32 {
    g = addressof(_globals).view(1);
    PyMutex_Lock(ptr[PyMutex](addressof(_globals)));
    g[0].module_count += 1;
    if g[0].module_count == 1 {
        mutex = PyThread_allocate_lock();
        if not mutex {
            g[0].module_count -= 1;
            PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
            return ERR_CHANNELS_MUTEX_INIT;
        }
        _channels_init(_global_channels(), mutex);
    }
    PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
    return 0;
}

impl _globals_fini {
    g = addressof(_globals).view(1);
    PyMutex_Lock(ptr[PyMutex](addressof(_globals)));
    g[0].module_count -= 1;
    if g[0].module_count == 0 {
        mutex = _channels_fini(_global_channels());
        PyThread_free_lock(mutex);
    }
    PyMutex_Unlock(ptr[PyMutex](addressof(_globals)));
}

impl clear_interpreter(data: ptr) {
    if addressof(_globals).view(1)[0].module_count == 0 {
        return;
    }
    interp = ptr[u8](data);
    interpid = PyInterpreterState_GetID(interp);
    _channels_clear_interpreter(_global_channels(), interpid);
}

impl channelsmod_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    unboundarg = i32(-1);
    fallbackarg = i32(-1);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("|ii:create"),
        ptr(addressof(create_kwlist)),
        &mut unboundarg,
        &mut fallbackarg
    )
        == 0 {
        return NULL;
    }
    (ustatus, unboundop) = resolve_unboundop(unboundarg, UNBOUND_REPLACE);
    if ustatus < 0 {
        return NULL;
    }
    (fstatus, fallback) = resolve_fallback(fallbackarg, XIDATA_FULL_FALLBACK);
    if fstatus < 0 {
        return NULL;
    }

    cid = channel_create(_global_channels(), unboundop, fallback);
    if cid < 0 {
        handle_channel_error(-1, self_, cid);
        return NULL;
    }
    state = get_module_state(self_);
    if not state {
        return NULL;
    }
    (err, cidobj) = newchannelid(
        state.view(1)[0].ChannelIDType, cid, 0, _global_channels(), 0, 0
    );
    if handle_channel_error(err, self_, cid) != 0 {
        err2 = channel_destroy(_global_channels(), cid);
        handle_channel_error(err2, self_, cid);
        return NULL;
    }
    return cidobj;
}

impl channelsmod_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:channel_destroy"),
        ptr(addressof(cid_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data)
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    err = channel_destroy(_global_channels(), cid);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl channelsmod_list_all(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    (cids, count) = _channels_list_all(_global_channels());
    if not cids {
        if count == 0 {
            return PyList_New(0);
        }
        return NULL;
    }
    ids = PyList_New(count);
    if not ids {
        PyMem_Free(ptr(cids));
        return ids;
    }
    state = get_module_state(self_);
    if not state {
        object_decref(ids);
        PyMem_Free(ptr(cids));
        return NULL;
    }
    items = ptr[PyListObject](ids).view(1)[0].ob_item;
    i: i64 = 0;
    while i < count {
        cur = (cids + i).view(1);
        (err, cidobj) = newchannelid(
            state.view(1)[0].ChannelIDType, cur[0].id, 0, _global_channels(), 0, 0
        );
        if handle_channel_error(err, self_, cur[0].id) != 0 {
            old = ids;
            ids = NULL;
            object_decref(old);
            break;
        }

        item = Py_BuildValue(
            ptr[u8]("Oii"), cidobj, cur[0].defaults_unboundop, cur[0].defaults_fallback
        );
        object_decref(cidobj);
        if not item {
            old = ids;
            ids = NULL;
            object_decref(old);
            break;
        }
        (items + i).view(1)[0] = item;
        i += 1;
    }

    PyMem_Free(ptr(cids));
    return ids;
}

impl channelsmod_list_interpreters(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    send = i32(0);

    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&$p:channel_list_interpreters"),
        ptr(addressof(list_interpreters_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data),
        &mut send
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    ids = PyList_New(0);
    if not ids {
        return NULL;
    }

    interp = PyInterpreterState_Head();
    while interp {
        interpid = PyInterpreterState_GetID(interp);
        res = channel_is_associated(_global_channels(), cid, interpid, send);
        if res < 0 {
            handle_channel_error(res, self_, cid);
            object_decref(ids);
            return NULL;
        }
        if res != 0 {
            interpid_obj = _PyInterpreterState_GetIDObject(interp);
            if not interpid_obj {
                object_decref(ids);
                return NULL;
            }
            res = PyList_Insert(ids, 0, interpid_obj);
            object_decref(interpid_obj);
            if res < 0 {
                object_decref(ids);
                return NULL;
            }
        }
        interp = PyInterpreterState_Next(interp);
    }

    return ids;
}

impl channelsmod_send_common(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject], as_buffer: bool
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    cid_data = converter_data(base, self_);
    timeout_p = ptr[i64](base + 32);
    obj_ = NULL;
    unboundarg = i32(-1);
    fallbackarg = i32(-1);
    blocking = i32(1);
    if as_buffer {
        blocking = -1;
    }
    timeout_obj = NULL;
    parsed: i32 = 0;
    if as_buffer {
        parsed = PyArg_ParseTupleAndKeywords(
            args,
            kwds,
            ptr[u8]("O&O|ii$pO:channel_send_buffer"),
            ptr(addressof(send_kwlist)),
            ptr(channel_id_converter),
            ptr(cid_data),
            &mut obj_,
            &mut unboundarg,
            &mut fallbackarg,
            &mut blocking,
            &mut timeout_obj
        );
    } else {
        parsed = PyArg_ParseTupleAndKeywords(
            args,
            kwds,
            ptr[u8]("O&O|ii$pO:channel_send"),
            ptr(addressof(send_kwlist)),
            ptr(channel_id_converter),
            ptr(cid_data),
            &mut obj_,
            &mut unboundarg,
            &mut fallbackarg,
            &mut blocking,
            &mut timeout_obj
        );
    }
    if parsed == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;
    if PyThread_ParseTimeoutArg(timeout_obj, blocking, timeout_p) < 0 {
        return NULL;
    }
    timeout = timeout_p.view(1)[0];
    dflt_unboundop = i32(-1);
    dflt_fallback = i32(-1);
    if unboundarg < 0 or fallbackarg < 0 {
        (err, dunbound, dfallback) = channel_get_defaults(_global_channels(), cid);
        if handle_channel_error(err, self_, cid) != 0 {
            return NULL;
        }
        dflt_unboundop = dunbound;
        dflt_fallback = dfallback;
    }
    (ustatus, unboundop) = resolve_unboundop(unboundarg, dflt_unboundop);
    if ustatus < 0 {
        return NULL;
    }
    (fstatus, fallback) = resolve_fallback(fallbackarg, dflt_fallback);
    if fstatus < 0 {
        return NULL;
    }

    sendobj = obj_;
    if as_buffer {
        sendobj = PyMemoryView_FromObject(obj_);
        if not sendobj {
            return NULL;
        }
    }

    serr: i32 = 0;
    if blocking != 0 {
        serr = channel_send_wait(
            _global_channels(), cid, sendobj, unboundop, timeout, fallback
        );
    } else {
        serr = channel_send(
            _global_channels(), cid, sendobj, ptr[_waiting_t](), unboundop, fallback
        );
    }
    if as_buffer {
        object_decref(sendobj);
    }
    if handle_channel_error(serr, self_, cid) != 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl channelsmod_send(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return channelsmod_send_common(self_, args, kwds, False);
}

impl channelsmod_send_buffer(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    return channelsmod_send_common(self_, args, kwds, True);
}

impl channelsmod_recv(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    dflt = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&|O:channel_recv"),
        ptr(addressof(recv_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data),
        &mut dflt
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    (err, obj_, unboundop) = channel_recv(_global_channels(), cid);
    if err == ERR_CHANNEL_EMPTY and dflt {
        obj_ = object_new_ref(dflt);
        err = 0;
    } elif handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    } elif not obj_ {
        return Py_BuildValue(ptr[u8]("Oi"), Py_None, unboundop);
    }

    res = Py_BuildValue(ptr[u8]("OO"), obj_, Py_None);
    object_decref(obj_);
    return res;
}

impl channelsmod_close(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    send = i32(0);
    recv = i32(0);
    force = i32(0);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&|$ppp:channel_close"),
        ptr(addressof(close_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data),
        &mut send,
        &mut recv,
        &mut force
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    err = channel_close(_global_channels(), cid, send - recv, force);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl channelsmod_release(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    send = i32(0);
    recv = i32(0);
    force = i32(0);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&|$ppp:channel_release"),
        ptr(addressof(close_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data),
        &mut send,
        &mut recv,
        &mut force
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;
    if send == 0 and recv == 0 {
        send = 1;
        recv = 1;
    }

    err = channel_release(_global_channels(), cid, send, recv);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl channelsmod_get_count(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get_count"),
        ptr(addressof(cid_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data)
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    (err, count) = _channel_get_count(_global_channels(), cid);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(count);
}

impl channelsmod_get_info(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:_get_info"),
        ptr(addressof(cid_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data)
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    info_slots: own ChannelsStack = ChannelsStack();
    info = ptr[channel_info](jacpy_stack_address(&mut info_slots));
    err = _channel_get_info(_global_channels(), cid, info);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }
    return new_channel_info(self_, info);
}

impl channelsmod_get_channel_defaults(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own ChannelsStack = ChannelsStack();
    cid_data = converter_data(ptr[u8](jacpy_stack_address(&mut slots)), self_);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O&:get_channel_defaults"),
        ptr(addressof(cid_kwlist)),
        ptr(channel_id_converter),
        ptr(cid_data)
    )
        == 0 {
        return NULL;
    }
    cid = cid_data.view(1)[0].cid;

    (err, unboundop, fallback) = channel_get_defaults(_global_channels(), cid);
    if handle_channel_error(err, self_, cid) != 0 {
        return NULL;
    }

    return Py_BuildValue(ptr[u8]("ii"), unboundop, fallback);
}

impl channelsmod__channel_id(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    state = get_module_state(self_);
    if not state {
        return NULL;
    }
    cls = state.view(1)[0].ChannelIDType;

    mod = get_module_from_owned_type(cls);
    object_decref(mod);

    return _channelid_new(self_, cls, args, kwds);
}

impl channelsmod__register_end_types(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    send = NULL;
    recv = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OO:_register_end_types"),
        ptr(addressof(register_end_types_kwlist)),
        &mut send,
        &mut recv
    )
        == 0 {
        return NULL;
    }
    if not type_check(send) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("expected a type for 'send'"));
        return NULL;
    }
    if not type_check(recv) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("expected a type for 'recv'"));
        return NULL;
    }

    if set_channelend_types(self_, ptr[PyTypeObject](send), ptr[PyTypeObject](recv))
        < 0 {
        return NULL;
    }

    return object_new_ref(Py_None);
}

impl module_exec(mod: ptr[PyObject]) -> i32 {
    err = _globals_init();
    if handle_channel_error(err, mod, -1) != 0 {
        return -1;
    }

    state = get_module_state(mod);
    if not state {
        _globals_fini();
        return -1;
    }

    if exceptions_init(mod) != 0 {
        clear_xid_types(state);
        _globals_fini();
        return -1;
    }

    st = state.view(1);
    st[0].ChannelInfoType = ptr[PyTypeObject](
        PyStructSequence_NewType(addressof(channel_info_desc))
    );
    if not st[0].ChannelInfoType {
        clear_xid_types(state);
        _globals_fini();
        return -1;
    }
    if PyModule_AddType(mod, ptr[PyObject](st[0].ChannelInfoType)) < 0 {
        clear_xid_types(state);
        _globals_fini();
        return -1;
    }

    st[0].ChannelIDType = add_channelid_type(mod);
    if not st[0].ChannelIDType {
        clear_xid_types(state);
        _globals_fini();
        return -1;
    }

    interp = _get_current_interp();
    PyUnstable_AtExit(interp, ptr(clear_interpreter), ptr(interp));

    return 0;
}

impl module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return traverse_module_state(get_module_state(mod), visitor, arg);
}

impl module_clear(mod: ptr[PyObject]) -> i32 {
    return clear_module_state(get_module_state(mod));
}

impl module_free(mod: ptr) {
    clear_module_state(get_module_state(ptr[PyObject](mod)));

    _globals_fini();
}
