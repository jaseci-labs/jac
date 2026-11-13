graph import {
    edge Embed: embed --> bringup;
    edge Libc: _libc --> embed | materialize;
    edge Materialize: materialize --> bringup;
    edge Report: report --> bringup | embed | materialize;
    edge Trailer: trailer --> materialize;

    _libc ++> [
        embed { c_alloc_string, c_string, peek, poke },
        materialize { getuid, listdir, read_at, write_file },
    ]
    embed ++> bringup { Embed, open_tree }
    materialize ++> bringup { materialize }
    report ++> [
        bringup | embed { die },
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
