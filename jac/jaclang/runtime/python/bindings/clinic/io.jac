glob:priv _io_open_signature = CallSignature(
         "open",
         [
             "file",
             "mode",
             "buffering",
             "encoding",
             "errors",
             "newline",
             "closefd",
             "opener"
         ],
         1,
         8,
         0,
         parser=PARSE_KEYWORDS
     );

def:priv _io_open_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_open_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_text_encoding_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_text_encoding_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob:priv _io_open_code_signature = CallSignature(
         "open_code", ["path"], 1, 1, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_open_code_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_open_code_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__IOBase_seek_signature = CallSignature(
         "seek", ["offset", "whence"], 1, 2, 2, parser=PARSE_KEYWORDS
     );

def:priv _io__IOBase_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_seek_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__IOBase_truncate_signature = CallSignature(
         "truncate", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__IOBase_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__IOBase_fileno_signature = CallSignature(
         "fileno", [], 0, 0, 0, parser=PARSE_NO_ARGUMENTS
     );

def:priv _io__IOBase_fileno_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_fileno_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_fileno_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__IOBase_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__IOBase_readlines_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__IOBase_readlines_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__IOBase_writelines_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__RawIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__RawIOBase_read_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__RawIOBase_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__RawIOBase_readall_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO_close_signature = CallSignature(
         "close", [], 0, 0, 0, parser=PARSE_NO_ARGUMENTS
     );

def:priv _io_FileIO_close_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_close_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_close_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO___init___signature = CallSignature(
         "FileIO", ["file", "mode", "closefd", "opener"], 1, 4, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_FileIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_FileIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv _io_FileIO_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO_readinto_signature = CallSignature(
         "readinto", ["buffer"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io_FileIO_readinto_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_readinto_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_readall_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO_read_signature = CallSignature(
         "read", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io_FileIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO_write_signature = CallSignature(
         "write", ["b"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io_FileIO_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_FileIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_FileIO_truncate_signature = CallSignature(
         "truncate", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io_FileIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_FileIO_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_FileIO_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_BytesIO_getbuffer_signature = CallSignature(
         "getbuffer", [], 0, 0, 0, parser=PARSE_NO_ARGUMENTS
     );

def:priv _io_BytesIO_getbuffer_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_getbuffer_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_getbuffer_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_getvalue_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_read1_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readlines_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readlines_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readlines_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_BytesIO_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_writelines_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_BytesIO_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_BytesIO___init___signature = CallSignature(
         "BytesIO", ["initial_bytes"], 0, 1, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_BytesIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_BytesIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv _io__BufferedIOBase_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_readinto1_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__BufferedIOBase_detach_signature = CallSignature(
         "detach", [], 0, 0, 0, parser=PARSE_NO_ARGUMENTS
     );

def:priv _io__BufferedIOBase_detach_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_detach_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_detach_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__BufferedIOBase_read_signature = CallSignature(
         "read", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__BufferedIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__BufferedIOBase_read1_signature = CallSignature(
         "read1", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__BufferedIOBase_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_read1_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__BufferedIOBase_write_signature = CallSignature(
         "write", ["b"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__BufferedIOBase_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_write_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__BufferedIOBase_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered___sizeof___call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered__dealloc_warn_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_simple_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_closed_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io__Buffered_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_detach_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_name_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io__Buffered_mode_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io__Buffered_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_peek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_peek_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_peek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__Buffered_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__Buffered_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_read1_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_read1_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__Buffered_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_readinto1_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io__Buffered_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__Buffered_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

glob:priv _io__Buffered_truncate_signature = CallSignature(
         "truncate", ["pos"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__Buffered_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__Buffered_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_BufferedReader___init___signature = CallSignature(
         "BufferedReader", ["raw", "buffer_size"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_BufferedReader___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_BufferedReader___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv _io_BufferedWriter___init___signature = CallSignature(
         "BufferedWriter", ["raw", "buffer_size"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_BufferedWriter___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_BufferedWriter___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv _io_BufferedWriter_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_BufferedRWPair___init___signature = CallSignature(
         "BufferedRWPair",
         ["reader", "writer", "buffer_size"],
         2,
         3,
         3,
         parser=PARSE_POSITIONAL
     );

def:priv _io_BufferedRWPair___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_BufferedRWPair___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv _io_BufferedRandom___init___signature = CallSignature(
         "BufferedRandom", ["raw", "buffer_size"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_BufferedRandom___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_BufferedRandom___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv _io_IncrementalNewlineDecoder___init___signature = CallSignature(
         "IncrementalNewlineDecoder",
         ["decoder", "translate", "errors"],
         2,
         3,
         0,
         parser=PARSE_KEYWORDS
     );

def:priv _io_IncrementalNewlineDecoder___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_IncrementalNewlineDecoder___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv _io_IncrementalNewlineDecoder_decode_signature = CallSignature(
         "decode", ["input", "final"], 1, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_IncrementalNewlineDecoder_decode_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_IncrementalNewlineDecoder_decode_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_IncrementalNewlineDecoder_getstate_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_IncrementalNewlineDecoder_setstate_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_IncrementalNewlineDecoder_reset_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_TextIOWrapper___init___signature = CallSignature(
         "TextIOWrapper",
         ["buffer", "encoding", "errors", "newline", "line_buffering", "write_through"],
         1,
         6,
         0,
         parser=PARSE_KEYWORDS
     );

def:priv _io_TextIOWrapper___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_TextIOWrapper___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

glob:priv _io_TextIOWrapper_reconfigure_signature = CallSignature(
         "reconfigure",
         ["encoding", "errors", "newline", "line_buffering", "write_through"],
         0,
         0,
         0,
         parser=PARSE_KEYWORDS
     );

def:priv _io_TextIOWrapper_reconfigure_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_reconfigure_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_reconfigure_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_detach_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_readline_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_name_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_closed_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_newlines_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper_errors_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper__CHUNK_SIZE_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_TextIOWrapper__CHUNK_SIZE_set(
    receiver: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32;

glob:priv _io__TextIOBase_detach_signature = CallSignature(
         "detach", [], 0, 0, 0, parser=PARSE_NO_ARGUMENTS
     );

def:priv _io__TextIOBase_detach_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__TextIOBase_detach_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__TextIOBase_detach_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__TextIOBase_read_signature = CallSignature(
         "read", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__TextIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__TextIOBase_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__TextIOBase_readline_signature = CallSignature(
         "readline", ["size"], 0, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__TextIOBase_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__TextIOBase_readline_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io__TextIOBase_write_signature = CallSignature(
         "write", ["s"], 1, 1, 1, parser=PARSE_KEYWORDS
     );

def:priv _io__TextIOBase_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io__TextIOBase_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io__TextIOBase_encoding_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io__TextIOBase_newlines_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io__TextIOBase_errors_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_StringIO_getvalue_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_StringIO_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_StringIO_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_StringIO_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_StringIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_StringIO_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_StringIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv _io_StringIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def:priv _io_StringIO_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

glob:priv _io_StringIO___init___signature = CallSignature(
         "StringIO", ["initial_value", "newline"], 0, 2, 0, parser=PARSE_KEYWORDS
     );

def:priv _io_StringIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:pub _io_StringIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32;

def:priv _io_StringIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO___getstate___call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO___setstate___call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv _io_StringIO_closed_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_StringIO_line_buffering_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

def:priv _io_StringIO_newlines_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject];

glob BufferedRWPair_doc: str = "BufferedRWPair(reader, writer, buffer_size=DEFAULT_BUFFER_SIZE, /)\n--\n\nA buffered reader and writer object together.\n\nA buffered reader object and buffered writer object put together to\nform a sequential IO object that can read and write. This is typically\nused with a socket or two-way pipe.\n\nreader and writer are RawIOBase objects that are readable and\nwriteable respectively. If the buffer_size is omitted it defaults to\nDEFAULT_BUFFER_SIZE.",
     BufferedRandom_doc: str = "BufferedRandom(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n--\n\nA buffered interface to random access streams.\n\nThe constructor creates a reader and writer for a seekable stream,\nraw, given in the first argument. If the buffer_size is omitted it\ndefaults to DEFAULT_BUFFER_SIZE.",
     BufferedReader_doc: str = "BufferedReader(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n--\n\nCreate a new buffered reader using the given readable raw IO object.",
     BufferedWriter_doc: str = "BufferedWriter(raw, buffer_size=DEFAULT_BUFFER_SIZE)\n--\n\nA buffer for a writeable sequential RawIO object.\n\nThe constructor creates a BufferedWriter for the given writeable raw\nstream. If the buffer_size is not given, it defaults to\nDEFAULT_BUFFER_SIZE.",
     BytesIO_doc: str = "BytesIO(initial_bytes=b'')\n--\n\nBuffered I/O implementation using an in-memory bytes buffer.",
     FileIO_doc: str = "FileIO(file, mode='r', closefd=True, opener=None)\n--\n\nOpen a file.\n\nThe mode can be 'r' (default), 'w', 'x' or 'a' for reading,\nwriting, exclusive creation or appending.  The file will be created\nif it doesn't exist when opened for writing or appending; it will be\ntruncated when opened for writing.  A FileExistsError will be raised\nif it already exists when opened for creating.  Opening a file for\ncreating implies writing so this mode behaves in a similar way to\n'w'.  Add a '+' to the mode to allow simultaneous reading and\nwriting.\n\nA custom opener can be used by passing a callable as *opener*.\nThe underlying file descriptor for the file object is then obtained\nby calling opener with (*name*, *flags*).  *opener* must return\nan open file descriptor (passing os.open as *opener* results in\nfunctionality similar to passing None).",
     IncrementalNewlineDecoder_doc: str = "IncrementalNewlineDecoder(decoder, translate, errors='strict')\n--\n\nCodec used when reading a file in universal newlines mode.\n\nIt wraps another incremental decoder, translating \\r\\n and \\r into \\n.\nIt also records the types of newlines encountered.  When used with\ntranslate=False, it ensures that the newline sequence is returned in\none piece. When used with decoder=None, it expects unicode strings as\ndecode input and translates newlines without first invoking an external\ndecoder.",
     StringIO_doc: str = "StringIO(initial_value='', newline='\\n')\n--\n\nText I/O implementation using an in-memory buffer.\n\nThe initial_value argument sets the value of object.  The newline\nargument is like the one of TextIOWrapper's constructor.",
     TextIOWrapper_doc: str = "TextIOWrapper(buffer, encoding=None, errors=None, newline=None,\n              line_buffering=False, write_through=False)\n--\n\nCharacter and line based layer over a BufferedIOBase object, buffer.\n\nencoding gives the name of the encoding that the stream will be\ndecoded or encoded with. It defaults to locale.getencoding().\n\nerrors determines the strictness of encoding and decoding (see\nhelp(codecs.Codec) or the documentation for codecs.register) and\ndefaults to \"strict\".\n\nnewline controls how line endings are handled. It can be None, '',\n'\\n', '\\r', and '\\r\\n'.  It works as follows:\n\n* On input, if newline is None, universal newlines mode is\n  enabled. Lines in the input can end in '\\n', '\\r', or '\\r\\n', and\n  these are translated into '\\n' before being returned to the\n  caller. If it is '', universal newline mode is enabled, but line\n  endings are returned to the caller untranslated. If it has any of\n  the other legal values, input lines are only terminated by the given\n  string, and the line ending is returned to the caller untranslated.\n\n* On output, if newline is None, any '\\n' characters written are\n  translated to the system default line separator, os.linesep. If\n  newline is '' or '\\n', no translation takes place. If newline is any\n  of the other legal values, any '\\n' characters written are translated\n  to the given string.\n\nIf line_buffering is True, a call to flush is implied when a call to\nwrite contains a newline character.",
     module_doc: str = "The io module provides the Python interfaces to stream handling. The\nbuiltin open function is defined in this module.\n\nAt the top of the I/O hierarchy is the abstract base class IOBase. It\ndefines the basic interface to a stream. Note, however, that there is no\nseparation between reading and writing to streams; implementations are\nallowed to raise an OSError if they do not support a given operation.\n\nExtending IOBase is RawIOBase which deals simply with the reading and\nwriting of raw bytes to a stream. FileIO subclasses RawIOBase to provide\nan interface to OS files.\n\nBufferedIOBase deals with buffering on a raw byte stream (RawIOBase). Its\nsubclasses, BufferedWriter, BufferedReader, and BufferedRWPair buffer\nstreams that are readable, writable, and both respectively.\nBufferedRandom provides a buffered interface to random access\nstreams. BytesIO is a simple stream of in-memory bytes.\n\nAnother IOBase subclass, TextIOBase, deals with the encoding and decoding\nof streams into text. TextIOWrapper, which extends it, is a buffered text\ninterface to a buffered raw stream (`BufferedIOBase`). Finally, StringIO\nis an in-memory stream for text.\n\nArgument names are not part of the specification, and only the arguments\nof open() are intended to be used as keyword arguments.\n\ndata:\n\nDEFAULT_BUFFER_SIZE\n\n   An int containing the default buffer size used by the module's buffered\n   I/O classes.\n",
     iobase_doc: str = "The abstract base class for all I/O classes.\n\nThis class provides dummy implementations for many methods that\nderived classes can override selectively; the default implementations\nrepresent a file that cannot be read, written or seeked.\n\nEven though IOBase does not declare read, readinto, or write because\ntheir signatures will vary, implementations and clients should\nconsider those methods part of the interface. Also, implementations\nmay raise UnsupportedOperation when operations they do not support are\ncalled.\n\nThe basic type used for binary data read from or written to a file is\nbytes. Other bytes-like objects are accepted as method arguments too.\nIn some cases (such as readinto), a writable object is required. Text\nI/O classes work with str data.\n\nNote that calling any method (except additional calls to close(),\nwhich are ignored) on a closed stream should raise a ValueError.\n\nIOBase (and its subclasses) support the iterator protocol, meaning\nthat an IOBase object can be iterated over yielding the lines in a\nstream.\n\nIOBase also supports the :keyword:`with` statement. In this example,\nfp is closed after the suite of the with statement is complete:\n\nwith open('spam.txt', 'r') as fp:\n    fp.write('Spam and eggs!')\n",
     rawiobase_doc: str = "Base class for raw binary I/O.",
     bufferediobase_doc: str = "Base class for buffered IO objects.\n\nThe main difference with RawIOBase is that the read() method\nsupports omitting the size argument, and does not have a default\nimplementation that defers to readinto().\n\nIn addition, read(), readinto() and write() may raise\nBlockingIOError if the underlying raw stream is in non-blocking\nmode and not ready; unlike their raw counterparts, they will never\nreturn None.\n\nA typical implementation should not inherit from a RawIOBase\nimplementation, but wrap one.\n",
     textiobase_doc: str = "Base class for text I/O.\n\nThis class provides a character and line based interface to stream\nI/O. There is no readinto method because Python's character strings\nare immutable.\n",
     fileio_getsetlist_closed_doc: str = "True if the file is closed",
     fileio_getsetlist_closefd_doc: str = "True if the file descriptor will be closed by close().",
     fileio_getsetlist_mode_doc: str = "String giving the file mode",
     fileio_getsetlist__blksize_doc: str = "Stat st_blksize if available",
     bytesio_getsetlist_closed_doc: str = "True if the file is closed.",
     BufferedWriter_methods: list[MethodDefinition] = [
         MethodDefinition(
             "write",
             MethodCallbacks(positional=_io_BufferedWriter_write_call),
             "write($self, buffer, /)\n--\n\n",
             8
         ),

     ],
     BytesIO_methods: list[MethodDefinition] = [
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io_BytesIO_readable_call),
             "readable($self, /)\n--\n\nReturns True if the IO object can be read.",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io_BytesIO_writable_call),
             "writable($self, /)\n--\n\nReturns True if the IO object can be written.",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io_BytesIO_seekable_call),
             "seekable($self, /)\n--\n\nReturns True if the IO object can be seeked.",
             4
         ),
         MethodDefinition(
             "flush",
             MethodCallbacks(positional=_io_BytesIO_flush_call),
             "flush($self, /)\n--\n\nDoes nothing.",
             4
         ),
         MethodDefinition(
             "getbuffer",
             MethodCallbacks(fast_keywords=_io_BytesIO_getbuffer_call),
             "getbuffer($self, /)\n--\n\nGet a read-write view over the contents of the BytesIO object.",
             130
         ),
         MethodDefinition(
             "getvalue",
             MethodCallbacks(positional=_io_BytesIO_getvalue_call),
             "getvalue($self, /)\n--\n\nRetrieve the entire contents of the BytesIO object.",
             4
         ),
         MethodDefinition(
             "isatty",
             MethodCallbacks(positional=_io_BytesIO_isatty_call),
             "isatty($self, /)\n--\n\nAlways returns False.\n\nBytesIO objects are not connected to a TTY-like device.",
             4
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io_BytesIO_tell_call),
             "tell($self, /)\n--\n\nCurrent file position, an integer.",
             4
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast=_io_BytesIO_read_call),
             "read($self, size=-1, /)\n--\n\nRead at most size bytes, returned as a bytes object.\n\nIf the size argument is negative, read until EOF is reached.\nReturn an empty bytes object at EOF.",
             128
         ),
         MethodDefinition(
             "read1",
             MethodCallbacks(fast=_io_BytesIO_read1_call),
             "read1($self, size=-1, /)\n--\n\nRead at most size bytes, returned as a bytes object.\n\nIf the size argument is negative or omitted, read until EOF is\nreached.  Return an empty bytes object at EOF.",
             128
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast=_io_BytesIO_readline_call),
             "readline($self, size=-1, /)\n--\n\nNext line from the file, as a bytes object.\n\nRetain newline.  A non-negative size argument limits the maximum\nnumber of bytes to return (an incomplete line may be returned then).\nReturn an empty bytes object at EOF.",
             128
         ),
         MethodDefinition(
             "readlines",
             MethodCallbacks(fast=_io_BytesIO_readlines_call),
             "readlines($self, size=None, /)\n--\n\nList of bytes objects, each a line from the file.\n\nCall readline() repeatedly and return a list of the lines so read.\nThe optional size argument, if given, is an approximate bound on the\ntotal number of bytes in the lines returned.",
             128
         ),
         MethodDefinition(
             "readinto",
             MethodCallbacks(positional=_io_BytesIO_readinto_call),
             "readinto($self, buffer, /)\n--\n\nRead bytes into buffer.\n\nReturns number of bytes read (0 for EOF), or None if the object\nis set not to block and has no data to read.",
             8
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast=_io_BytesIO_truncate_call),
             "truncate($self, size=None, /)\n--\n\nTruncate the file to at most size bytes.\n\nSize defaults to the current file position, as returned by tell().\nThe current file position is unchanged.  Returns the new size.",
             128
         ),
         MethodDefinition(
             "seek",
             MethodCallbacks(fast=_io_BytesIO_seek_call),
             "seek($self, pos, whence=0, /)\n--\n\nChange stream position.\n\nSeek to byte offset pos relative to position indicated by whence:\n     0  Start of stream (the default).  pos should be >= 0;\n     1  Current position - pos may be negative;\n     2  End of stream - pos usually negative.\nReturns the new absolute position.",
             128
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(positional=_io_BytesIO_write_call),
             "write($self, b, /)\n--\n\nWrite bytes to file.\n\nReturn the number of bytes written.",
             8
         ),
         MethodDefinition(
             "writelines",
             MethodCallbacks(positional=_io_BytesIO_writelines_call),
             "writelines($self, lines, /)\n--\n\nWrite lines to the file.\n\nNote that newlines are not added.  lines can be any iterable object\nproducing bytes-like objects.  This is equivalent to calling write()\nfor each element.",
             8
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=_io_BytesIO_close_call),
             "close($self, /)\n--\n\nDisable all I/O operations.",
             4
         ),

     ],
     FileIO_methods: list[MethodDefinition] = [
         MethodDefinition(
             "close",
             MethodCallbacks(fast_keywords=_io_FileIO_close_call),
             "close($self, /)\n--\n\nClose the file.\n\nA closed file cannot be used for further I/O operations.  close()\nmay be called more than once without error.",
             130
         ),
         MethodDefinition(
             "fileno",
             MethodCallbacks(positional=_io_FileIO_fileno_call),
             "fileno($self, /)\n--\n\nReturn the underlying file descriptor (an integer).",
             4
         ),
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io_FileIO_readable_call),
             "readable($self, /)\n--\n\nTrue if file was opened in a read mode.",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io_FileIO_writable_call),
             "writable($self, /)\n--\n\nTrue if file was opened in a write mode.",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io_FileIO_seekable_call),
             "seekable($self, /)\n--\n\nTrue if file supports random-access.",
             4
         ),
         MethodDefinition(
             "readinto",
             MethodCallbacks(fast_keywords=_io_FileIO_readinto_call),
             "readinto($self, buffer, /)\n--\n\nSame as RawIOBase.readinto().",
             130
         ),
         MethodDefinition(
             "readall",
             MethodCallbacks(positional=_io_FileIO_readall_call),
             "readall($self, /)\n--\n\nRead all data from the file, returned as bytes.\n\nReads until either there is an error or read() returns size 0\n(indicates EOF).  If the file is already at EOF, returns an empty\nbytes object.\n\nIn non-blocking mode, returns as much data as could be read before\nEAGAIN.  If no data is available (EAGAIN is returned before bytes\nare read) returns None.",
             4
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast_keywords=_io_FileIO_read_call),
             "read($self, size=-1, /)\n--\n\nRead at most size bytes, returned as bytes.\n\nIf size is less than 0, read all bytes in the file making multiple\nread calls.  See ``FileIO.readall``.\n\nAttempts to make only one system call, retrying only per PEP 475\n(EINTR).  This means less data may be returned than requested.\n\nIn non-blocking mode, returns None if no data is available.  Return\nan empty bytes object at EOF.",
             130
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(fast_keywords=_io_FileIO_write_call),
             "write($self, b, /)\n--\n\nWrite buffer b to file, return number of bytes written.\n\nOnly makes one system call, so not all of the data may be written.\nThe number of bytes actually written is returned.  In non-blocking\nmode, returns None if the write would block.",
             130
         ),
         MethodDefinition(
             "seek",
             MethodCallbacks(fast=_io_FileIO_seek_call),
             "seek($self, pos, whence=0, /)\n--\n\nMove to new file position and return the file position.\n\nArgument offset is a byte count.  Optional argument whence defaults\nto SEEK_SET or 0 (offset from start of file, offset should be >= 0);\nother values are SEEK_CUR or 1 (move relative to current position,\npositive or negative), and SEEK_END or 2 (move relative to end of\nfile, usually negative, although many platforms allow seeking beyond\nthe end of a file).\n\nNote that not all file objects are seekable.",
             128
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io_FileIO_tell_call),
             "tell($self, /)\n--\n\nCurrent file position.\n\nCan raise OSError for non seekable files.",
             4
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast_keywords=_io_FileIO_truncate_call),
             "truncate($self, size=None, /)\n--\n\nTruncate the file to at most size bytes and return the truncated size.\n\nSize defaults to the current file position, as returned by tell().\nThe current file position is changed to the value of size.",
             130
         ),
         MethodDefinition(
             "isatty",
             MethodCallbacks(positional=_io_FileIO_isatty_call),
             "isatty($self, /)\n--\n\nTrue if the file is connected to a TTY device.",
             4
         ),

     ],
     IncrementalNewlineDecoder_methods: list[MethodDefinition] = [
         MethodDefinition(
             "decode",
             MethodCallbacks(fast_keywords=_io_IncrementalNewlineDecoder_decode_call),
             "decode($self, /, input, final=False)\n--\n\n",
             130
         ),
         MethodDefinition(
             "getstate",
             MethodCallbacks(positional=_io_IncrementalNewlineDecoder_getstate_call),
             "getstate($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "setstate",
             MethodCallbacks(positional=_io_IncrementalNewlineDecoder_setstate_call),
             "setstate($self, state, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "reset",
             MethodCallbacks(positional=_io_IncrementalNewlineDecoder_reset_call),
             "reset($self, /)\n--\n\n",
             4
         ),

     ],
     StringIO_methods: list[MethodDefinition] = [
         MethodDefinition(
             "getvalue",
             MethodCallbacks(positional=_io_StringIO_getvalue_call),
             "getvalue($self, /)\n--\n\nRetrieve the entire contents of the object.",
             4
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io_StringIO_tell_call),
             "tell($self, /)\n--\n\nTell the current file position.",
             4
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast=_io_StringIO_read_call),
             "read($self, size=-1, /)\n--\n\nRead at most size characters, returned as a string.\n\nIf the argument is negative or omitted, read until EOF\nis reached. Return an empty string at EOF.",
             128
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast=_io_StringIO_readline_call),
             "readline($self, size=-1, /)\n--\n\nRead until newline or EOF.\n\nReturns an empty string if EOF is hit immediately.",
             128
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast=_io_StringIO_truncate_call),
             "truncate($self, pos=None, /)\n--\n\nTruncate size to pos.\n\nThe pos argument defaults to the current file position, as\nreturned by tell().  The current file position is unchanged.\nReturns the new absolute position.",
             128
         ),
         MethodDefinition(
             "seek",
             MethodCallbacks(fast=_io_StringIO_seek_call),
             "seek($self, pos, whence=0, /)\n--\n\nChange stream position.\n\nSeek to character offset pos relative to position indicated by\nwhence:\n    0  Start of stream (the default).  pos should be >= 0;\n    1  Current position - pos must be 0;\n    2  End of stream - pos must be 0.\nReturns the new absolute position.",
             128
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(positional=_io_StringIO_write_call),
             "write($self, s, /)\n--\n\nWrite string to file.\n\nReturns the number of characters written, which is always equal to\nthe length of the string.",
             8
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=_io_StringIO_close_call),
             "close($self, /)\n--\n\nClose the IO object.\n\nAttempting any further operation after the object is closed\nwill raise a ValueError.\n\nThis method has no effect if the file is already closed.",
             4
         ),
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io_StringIO_readable_call),
             "readable($self, /)\n--\n\nReturns True if the IO object can be read.",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io_StringIO_writable_call),
             "writable($self, /)\n--\n\nReturns True if the IO object can be written.",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io_StringIO_seekable_call),
             "seekable($self, /)\n--\n\nReturns True if the IO object can be seeked.",
             4
         ),
         MethodDefinition(
             "__getstate__",
             MethodCallbacks(positional=_io_StringIO___getstate___call),
             "__getstate__($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "__setstate__",
             MethodCallbacks(positional=_io_StringIO___setstate___call),
             "__setstate__($self, state, /)\n--\n\n",
             8
         ),

     ],
     TextIOWrapper_methods: list[MethodDefinition] = [
         MethodDefinition(
             "reconfigure",
             MethodCallbacks(fast_keywords=_io_TextIOWrapper_reconfigure_call),
             "reconfigure($self, /, *, encoding=None, errors=None, newline=None,\n            line_buffering=None, write_through=None)\n--\n\nReconfigure the text stream with new parameters.\n\nThis also does an implicit stream flush.",
             130
         ),
         MethodDefinition(
             "detach",
             MethodCallbacks(positional=_io_TextIOWrapper_detach_call),
             "detach($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(positional=_io_TextIOWrapper_write_call),
             "write($self, text, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast=_io_TextIOWrapper_read_call),
             "read($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast=_io_TextIOWrapper_readline_call),
             "readline($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "seek",
             MethodCallbacks(fast=_io_TextIOWrapper_seek_call),
             "seek($self, cookie, whence=os.SEEK_SET, /)\n--\n\nSet the stream position, and return the new stream position.\n\n  cookie\n    Zero or an opaque number returned by tell().\n  whence\n    The relative position to seek from.\n\nFour operations are supported, given by the following argument\ncombinations:\n\n- seek(0, SEEK_SET): Rewind to the start of the stream.\n- seek(cookie, SEEK_SET): Restore a previous position;\n  'cookie' must be a number returned by tell().\n- seek(0, SEEK_END): Fast-forward to the end of the stream.\n- seek(0, SEEK_CUR): Leave the current stream position unchanged.\n\nAny other argument combinations are invalid,\nand may raise exceptions.",
             128
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io_TextIOWrapper_tell_call),
             "tell($self, /)\n--\n\nReturn the stream position as an opaque number.\n\nThe return value of tell() can be given as input to seek(), to\nrestore a previous stream position.",
             4
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast=_io_TextIOWrapper_truncate_call),
             "truncate($self, pos=None, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "fileno",
             MethodCallbacks(positional=_io_TextIOWrapper_fileno_call),
             "fileno($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io_TextIOWrapper_seekable_call),
             "seekable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io_TextIOWrapper_readable_call),
             "readable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io_TextIOWrapper_writable_call),
             "writable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "isatty",
             MethodCallbacks(positional=_io_TextIOWrapper_isatty_call),
             "isatty($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "flush",
             MethodCallbacks(positional=_io_TextIOWrapper_flush_call),
             "flush($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=_io_TextIOWrapper_close_call),
             "close($self, /)\n--\n\n",
             4
         ),

     ],
     _BufferedIOBase_methods: list[MethodDefinition] = [
         MethodDefinition(
             "readinto",
             MethodCallbacks(positional=_io__BufferedIOBase_readinto_call),
             "readinto($self, buffer, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "readinto1",
             MethodCallbacks(positional=_io__BufferedIOBase_readinto1_call),
             "readinto1($self, buffer, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "detach",
             MethodCallbacks(fast_keywords=_io__BufferedIOBase_detach_call),
             "detach($self, /)\n--\n\nDisconnect this buffer from its underlying raw stream and return it.\n\nAfter the raw stream has been detached, the buffer is in an unusable\nstate.",
             130
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast_keywords=_io__BufferedIOBase_read_call),
             "read($self, size=-1, /)\n--\n\nRead and return up to n bytes.\n\nIf the size argument is omitted, None, or negative, read and\nreturn all data until EOF.\n\nIf the size argument is positive, and the underlying raw stream is\nnot 'interactive', multiple raw reads may be issued to satisfy\nthe byte count (unless EOF is reached first).\nHowever, for interactive raw streams (as well as sockets and pipes),\nat most one raw read will be issued, and a short result does not\nimply that EOF is imminent.\n\nReturn an empty bytes object on EOF.\n\nReturn None if the underlying raw stream was open in non-blocking\nmode and no data is available at the moment.",
             130
         ),
         MethodDefinition(
             "read1",
             MethodCallbacks(fast_keywords=_io__BufferedIOBase_read1_call),
             "read1($self, size=-1, /)\n--\n\nRead and return up to size bytes, with at most one read() call to the underlying raw stream.\n\nReturn an empty bytes object on EOF.\nA short result does not imply that EOF is imminent.",
             130
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(fast_keywords=_io__BufferedIOBase_write_call),
             "write($self, b, /)\n--\n\nWrite buffer b to the IO stream.\n\nReturn the number of bytes written, which is always\nthe length of b in bytes.\n\nRaise BlockingIOError if the buffer is full and the\nunderlying raw stream cannot accept more data at the moment.",
             130
         ),

     ],
     _Buffered_methods: list[MethodDefinition] = [
         MethodDefinition(
             "__sizeof__",
             MethodCallbacks(positional=_io__Buffered___sizeof___call),
             "__sizeof__($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "_dealloc_warn",
             MethodCallbacks(positional=_io__Buffered__dealloc_warn_call),
             "_dealloc_warn($self, source, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "flush",
             MethodCallbacks(positional=_io__Buffered_simple_flush_call),
             "flush($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=_io__Buffered_close_call),
             "close($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "detach",
             MethodCallbacks(positional=_io__Buffered_detach_call),
             "detach($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io__Buffered_seekable_call),
             "seekable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io__Buffered_readable_call),
             "readable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io__Buffered_writable_call),
             "writable($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "fileno",
             MethodCallbacks(positional=_io__Buffered_fileno_call),
             "fileno($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "isatty",
             MethodCallbacks(positional=_io__Buffered_isatty_call),
             "isatty($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "flush",
             MethodCallbacks(positional=_io__Buffered_flush_call),
             "flush($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "peek",
             MethodCallbacks(fast=_io__Buffered_peek_call),
             "peek($self, size=0, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast=_io__Buffered_read_call),
             "read($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "read1",
             MethodCallbacks(fast=_io__Buffered_read1_call),
             "read1($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "readinto",
             MethodCallbacks(positional=_io__Buffered_readinto_call),
             "readinto($self, buffer, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "readinto1",
             MethodCallbacks(positional=_io__Buffered_readinto1_call),
             "readinto1($self, buffer, /)\n--\n\n",
             8
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast=_io__Buffered_readline_call),
             "readline($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io__Buffered_tell_call),
             "tell($self, /)\n--\n\n",
             4
         ),
         MethodDefinition(
             "seek",
             MethodCallbacks(fast=_io__Buffered_seek_call),
             "seek($self, target, whence=0, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast_keywords=_io__Buffered_truncate_call),
             "truncate($self, pos=None, /)\n--\n\n",
             130
         ),

     ],
     _IOBase_methods: list[MethodDefinition] = [
         MethodDefinition(
             "seek",
             MethodCallbacks(fast_keywords=_io__IOBase_seek_call),
             "seek($self, offset, whence=os.SEEK_SET, /)\n--\n\nChange the stream position to the given byte offset.\n\n  offset\n    The stream position, relative to 'whence'.\n  whence\n    The relative position to seek from.\n\nThe offset is interpreted relative to the position indicated by\nwhence.  Values for whence are:\n\n* os.SEEK_SET or 0 -- start of stream (the default); offset should\n  be zero or positive\n* os.SEEK_CUR or 1 -- current stream position; offset may be\n  negative\n* os.SEEK_END or 2 -- end of stream; offset is usually negative\n\nReturn the new absolute position.",
             130
         ),
         MethodDefinition(
             "tell",
             MethodCallbacks(positional=_io__IOBase_tell_call),
             "tell($self, /)\n--\n\nReturn current stream position.",
             4
         ),
         MethodDefinition(
             "truncate",
             MethodCallbacks(fast_keywords=_io__IOBase_truncate_call),
             "truncate($self, size=None, /)\n--\n\nTruncate file to size bytes.\n\nFile pointer is left unchanged.  Size defaults to the current IO\nposition as reported by tell().  Return the new size.",
             130
         ),
         MethodDefinition(
             "flush",
             MethodCallbacks(positional=_io__IOBase_flush_call),
             "flush($self, /)\n--\n\nFlush write buffers, if applicable.\n\nThis is not implemented for read-only and non-blocking streams.",
             4
         ),
         MethodDefinition(
             "close",
             MethodCallbacks(positional=_io__IOBase_close_call),
             "close($self, /)\n--\n\nFlush and close the IO object.\n\nThis method has no effect if the file is already closed.",
             4
         ),
         MethodDefinition(
             "seekable",
             MethodCallbacks(positional=_io__IOBase_seekable_call),
             "seekable($self, /)\n--\n\nReturn whether object supports random access.\n\nIf False, seek(), tell() and truncate() will raise OSError.\nThis method may need to do a test seek().",
             4
         ),
         MethodDefinition(
             "readable",
             MethodCallbacks(positional=_io__IOBase_readable_call),
             "readable($self, /)\n--\n\nReturn whether object was opened for reading.\n\nIf False, read() will raise OSError.",
             4
         ),
         MethodDefinition(
             "writable",
             MethodCallbacks(positional=_io__IOBase_writable_call),
             "writable($self, /)\n--\n\nReturn whether object was opened for writing.\n\nIf False, write() will raise OSError.",
             4
         ),
         MethodDefinition(
             "fileno",
             MethodCallbacks(fast_keywords=_io__IOBase_fileno_call),
             "fileno($self, /)\n--\n\nReturn underlying file descriptor if one exists.\n\nRaise OSError if the IO object does not use a file descriptor.",
             130
         ),
         MethodDefinition(
             "isatty",
             MethodCallbacks(positional=_io__IOBase_isatty_call),
             "isatty($self, /)\n--\n\nReturn whether this is an 'interactive' stream.\n\nReturn False if it can't be determined.",
             4
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast=_io__IOBase_readline_call),
             "readline($self, size=-1, /)\n--\n\nRead and return a line from the stream.\n\nIf size is specified, at most size bytes will be read.\n\nThe line terminator is always b'\\n' for binary files; for text\nfiles, the newlines argument to open can be used to select the line\nterminator(s) recognized.",
             128
         ),
         MethodDefinition(
             "readlines",
             MethodCallbacks(fast=_io__IOBase_readlines_call),
             "readlines($self, hint=-1, /)\n--\n\nReturn a list of lines from the stream.\n\nhint can be specified to control the number of lines read: no more\nlines will be read if the total size (in bytes/characters) of all\nlines so far exceeds hint.",
             128
         ),
         MethodDefinition(
             "writelines",
             MethodCallbacks(positional=_io__IOBase_writelines_call),
             "writelines($self, lines, /)\n--\n\nWrite a list of lines to stream.\n\nLine separators are not added, so it is usual for each of the\nlines provided to have a line separator at the end.",
             8
         ),

     ],
     _RawIOBase_methods: list[MethodDefinition] = [
         MethodDefinition(
             "read",
             MethodCallbacks(fast=_io__RawIOBase_read_call),
             "read($self, size=-1, /)\n--\n\n",
             128
         ),
         MethodDefinition(
             "readall",
             MethodCallbacks(positional=_io__RawIOBase_readall_call),
             "readall($self, /)\n--\n\nRead until EOF, using multiple read() call.",
             4
         ),

     ],
     _TextIOBase_methods: list[MethodDefinition] = [
         MethodDefinition(
             "detach",
             MethodCallbacks(fast_keywords=_io__TextIOBase_detach_call),
             "detach($self, /)\n--\n\nSeparate the underlying buffer from the TextIOBase and return it.\n\nAfter the underlying buffer has been detached, the TextIO is in\nan unusable state.",
             130
         ),
         MethodDefinition(
             "read",
             MethodCallbacks(fast_keywords=_io__TextIOBase_read_call),
             "read($self, size=-1, /)\n--\n\nRead at most size characters from stream.\n\nRead from underlying buffer until we have size characters or we hit\nEOF.  If size is negative or omitted, read until EOF.",
             130
         ),
         MethodDefinition(
             "readline",
             MethodCallbacks(fast_keywords=_io__TextIOBase_readline_call),
             "readline($self, size=-1, /)\n--\n\nRead until newline or EOF.\n\nReturn an empty string if EOF is hit immediately.\nIf size is specified, at most size characters will be read.",
             130
         ),
         MethodDefinition(
             "write",
             MethodCallbacks(fast_keywords=_io__TextIOBase_write_call),
             "write($self, s, /)\n--\n\nWrite string s to stream.\n\nReturn the number of characters written\n(which is always equal to the length of the string).",
             130
         ),

     ],
     module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "open",
             MethodCallbacks(fast_keywords=_io_open_call),
             "open($module, /, file, mode='r', buffering=-1, encoding=None,\n     errors=None, newline=None, closefd=True, opener=None)\n--\n\nOpen file and return a stream.  Raise OSError upon failure.\n\nfile is either a text or byte string giving the name (and the path\nif the file isn't in the current working directory) of the file to\nbe opened or an integer file descriptor of the file to be\nwrapped.  (If a file descriptor is given, it is closed when the\nreturned I/O object is closed, unless closefd is set to False.)\n\nmode is an optional string that specifies the mode in which the file\nis opened.  It defaults to 'r' which means open for reading in text\nmode.  Other common values are 'w' for writing (truncating the file if\nit already exists), 'x' for creating and writing to a new file, and\n'a' for appending (which on some Unix systems, means that all writes\nappend to the end of the file regardless of the current seek position).\nIn text mode, if encoding is not specified the encoding used is platform\ndependent: locale.getencoding() is called to get the current locale\nencoding.  (For reading and writing raw bytes use binary mode and leave\nencoding unspecified.)  The available modes are:\n\n========= ==========================================================\nCharacter Meaning\n--------- ----------------------------------------------------------\n'r'       open for reading (default)\n'w'       open for writing, truncating the file first\n'x'       create a new file and open it for writing\n'a'       open for writing, appending to the end of the file if it\n          exists\n'b'       binary mode\n't'       text mode (default)\n'+'       open a disk file for updating (reading and writing)\n========= ==========================================================\n\nThe default mode is 'rt' (open for reading text).  For binary random\naccess, the mode 'w+b' opens and truncates the file to 0 bytes, while\n'r+b' opens the file without truncation.  The 'x' mode implies 'w' and\nraises an `FileExistsError` if the file already exists.\n\nPython distinguishes between files opened in binary and text modes,\neven when the underlying operating system doesn't.  Files opened in\nbinary mode (appending 'b' to the mode argument) return contents as\nbytes objects without any decoding.  In text mode (the default, or when\n't' is appended to the mode argument), the contents of the file are\nreturned as strings, the bytes having been first decoded using a\nplatform-dependent encoding or using the specified encoding if given.\n\nbuffering is an optional integer used to set the buffering policy.\nPass 0 to switch buffering off (only allowed in binary mode), 1 to\nselect line buffering (only usable in text mode), and an integer > 1 to\nindicate the size of a fixed-size chunk buffer.   When no buffering\nargument is given, the default buffering policy works as follows:\n\n* Binary files are buffered in fixed-size chunks; the size of the buffer\n  is max(min(blocksize, 8 MiB), DEFAULT_BUFFER_SIZE) when the device\n  block size is available.\n  On most systems, the buffer will typically be 128 kilobytes long.\n\n* \"Interactive\" text files (files for which isatty() returns True)\n  use line buffering.  Other text files use the policy described above\n  for binary files.\n\nencoding is the name of the encoding used to decode or encode the\nfile.  This should only be used in text mode.  The default encoding is\nplatform dependent, but any encoding supported by Python can be\npassed.  See the codecs module for the list of supported encodings.\n\nerrors is an optional string that specifies how encoding errors are to\nbe handled---this argument should not be used in binary mode.  Pass\n'strict' to raise a ValueError exception if there is an encoding error\n(the default of None has the same effect), or pass 'ignore' to ignore\nerrors.  (Note that ignoring encoding errors can lead to data loss.)\nSee the documentation for codecs.register or run 'help(codecs.Codec)'\nfor a list of the permitted encoding error strings.\n\nnewline controls how universal newlines works (it only applies to text\nmode).  It can be None, '', '\\n', '\\r', and '\\r\\n'.  It works as\nfollows:\n\n* On input, if newline is None, universal newlines mode is enabled.\n  Lines in the input can end in '\\n', '\\r', or '\\r\\n', and these are\n  translated into '\\n' before being returned to the caller.  If it is\n  '', universal newline mode is enabled, but line endings are returned\n  to the caller untranslated.  If it has any of the other legal values,\n  input lines are only terminated by the given string, and the line\n  ending is returned to the caller untranslated.\n\n* On output, if newline is None, any '\\n' characters written are\n  translated to the system default line separator, os.linesep.  If\n  newline is '' or '\\n', no translation takes place.  If newline is any\n  of the other legal values, any '\\n' characters written are translated\n  to the given string.\n\nIf closefd is False, the underlying file descriptor will be kept open\nwhen the file is closed.  This does not work when a file name is given\nand must be True in that case.\n\nA custom opener can be used by passing a callable as *opener*.  The\nunderlying file descriptor for the file object is then obtained by\ncalling *opener* with (*file*, *flags*).  *opener* must return an open\nfile descriptor (passing os.open as *opener* results in functionality\nsimilar to passing None).\n\nopen() returns a file object whose type depends on the mode, and\nthrough which the standard file operations such as reading and writing\nare performed.  When open() is used to open a file in a text mode ('w',\n'r', 'wt', 'rt', etc.), it returns a TextIOWrapper.  When used to open\na file in a binary mode, the returned class varies: in read binary\nmode, it returns a BufferedReader; in write binary and append binary\nmodes, it returns a BufferedWriter, and in read/write mode, it returns\na BufferedRandom.\n\nIt is also possible to use a string or bytearray as a file for both\nreading and writing.  For strings StringIO can be used like a file\nopened in a text mode, and for bytes a BytesIO can be used like a file\nopened in a binary mode.",
             130
         ),
         MethodDefinition(
             "text_encoding",
             MethodCallbacks(fast=_io_text_encoding_call),
             "text_encoding($module, encoding, stacklevel=2, /)\n--\n\nA helper function to choose the text encoding.\n\nWhen encoding is not None, this function returns it.\nOtherwise, this function returns the default text encoding\n(i.e. \"locale\" or \"utf-8\" depends on UTF-8 mode).\n\nThis function emits an EncodingWarning if encoding is None and\nsys.flags.warn_default_encoding is true.\n\nThis can be used in APIs with an encoding=None parameter.\nHowever, please consider using encoding=\"utf-8\" for new APIs.",
             128
         ),
         MethodDefinition(
             "open_code",
             MethodCallbacks(fast_keywords=_io_open_code_call),
             "open_code($module, /, path)\n--\n\nOpens the provided file with the intent to import the contents.\n\nThis may perform extra validation beyond open(), but is otherwise\ninterchangeable with calling open(path, 'rb').",
             130
         ),

     ],
     StringIO_getset: list[PropertyDefinition] = [
         PropertyDefinition(
             "closed", PropertyCallbacks(read=_io_StringIO_closed_get), 0, ""
         ),
         PropertyDefinition(
             "line_buffering",
             PropertyCallbacks(read=_io_StringIO_line_buffering_get),
             0,
             ""
         ),
         PropertyDefinition(
             "newlines", PropertyCallbacks(read=_io_StringIO_newlines_get), 0, ""
         ),

     ],
     TextIOWrapper_getset: list[PropertyDefinition] = [
         PropertyDefinition(
             "_CHUNK_SIZE",
             PropertyCallbacks(
                 read=_io_TextIOWrapper__CHUNK_SIZE_get,
                 write=_io_TextIOWrapper__CHUNK_SIZE_set
             ),
             0,
             ""
         ),
         PropertyDefinition(
             "closed", PropertyCallbacks(read=_io_TextIOWrapper_closed_get), 0, ""
         ),
         PropertyDefinition(
             "errors", PropertyCallbacks(read=_io_TextIOWrapper_errors_get), 0, ""
         ),
         PropertyDefinition(
             "name", PropertyCallbacks(read=_io_TextIOWrapper_name_get), 0, ""
         ),
         PropertyDefinition(
             "newlines", PropertyCallbacks(read=_io_TextIOWrapper_newlines_get), 0, ""
         ),

     ],
     _Buffered_getset: list[PropertyDefinition] = [
         PropertyDefinition(
             "closed", PropertyCallbacks(read=_io__Buffered_closed_get), 0, ""
         ),
         PropertyDefinition(
             "mode", PropertyCallbacks(read=_io__Buffered_mode_get), 0, ""
         ),
         PropertyDefinition(
             "name", PropertyCallbacks(read=_io__Buffered_name_get), 0, ""
         ),

     ],
     _TextIOBase_getset: list[PropertyDefinition] = [
         PropertyDefinition(
             "encoding",
             PropertyCallbacks(read=_io__TextIOBase_encoding_get),
             0,
             "Encoding of the text stream.\n\nSubclasses should override."
         ),
         PropertyDefinition(
             "errors",
             PropertyCallbacks(read=_io__TextIOBase_errors_get),
             0,
             "The error setting of the decoder or encoder.\n\nSubclasses should override."
         ),
         PropertyDefinition(
             "newlines",
             PropertyCallbacks(read=_io__TextIOBase_newlines_get),
             0,
             "Line endings translated so far.\n\nOnly line endings translated during reading are considered.\n\nSubclasses should override."
         ),

     ];

impl _io_open_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        file: ptr[PyObject] = value;
        mode: str = "r";
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            mode = convert_str(value, "open", argument_label("mode", 2));
        }
        buffering: i32 = -1;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            buffering = convert_int(value);
        }
        encoding: ptr[u8] = ptr[u8]();
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            encoding = convert_cstr(value, "open", argument_label("encoding", 4), True);
        }
        errors: ptr[u8] = ptr[u8]();
        if count > 4 and clinic_args[4] != NULL {
            value = clinic_args[4];
            errors = convert_cstr(value, "open", argument_label("errors", 5), True);
        }
        newline: ptr[u8] = ptr[u8]();
        if count > 5 and clinic_args[5] != NULL {
            value = clinic_args[5];
            newline = convert_cstr(value, "open", argument_label("newline", 6), True);
        }
        closefd: bool = True;
        if count > 6 and clinic_args[6] != NULL {
            value = clinic_args[6];
            closefd = convert_bool(value);
        }
        opener: ptr[PyObject] = borrowed_none();
        if count > 7 and clinic_args[7] != NULL {
            value = clinic_args[7];
            opener = value;
        }
        return _io_open_impl(
            receiver, file, mode, buffering, encoding, errors, newline, closefd, opener
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_open_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 8 {
        return _io_open_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io_open_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_open_bound(receiver, values, 8);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_open_signature, args, nargs, kwnames, _io_open_bound, receiver
    );
}

impl _io_text_encoding_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        encoding: ptr[PyObject] = value;
        stacklevel: i32 = 2;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            stacklevel = convert_int(value);
        }
        return _io_text_encoding_impl(receiver, encoding, stacklevel);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_text_encoding_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2)
        and not check_positional("text_encoding", int(nargs), 1, 2) {
        return NULL;
    }
    return _io_text_encoding_bound(receiver, args, nargs);
}

impl _io_open_code_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        path: ptr[PyObject] = convert_unicode(
            value, "open_code", argument_label("path", 1)
        );
        return _io_open_code_impl(receiver, path);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_open_code_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _io_open_code_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io_open_code_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_open_code_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_open_code_signature, args, nargs, kwnames, _io_open_code_bound, receiver
    );
}

impl _io__IOBase_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _IOBase_token);
        value = clinic_args[0];
        offset: i32 = convert_int(value);
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io__IOBase_seek_impl(receiver, cls, offset, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__IOBase_seek_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 2 {
        return _io__IOBase_seek_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__IOBase_seek_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__IOBase_seek_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__IOBase_seek_signature,
        args,
        nargs,
        kwnames,
        _io__IOBase_seek_bound,
        receiver
    );
}

impl _io__IOBase_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_tell_impl(receiver);
}

impl _io__IOBase_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _IOBase_token);
        size: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = value;
        }
        return _io__IOBase_truncate_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__IOBase_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    cls = defining_class_or_null(receiver, _IOBase_token);
    if cls == NULL {
        return NULL;
    }
    size: ptr[PyObject] = borrowed_none();
    if count > 0 {
        size = clinic_args[0];
    }
    return _io__IOBase_truncate_impl(receiver, cls, size);
}

impl _io__IOBase_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__IOBase_truncate_direct(receiver, args, nargs);
    }
    values = unpack_stack(_io__IOBase_truncate_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__IOBase_truncate_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__IOBase_truncate_signature,
        args,
        nargs,
        kwnames,
        _io__IOBase_truncate_bound,
        receiver
    );
}

impl _io__IOBase_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_flush_impl(receiver);
}

impl _io__IOBase_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_close_impl(receiver);
}

impl _io__IOBase_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_seekable_impl(receiver);
}

impl _io__IOBase_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_readable_impl(receiver);
}

impl _io__IOBase_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_writable_impl(receiver);
}

impl _io__IOBase_fileno_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        cls = defining_class(receiver, _IOBase_token);
        return _io__IOBase_fileno_impl(receiver, cls);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__IOBase_fileno_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    cls = defining_class_or_null(receiver, _IOBase_token);
    if cls == NULL {
        return NULL;
    }
    return _io__IOBase_fileno_impl(receiver, cls);
}

impl _io__IOBase_fileno_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs == 0 {
        return _io__IOBase_fileno_direct(receiver, args, nargs);
    }
    return invoke_stack(
        _io__IOBase_fileno_signature,
        args,
        nargs,
        kwnames,
        _io__IOBase_fileno_bound,
        receiver
    );
}

impl _io__IOBase_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__IOBase_isatty_impl(receiver);
}

impl _io__IOBase_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io__IOBase_readline_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__IOBase_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readline", int(nargs), 0, 1) {
        return NULL;
    }
    return _io__IOBase_readline_bound(receiver, args, nargs);
}

impl _io__IOBase_readlines_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        hint: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            hint = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io__IOBase_readlines_impl(receiver, hint);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__IOBase_readlines_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readlines", int(nargs), 0, 1) {
        return NULL;
    }
    return _io__IOBase_readlines_bound(receiver, args, nargs);
}

impl _io__IOBase_writelines_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    lines: ptr[PyObject] = value;
    return _io__IOBase_writelines_impl(receiver, lines);
}

impl _io__RawIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_ssize(value);
        }
        return _io__RawIOBase_read_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__RawIOBase_read_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: i64 = -1;
    if count > 0 {
        size = PyLong_AsSsize_t(clinic_args[0]);
        if size == -1 and failed() {
            return NULL;
        }
    }
    return _io__RawIOBase_read_impl(receiver, size);
}

impl _io__RawIOBase_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read", int(nargs), 0, 1) {
        return NULL;
    }
    if exact_int_at(args, nargs, 0) {
        return _io__RawIOBase_read_direct(receiver, args, nargs);
    }
    return _io__RawIOBase_read_bound(receiver, args, nargs);
}

impl _io__RawIOBase_readall_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__RawIOBase_readall_impl(receiver);
}

impl _io_FileIO_close_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        cls = defining_class(receiver, FileIO_token);
        return _io_FileIO_close_impl(receiver, cls);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_close_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    cls = defining_class_or_null(receiver, FileIO_token);
    if cls == NULL {
        return NULL;
    }
    return _io_FileIO_close_impl(receiver, cls);
}

impl _io_FileIO_close_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs == 0 {
        return _io_FileIO_close_direct(receiver, args, nargs);
    }
    return invoke_stack(
        _io_FileIO_close_signature,
        args,
        nargs,
        kwnames,
        _io_FileIO_close_bound,
        receiver
    );
}

impl _io_FileIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        file: ptr[PyObject] = value;
        mode: str = "r";
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            mode = convert_str(value, "FileIO", argument_label("mode", 2));
        }
        closefd: bool = True;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            closefd = convert_bool(value);
        }
        opener: ptr[PyObject] = borrowed_none();
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            opener = value;
        }
        return return_int(
            _io_FileIO___init___impl(receiver, file, mode, closefd, opener)
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 1 and size <= 4 {
            bound = True;
            result = _io_FileIO___init___bound(receiver, jacpy_tuple_items(args), size);
        }
    }
    if not bound {
        values = unpack_mapping(_io_FileIO___init___signature, args, kwargs);
        if values {
            unpacked = _io_FileIO___init___bound(receiver, values, 4);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_FileIO___init___signature,
            args,
            kwargs,
            _io_FileIO___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_FileIO_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_fileno_impl(receiver);
}

impl _io_FileIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_readable_impl(receiver);
}

impl _io_FileIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_writable_impl(receiver);
}

impl _io_FileIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_seekable_impl(receiver);
}

impl _io_FileIO_readinto_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, FileIO_token);
        value = clinic_args[0];
        buffer: BufferArgument = convert_writable_buffer(
            value, "readinto", argument_label("", 1)
        );
        try {
            return _io_FileIO_readinto_impl(receiver, cls, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_readinto_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _io_FileIO_readinto_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io_FileIO_readinto_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_FileIO_readinto_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_FileIO_readinto_signature,
        args,
        nargs,
        kwnames,
        _io_FileIO_readinto_bound,
        receiver
    );
}

impl _io_FileIO_readall_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_readall_impl(receiver);
}

impl _io_FileIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, FileIO_token);
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_FileIO_read_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io_FileIO_read_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io_FileIO_read_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_FileIO_read_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_FileIO_read_signature, args, nargs, kwnames, _io_FileIO_read_bound, receiver
    );
}

impl _io_FileIO_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, FileIO_token);
        value = clinic_args[0];
        b: BufferArgument = convert_buffer(value, "write", argument_label("", 1));
        try {
            return _io_FileIO_write_impl(receiver, cls, b);
        } finally {
            b.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _io_FileIO_write_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io_FileIO_write_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_FileIO_write_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_FileIO_write_signature,
        args,
        nargs,
        kwnames,
        _io_FileIO_write_bound,
        receiver
    );
}

impl _io_FileIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        pos: ptr[PyObject] = value;
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io_FileIO_seek_impl(receiver, pos, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("seek", int(nargs), 1, 2) {
        return NULL;
    }
    return _io_FileIO_seek_bound(receiver, args, nargs);
}

impl _io_FileIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_tell_impl(receiver);
}

impl _io_FileIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, FileIO_token);
        size: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = value;
        }
        return _io_FileIO_truncate_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_FileIO_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    cls = defining_class_or_null(receiver, FileIO_token);
    if cls == NULL {
        return NULL;
    }
    size: ptr[PyObject] = borrowed_none();
    if count > 0 {
        size = clinic_args[0];
    }
    return _io_FileIO_truncate_impl(receiver, cls, size);
}

impl _io_FileIO_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io_FileIO_truncate_direct(receiver, args, nargs);
    }
    values = unpack_stack(_io_FileIO_truncate_signature, args, nargs, kwnames);
    if values {
        unpacked = _io_FileIO_truncate_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_FileIO_truncate_signature,
        args,
        nargs,
        kwnames,
        _io_FileIO_truncate_bound,
        receiver
    );
}

impl _io_FileIO_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_FileIO_isatty_impl(receiver);
}

impl _io_BytesIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_readable_impl(receiver);
}

impl _io_BytesIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_writable_impl(receiver);
}

impl _io_BytesIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_seekable_impl(receiver);
}

impl _io_BytesIO_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_flush_impl(receiver);
}

impl _io_BytesIO_getbuffer_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        cls = defining_class(receiver, BytesIO_token);
        return _io_BytesIO_getbuffer_impl(receiver, cls);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_getbuffer_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    cls = defining_class_or_null(receiver, BytesIO_token);
    if cls == NULL {
        return NULL;
    }
    return _io_BytesIO_getbuffer_impl(receiver, cls);
}

impl _io_BytesIO_getbuffer_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs == 0 {
        return _io_BytesIO_getbuffer_direct(receiver, args, nargs);
    }
    return invoke_stack(
        _io_BytesIO_getbuffer_signature,
        args,
        nargs,
        kwnames,
        _io_BytesIO_getbuffer_bound,
        receiver
    );
}

impl _io_BytesIO_getvalue_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_getvalue_impl(receiver);
}

impl _io_BytesIO_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_isatty_impl(receiver);
}

impl _io_BytesIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_tell_impl(receiver);
}

impl _io_BytesIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_BytesIO_read_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_BytesIO_read_bound(receiver, args, nargs);
}

impl _io_BytesIO_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_BytesIO_read1_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_read1_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read1", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_BytesIO_read1_bound(receiver, args, nargs);
}

impl _io_BytesIO_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_BytesIO_readline_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readline", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_BytesIO_readline_bound(receiver, args, nargs);
}

impl _io_BytesIO_readlines_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = value;
        }
        return _io_BytesIO_readlines_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_readlines_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: ptr[PyObject] = borrowed_none();
    if count > 0 {
        size = clinic_args[0];
    }
    return _io_BytesIO_readlines_impl(receiver, size);
}

impl _io_BytesIO_readlines_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readlines", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_BytesIO_readlines_direct(receiver, args, nargs);
}

impl _io_BytesIO_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_writable_buffer(value, "readinto", "argument");
        try {
            return _io_BytesIO_readinto_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = value;
        }
        return _io_BytesIO_truncate_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: ptr[PyObject] = borrowed_none();
    if count > 0 {
        size = clinic_args[0];
    }
    return _io_BytesIO_truncate_impl(receiver, size);
}

impl _io_BytesIO_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("truncate", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_BytesIO_truncate_direct(receiver, args, nargs);
}

impl _io_BytesIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        pos: i64 = convert_ssize(value);
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io_BytesIO_seek_impl(receiver, pos, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("seek", int(nargs), 1, 2) {
        return NULL;
    }
    return _io_BytesIO_seek_bound(receiver, args, nargs);
}

impl _io_BytesIO_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    b: ptr[PyObject] = value;
    return _io_BytesIO_write_impl(receiver, b);
}

impl _io_BytesIO_writelines_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    lines: ptr[PyObject] = value;
    return _io_BytesIO_writelines_impl(receiver, lines);
}

impl _io_BytesIO_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_BytesIO_close_impl(receiver);
}

impl _io_BytesIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        initial_bytes: ptr[PyObject] = NULL;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            initial_bytes = value;
        }
        return return_int(_io_BytesIO___init___impl(receiver, initial_bytes));
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BytesIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 0 and size <= 1 {
            bound = True;
            result = _io_BytesIO___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_BytesIO___init___signature, args, kwargs);
        if values {
            unpacked = _io_BytesIO___init___bound(receiver, values, 1);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_BytesIO___init___signature,
            args,
            kwargs,
            _io_BytesIO___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io__BufferedIOBase_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_writable_buffer(value, "readinto", "argument");
        try {
            return _io__BufferedIOBase_readinto_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_readinto1_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_writable_buffer(
            value, "readinto1", "argument"
        );
        try {
            return _io__BufferedIOBase_readinto1_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_detach_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        cls = defining_class(receiver, _BufferedIOBase_token);
        return _io__BufferedIOBase_detach_impl(receiver, cls);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_detach_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    cls = defining_class_or_null(receiver, _BufferedIOBase_token);
    if cls == NULL {
        return NULL;
    }
    return _io__BufferedIOBase_detach_impl(receiver, cls);
}

impl _io__BufferedIOBase_detach_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs == 0 {
        return _io__BufferedIOBase_detach_direct(receiver, args, nargs);
    }
    return invoke_stack(
        _io__BufferedIOBase_detach_signature,
        args,
        nargs,
        kwnames,
        _io__BufferedIOBase_detach_bound,
        receiver
    );
}

impl _io__BufferedIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _BufferedIOBase_token);
        size: i32 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_int(value);
        }
        return _io__BufferedIOBase_read_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__BufferedIOBase_read_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__BufferedIOBase_read_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__BufferedIOBase_read_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__BufferedIOBase_read_signature,
        args,
        nargs,
        kwnames,
        _io__BufferedIOBase_read_bound,
        receiver
    );
}

impl _io__BufferedIOBase_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _BufferedIOBase_token);
        size: i32 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_int(value);
        }
        return _io__BufferedIOBase_read1_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_read1_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__BufferedIOBase_read1_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__BufferedIOBase_read1_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__BufferedIOBase_read1_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__BufferedIOBase_read1_signature,
        args,
        nargs,
        kwnames,
        _io__BufferedIOBase_read1_bound,
        receiver
    );
}

impl _io__BufferedIOBase_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _BufferedIOBase_token);
        value = clinic_args[0];
        b: ptr[PyObject] = value;
        return _io__BufferedIOBase_write_impl(receiver, cls, b);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__BufferedIOBase_write_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    cls = defining_class_or_null(receiver, _BufferedIOBase_token);
    if cls == NULL {
        return NULL;
    }
    b: ptr[PyObject] = clinic_args[0];
    return _io__BufferedIOBase_write_impl(receiver, cls, b);
}

impl _io__BufferedIOBase_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _io__BufferedIOBase_write_direct(receiver, args, nargs);
    }
    values = unpack_stack(_io__BufferedIOBase_write_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__BufferedIOBase_write_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__BufferedIOBase_write_signature,
        args,
        nargs,
        kwnames,
        _io__BufferedIOBase_write_bound,
        receiver
    );
}

impl _io__Buffered___sizeof___call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered___sizeof___impl(receiver);
}

impl _io__Buffered__dealloc_warn_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    source: ptr[PyObject] = value;
    return _io__Buffered__dealloc_warn_impl(receiver, source);
}

impl _io__Buffered_simple_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_simple_flush_impl(receiver);
}

impl _io__Buffered_closed_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return _io__Buffered_closed_get_impl(receiver);
}

impl _io__Buffered_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_close_impl(receiver);
}

impl _io__Buffered_detach_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_detach_impl(receiver);
}

impl _io__Buffered_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_seekable_impl(receiver);
}

impl _io__Buffered_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_readable_impl(receiver);
}

impl _io__Buffered_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_writable_impl(receiver);
}

impl _io__Buffered_name_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return _io__Buffered_name_get_impl(receiver);
}

impl _io__Buffered_mode_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return _io__Buffered_mode_get_impl(receiver);
}

impl _io__Buffered_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_fileno_impl(receiver);
}

impl _io__Buffered_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_isatty_impl(receiver);
}

impl _io__Buffered_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_flush_impl(receiver);
}

impl _io__Buffered_peek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = 0;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_ssize(value);
        }
        return _io__Buffered_peek_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_peek_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: i64 = 0;
    if count > 0 {
        size = PyLong_AsSsize_t(clinic_args[0]);
        if size == -1 and failed() {
            return NULL;
        }
    }
    return _io__Buffered_peek_impl(receiver, size);
}

impl _io__Buffered_peek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("peek", int(nargs), 0, 1) {
        return NULL;
    }
    if exact_int_at(args, nargs, 0) {
        return _io__Buffered_peek_direct(receiver, args, nargs);
    }
    return _io__Buffered_peek_bound(receiver, args, nargs);
}

impl _io__Buffered_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io__Buffered_read_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read", int(nargs), 0, 1) {
        return NULL;
    }
    return _io__Buffered_read_bound(receiver, args, nargs);
}

impl _io__Buffered_read1_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_ssize(value);
        }
        return _io__Buffered_read1_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_read1_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: i64 = -1;
    if count > 0 {
        size = PyLong_AsSsize_t(clinic_args[0]);
        if size == -1 and failed() {
            return NULL;
        }
    }
    return _io__Buffered_read1_impl(receiver, size);
}

impl _io__Buffered_read1_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read1", int(nargs), 0, 1) {
        return NULL;
    }
    if exact_int_at(args, nargs, 0) {
        return _io__Buffered_read1_direct(receiver, args, nargs);
    }
    return _io__Buffered_read1_bound(receiver, args, nargs);
}

impl _io__Buffered_readinto_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_writable_buffer(value, "readinto", "argument");
        try {
            return _io__Buffered_readinto_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_readinto1_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_writable_buffer(
            value, "readinto1", "argument"
        );
        try {
            return _io__Buffered_readinto1_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io__Buffered_readline_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readline", int(nargs), 0, 1) {
        return NULL;
    }
    return _io__Buffered_readline_bound(receiver, args, nargs);
}

impl _io__Buffered_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io__Buffered_tell_impl(receiver);
}

impl _io__Buffered_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        target: ptr[PyObject] = value;
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io__Buffered_seek_impl(receiver, target, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("seek", int(nargs), 1, 2) {
        return NULL;
    }
    return _io__Buffered_seek_bound(receiver, args, nargs);
}

impl _io__Buffered_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _Buffered_token);
        pos: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            pos = value;
        }
        return _io__Buffered_truncate_impl(receiver, cls, pos);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__Buffered_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    cls = defining_class_or_null(receiver, _Buffered_token);
    if cls == NULL {
        return NULL;
    }
    pos: ptr[PyObject] = borrowed_none();
    if count > 0 {
        pos = clinic_args[0];
    }
    return _io__Buffered_truncate_impl(receiver, cls, pos);
}

impl _io__Buffered_truncate_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__Buffered_truncate_direct(receiver, args, nargs);
    }
    values = unpack_stack(_io__Buffered_truncate_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__Buffered_truncate_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__Buffered_truncate_signature,
        args,
        nargs,
        kwnames,
        _io__Buffered_truncate_bound,
        receiver
    );
}

impl _io_BufferedReader___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        raw: ptr[PyObject] = value;
        buffer_size: i64 = DEFAULT_BUFFER_SIZE;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            buffer_size = convert_ssize(value);
        }
        return return_int(_io_BufferedReader___init___impl(receiver, raw, buffer_size));
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BufferedReader___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 1 and size <= 2 {
            bound = True;
            result = _io_BufferedReader___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_BufferedReader___init___signature, args, kwargs);
        if values {
            unpacked = _io_BufferedReader___init___bound(receiver, values, 2);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_BufferedReader___init___signature,
            args,
            kwargs,
            _io_BufferedReader___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_BufferedWriter___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        raw: ptr[PyObject] = value;
        buffer_size: i64 = DEFAULT_BUFFER_SIZE;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            buffer_size = convert_ssize(value);
        }
        return return_int(_io_BufferedWriter___init___impl(receiver, raw, buffer_size));
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BufferedWriter___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 1 and size <= 2 {
            bound = True;
            result = _io_BufferedWriter___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_BufferedWriter___init___signature, args, kwargs);
        if values {
            unpacked = _io_BufferedWriter___init___bound(receiver, values, 2);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_BufferedWriter___init___signature,
            args,
            kwargs,
            _io_BufferedWriter___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_BufferedWriter_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        buffer: BufferArgument = convert_buffer(value, "write", "argument");
        try {
            return _io_BufferedWriter_write_impl(receiver, buffer);
        } finally {
            buffer.close();
        }
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BufferedRWPair___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        reader: ptr[PyObject] = value;
        value = clinic_args[1];
        writer: ptr[PyObject] = value;
        buffer_size: i64 = DEFAULT_BUFFER_SIZE;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            buffer_size = convert_ssize(value);
        }
        return return_int(
            _io_BufferedRWPair___init___impl(receiver, reader, writer, buffer_size)
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BufferedRWPair___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 2 and size <= 3 {
            bound = True;
            result = _io_BufferedRWPair___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_BufferedRWPair___init___signature,
            args,
            kwargs,
            _io_BufferedRWPair___init___bound,
            receiver,
            checked=init_checks_arguments(receiver, BufferedRWPair_token)
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_BufferedRandom___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        raw: ptr[PyObject] = value;
        buffer_size: i64 = DEFAULT_BUFFER_SIZE;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            buffer_size = convert_ssize(value);
        }
        return return_int(_io_BufferedRandom___init___impl(receiver, raw, buffer_size));
    } except boundary_failure {
        return NULL;
    }
}

impl _io_BufferedRandom___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 1 and size <= 2 {
            bound = True;
            result = _io_BufferedRandom___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_BufferedRandom___init___signature, args, kwargs);
        if values {
            unpacked = _io_BufferedRandom___init___bound(receiver, values, 2);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_BufferedRandom___init___signature,
            args,
            kwargs,
            _io_BufferedRandom___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_IncrementalNewlineDecoder___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        decoder: ptr[PyObject] = value;
        value = clinic_args[1];
        translate: bool = convert_bool(value);
        errors: ptr[PyObject] = NULL;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            errors = value;
        }
        return return_int(
            _io_IncrementalNewlineDecoder___init___impl(
                receiver, decoder, translate, errors
            )
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_IncrementalNewlineDecoder___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 2 and size <= 3 {
            bound = True;
            result = _io_IncrementalNewlineDecoder___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(
            _io_IncrementalNewlineDecoder___init___signature, args, kwargs
        );
        if values {
            unpacked = _io_IncrementalNewlineDecoder___init___bound(
                receiver, values, 3
            );
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_IncrementalNewlineDecoder___init___signature,
            args,
            kwargs,
            _io_IncrementalNewlineDecoder___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_IncrementalNewlineDecoder_decode_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        input: ptr[PyObject] = value;
        final: bool = False;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            final = convert_bool(value);
        }
        return _io_IncrementalNewlineDecoder_decode_impl(receiver, input, final);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_IncrementalNewlineDecoder_decode_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 2 {
        return _io_IncrementalNewlineDecoder_decode_bound(receiver, args, nargs);
    }
    values = unpack_stack(
        _io_IncrementalNewlineDecoder_decode_signature, args, nargs, kwnames
    );
    if values {
        unpacked = _io_IncrementalNewlineDecoder_decode_bound(receiver, values, 2);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_IncrementalNewlineDecoder_decode_signature,
        args,
        nargs,
        kwnames,
        _io_IncrementalNewlineDecoder_decode_bound,
        receiver
    );
}

impl _io_IncrementalNewlineDecoder_getstate_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_IncrementalNewlineDecoder_getstate_impl(receiver);
}

impl _io_IncrementalNewlineDecoder_setstate_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    state: ptr[PyObject] = value;
    return _io_IncrementalNewlineDecoder_setstate_impl(receiver, state);
}

impl _io_IncrementalNewlineDecoder_reset_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_IncrementalNewlineDecoder_reset_impl(receiver);
}

impl _io_TextIOWrapper___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        buffer: ptr[PyObject] = value;
        encoding: ptr[u8] = ptr[u8]();
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            encoding = convert_cstr(
                value, "TextIOWrapper", argument_label("encoding", 2), True
            );
        }
        errors: ptr[PyObject] = borrowed_none();
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            errors = value;
        }
        newline: ptr[u8] = ptr[u8]();
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            newline = convert_cstr(
                value, "TextIOWrapper", argument_label("newline", 4), True
            );
        }
        line_buffering: bool = False;
        if count > 4 and clinic_args[4] != NULL {
            value = clinic_args[4];
            line_buffering = convert_bool(value);
        }
        write_through: bool = False;
        if count > 5 and clinic_args[5] != NULL {
            value = clinic_args[5];
            write_through = convert_bool(value);
        }
        return return_int(
            _io_TextIOWrapper___init___impl(
                receiver,
                buffer,
                encoding,
                errors,
                newline,
                line_buffering,
                write_through
            )
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 1 and size <= 6 {
            bound = True;
            result = _io_TextIOWrapper___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_TextIOWrapper___init___signature, args, kwargs);
        if values {
            unpacked = _io_TextIOWrapper___init___bound(receiver, values, 6);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_TextIOWrapper___init___signature,
            args,
            kwargs,
            _io_TextIOWrapper___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_TextIOWrapper_reconfigure_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        encoding: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            encoding = value;
        }
        errors: ptr[PyObject] = borrowed_none();
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            errors = value;
        }
        newline: ptr[PyObject] = NULL;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            newline = value;
        }
        line_buffering: ptr[PyObject] = borrowed_none();
        if count > 3 and clinic_args[3] != NULL {
            value = clinic_args[3];
            line_buffering = value;
        }
        write_through: ptr[PyObject] = borrowed_none();
        if count > 4 and clinic_args[4] != NULL {
            value = clinic_args[4];
            write_through = value;
        }
        return _io_TextIOWrapper_reconfigure_impl(
            receiver, encoding, errors, newline, line_buffering, write_through
        );
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_reconfigure_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    encoding: ptr[PyObject] = borrowed_none();
    if count > 0 {
        encoding = clinic_args[0];
    }
    errors: ptr[PyObject] = borrowed_none();
    if count > 1 {
        errors = clinic_args[1];
    }
    newline: ptr[PyObject] = NULL;
    if count > 2 {
        newline = clinic_args[2];
    }
    line_buffering: ptr[PyObject] = borrowed_none();
    if count > 3 {
        line_buffering = clinic_args[3];
    }
    write_through: ptr[PyObject] = borrowed_none();
    if count > 4 {
        write_through = clinic_args[4];
    }
    return _io_TextIOWrapper_reconfigure_impl(
        receiver, encoding, errors, newline, line_buffering, write_through
    );
}

impl _io_TextIOWrapper_reconfigure_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 0 {
        return _io_TextIOWrapper_reconfigure_direct(receiver, args, nargs);
    }
    values = unpack_stack(
        _io_TextIOWrapper_reconfigure_signature, args, nargs, kwnames
    );
    if values {
        unpacked = _io_TextIOWrapper_reconfigure_bound(receiver, values, 5);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io_TextIOWrapper_reconfigure_signature,
        args,
        nargs,
        kwnames,
        _io_TextIOWrapper_reconfigure_bound,
        receiver
    );
}

impl _io_TextIOWrapper_detach_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_detach_impl(receiver);
}

impl _io_TextIOWrapper_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        text: ptr[PyObject] = convert_unicode(value, "write", "argument");
        return _io_TextIOWrapper_write_impl(receiver, text);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_TextIOWrapper_read_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_TextIOWrapper_read_bound(receiver, args, nargs);
}

impl _io_TextIOWrapper_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_ssize(value);
        }
        return _io_TextIOWrapper_readline_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_readline_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    size: i64 = -1;
    if count > 0 {
        size = PyLong_AsSsize_t(clinic_args[0]);
        if size == -1 and failed() {
            return NULL;
        }
    }
    return _io_TextIOWrapper_readline_impl(receiver, size);
}

impl _io_TextIOWrapper_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readline", int(nargs), 0, 1) {
        return NULL;
    }
    if exact_int_at(args, nargs, 0) {
        return _io_TextIOWrapper_readline_direct(receiver, args, nargs);
    }
    return _io_TextIOWrapper_readline_bound(receiver, args, nargs);
}

impl _io_TextIOWrapper_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        cookie: ptr[PyObject] = value;
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io_TextIOWrapper_seek_impl(receiver, cookie, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("seek", int(nargs), 1, 2) {
        return NULL;
    }
    return _io_TextIOWrapper_seek_bound(receiver, args, nargs);
}

impl _io_TextIOWrapper_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_tell_impl(receiver);
}

impl _io_TextIOWrapper_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        pos: ptr[PyObject] = borrowed_none();
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            pos = value;
        }
        return _io_TextIOWrapper_truncate_impl(receiver, pos);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_TextIOWrapper_truncate_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    pos: ptr[PyObject] = borrowed_none();
    if count > 0 {
        pos = clinic_args[0];
    }
    return _io_TextIOWrapper_truncate_impl(receiver, pos);
}

impl _io_TextIOWrapper_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("truncate", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_TextIOWrapper_truncate_direct(receiver, args, nargs);
}

impl _io_TextIOWrapper_fileno_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_fileno_impl(receiver);
}

impl _io_TextIOWrapper_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_seekable_impl(receiver);
}

impl _io_TextIOWrapper_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_readable_impl(receiver);
}

impl _io_TextIOWrapper_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_writable_impl(receiver);
}

impl _io_TextIOWrapper_isatty_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_isatty_impl(receiver);
}

impl _io_TextIOWrapper_flush_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_flush_impl(receiver);
}

impl _io_TextIOWrapper_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_TextIOWrapper_close_impl(receiver);
}

impl _io_TextIOWrapper_name_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_TextIOWrapper_name_get_impl(receiver);
}

impl _io_TextIOWrapper_closed_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_TextIOWrapper_closed_get_impl(receiver);
}

impl _io_TextIOWrapper_newlines_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_TextIOWrapper_newlines_get_impl(receiver);
}

impl _io_TextIOWrapper_errors_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_TextIOWrapper_errors_get_impl(receiver);
}

impl _io_TextIOWrapper__CHUNK_SIZE_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_TextIOWrapper__CHUNK_SIZE_get_impl(receiver);
}

impl _io_TextIOWrapper__CHUNK_SIZE_set(
    receiver: ptr[PyObject], value: ptr[PyObject], context: u64
) -> i32 {
    return i32(_io_TextIOWrapper__CHUNK_SIZE_set_impl(receiver, value));
}

impl _io__TextIOBase_detach_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        cls = defining_class(receiver, _TextIOBase_token);
        return _io__TextIOBase_detach_impl(receiver, cls);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__TextIOBase_detach_direct(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    cls = defining_class_or_null(receiver, _TextIOBase_token);
    if cls == NULL {
        return NULL;
    }
    return _io__TextIOBase_detach_impl(receiver, cls);
}

impl _io__TextIOBase_detach_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs == 0 {
        return _io__TextIOBase_detach_direct(receiver, args, nargs);
    }
    return invoke_stack(
        _io__TextIOBase_detach_signature,
        args,
        nargs,
        kwnames,
        _io__TextIOBase_detach_bound,
        receiver
    );
}

impl _io__TextIOBase_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _TextIOBase_token);
        size: i32 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_int(value);
        }
        return _io__TextIOBase_read_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__TextIOBase_read_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__TextIOBase_read_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__TextIOBase_read_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__TextIOBase_read_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__TextIOBase_read_signature,
        args,
        nargs,
        kwnames,
        _io__TextIOBase_read_bound,
        receiver
    );
}

impl _io__TextIOBase_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _TextIOBase_token);
        size: i32 = -1;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            size = convert_int(value);
        }
        return _io__TextIOBase_readline_impl(receiver, cls, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__TextIOBase_readline_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 1 {
        return _io__TextIOBase_readline_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__TextIOBase_readline_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__TextIOBase_readline_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__TextIOBase_readline_signature,
        args,
        nargs,
        kwnames,
        _io__TextIOBase_readline_bound,
        receiver
    );
}

impl _io__TextIOBase_write_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        cls = defining_class(receiver, _TextIOBase_token);
        value = clinic_args[0];
        s: str = convert_str(value, "write", argument_label("", 1));
        return _io__TextIOBase_write_impl(receiver, cls, s);
    } except boundary_failure {
        return NULL;
    }
}

impl _io__TextIOBase_write_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 1 and nargs <= 1 {
        return _io__TextIOBase_write_bound(receiver, args, nargs);
    }
    values = unpack_stack(_io__TextIOBase_write_signature, args, nargs, kwnames);
    if values {
        unpacked = _io__TextIOBase_write_bound(receiver, values, 1);
        PyMem_Free(values);
        return unpacked;
    }
    return invoke_stack(
        _io__TextIOBase_write_signature,
        args,
        nargs,
        kwnames,
        _io__TextIOBase_write_bound,
        receiver
    );
}

impl _io__TextIOBase_encoding_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io__TextIOBase_encoding_get_impl(receiver);
}

impl _io__TextIOBase_newlines_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io__TextIOBase_newlines_get_impl(receiver);
}

impl _io__TextIOBase_errors_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io__TextIOBase_errors_get_impl(receiver);
}

impl _io_StringIO_getvalue_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_getvalue_impl(receiver);
}

impl _io_StringIO_tell_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_tell_impl(receiver);
}

impl _io_StringIO_read_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_StringIO_read_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_StringIO_read_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("read", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_StringIO_read_bound(receiver, args, nargs);
}

impl _io_StringIO_readline_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        size: i64 = -1;
        if count > 0 and clinic_args[0] != NULL {
            size = convert_optional_ssize(clinic_args[0], -1);
        }
        return _io_StringIO_readline_impl(receiver, size);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_StringIO_readline_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("readline", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_StringIO_readline_bound(receiver, args, nargs);
}

impl _io_StringIO_truncate_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        pos: i64 = self_pos(receiver);
        if count > 0 and clinic_args[0] != NULL {
            pos = convert_optional_ssize(clinic_args[0], self_pos(receiver));
        }
        return _io_StringIO_truncate_impl(receiver, pos);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_StringIO_truncate_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs > 1) and not check_positional("truncate", int(nargs), 0, 1) {
        return NULL;
    }
    return _io_StringIO_truncate_bound(receiver, args, nargs);
}

impl _io_StringIO_seek_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        value = clinic_args[0];
        pos: i64 = convert_ssize(value);
        whence: i32 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            whence = convert_int(value);
        }
        return _io_StringIO_seek_impl(receiver, pos, whence);
    } except boundary_failure {
        return NULL;
    }
}

impl _io_StringIO_seek_call(
    receiver: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if (nargs < 1 or nargs > 2) and not check_positional("seek", int(nargs), 1, 2) {
        return NULL;
    }
    return _io_StringIO_seek_bound(receiver, args, nargs);
}

impl _io_StringIO_write_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    s: ptr[PyObject] = value;
    return _io_StringIO_write_impl(receiver, s);
}

impl _io_StringIO_close_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_close_impl(receiver);
}

impl _io_StringIO___init___bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        initial_value: ptr[PyObject] = NULL;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            initial_value = value;
        }
        newline: ptr[PyObject] = NULL;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            newline = value;
        }
        return return_int(_io_StringIO___init___impl(receiver, initial_value, newline));
    } except boundary_failure {
        return NULL;
    }
}

impl _io_StringIO___init___init(
    receiver: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> i32 {
    result: ptr[PyObject] = NULL;
    bound = False;
    if kwargs == NULL or jacpy_dict_size(kwargs) == 0 {
        size = PyTuple_Size(args);
        if size >= 0 and size <= 2 {
            bound = True;
            result = _io_StringIO___init___bound(
                receiver, jacpy_tuple_items(args), size
            );
        }
    }
    if not bound {
        values = unpack_mapping(_io_StringIO___init___signature, args, kwargs);
        if values {
            unpacked = _io_StringIO___init___bound(receiver, values, 2);
            PyMem_Free(values);
            bound = True;
            result = unpacked;
        }
    }
    if not bound {
        result = invoke_tuple(
            _io_StringIO___init___signature,
            args,
            kwargs,
            _io_StringIO___init___bound,
            receiver
        );
    }
    if not result {
        return i32(-1);
    }
    jacpy_release(result);
    return i32(0);
}

impl _io_StringIO_readable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_readable_impl(receiver);
}

impl _io_StringIO_writable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_writable_impl(receiver);
}

impl _io_StringIO_seekable_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO_seekable_impl(receiver);
}

impl _io_StringIO___getstate___call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return _io_StringIO___getstate___impl(receiver);
}

impl _io_StringIO___setstate___call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    state: ptr[PyObject] = value;
    return _io_StringIO___setstate___impl(receiver, state);
}

impl _io_StringIO_closed_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return _io_StringIO_closed_get_impl(receiver);
}

impl _io_StringIO_line_buffering_get(
    receiver: ptr[PyObject], context: u64
) -> ptr[PyObject] {
    return _io_StringIO_line_buffering_get_impl(receiver);
}

impl _io_StringIO_newlines_get(receiver: ptr[PyObject], context: u64) -> ptr[PyObject] {
    return _io_StringIO_newlines_get_impl(receiver);
}
