import from core.async_utils { sleep }

impl DocsShell.load(want_version: str, want_path: str) -> None {
    loading = True;
    if len(versions) == 0 {
        st = await docs_status();
        while not st.ready {
            waiting = True;
            await sleep(NOT_READY_POLL_MS);
            st = await docs_status();
        }
        waiting = False;
        versions = st.versions;
        latest_label = st.latest_label;
    }
    if tree_version != want_version {
        branch = await doc_tree(version=want_version);
        if branch is not None {
            tree = branch.tree;
            tree_version = want_version;
        }
    }
    p = root spawn doc_page(version=want_version, path=want_path);
    page = (p.reports[0] if p.reports else None) as DocPageView | None;
    loading = False;
}
