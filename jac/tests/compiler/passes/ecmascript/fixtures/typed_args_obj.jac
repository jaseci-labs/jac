"""Fixture: CL sends typed obj arguments to SV.

Tests that when client code passes a typed object as an argument
to a server function, it gets properly serialized with type metadata
and deserialized on the server side.
"""

obj SearchFilter {
    has query: str,
        max_results: int = 10,
        include_archived: bool = False;
}

obj SearchResult {
    has items: list,
        total_count: int,
        has_more: bool;
}

def:pub search(filter: SearchFilter) -> SearchResult {
    return SearchResult(items=[], total_count=0, has_more=False);
}

def:pub bulk_update(items: list[SearchFilter]) -> int {
    return len(items);
}

cl {
    sv import from .typed_args_obj { search, bulk_update }

    def:pub app -> JsxElement {
        has results: Any = None;

        async def doSearch(query: str) -> None {
            filter = SearchFilter(query=query, max_results=20);
            results = await search(filter);
        }

        return <div>
            <span>Found {results.total_count} items</span>
        </div>;
    }
}
