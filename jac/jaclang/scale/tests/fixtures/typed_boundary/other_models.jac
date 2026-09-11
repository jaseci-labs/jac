obj Detail {
    has label: str = "detail";
}

obj RepoMeta {
    has owner: str = "other",
        detail: Detail = Detail();
}
