graph import {
    _libc ++> [
        embed { c_alloc_string, c_string, peek, poke },
        materialize { getuid, listdir, read_at, write_file },
    ]
    embed ++> [
        bringup { Embed, open_tree },
        js_engine { CStrArray, export_ca_bundle },
    ]
    materialize ++> bringup { materialize }
    report ++> [
        bringup | embed | js_engine { die },
        materialize { die, say },
    ]
    trailer ++> materialize {
        MAGIC,
        OVERLAY_MAGIC,
        TRAILER_LEN,
        Trailer,
        parse_trailer,
        region_start,
        rt_key
    }
}
