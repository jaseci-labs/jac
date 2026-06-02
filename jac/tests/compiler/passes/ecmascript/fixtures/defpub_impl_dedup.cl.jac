"""Client module that uses sv import. Has a separate .impl.jac file.

Tests that __jacCallFunction import is not duplicated when both the main
module (via sv import) and the impl module (via sv import) trigger injection.
"""

sv import from defpub_impl_dedup_server { create_item, list_items }

def:pub app -> JsxElement {
    has items: list = [],
        itemName: str = "";

    async def addItem -> None;
    async def loadItems -> None;

    return
        <div>
            <h1>Items</h1>
            <input
                value={itemName}
                onChange={lambda e: any -> None { itemName = e.target.value; }}
            />
            <button onClick={addItem}>Add</button>
        </div>;
}
