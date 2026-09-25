graph import {
    _libc --> embed { c_alloc_string, c_string, peek, poke }
    _libc --> materialize { getuid, listdir, read_at, write_file }
    embed --> bringup { Embed, open_tree }
    materialize --> bringup { materialize }
    report --> bringup | embed { die }
    report --> materialize { die, say }
    trailer --> materialize {
        MAGIC,
        OVERLAY_MAGIC,
        REGION_DESC_LEN,
        TRAILER_LEN,
        Trailer,
        parse_region_desc,
        parse_trailer,
        region_start,
        rt_key
    }
}
