def probe_kind -> str {
    import from jaclang.server.session { Session }
    return Session.__name__;
}


def probe_store -> str {
    import from jaclang.data.store { AnchorRow }
    return AnchorRow.__name__;
}
