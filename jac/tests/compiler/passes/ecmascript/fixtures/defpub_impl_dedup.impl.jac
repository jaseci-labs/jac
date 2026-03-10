"""Implementation for defpub_impl_dedup.cl.jac.

This impl module also uses sv import, which would trigger a second
__jacCallFunction injection in the child pass if not deduplicated.
"""

sv import from defpub_impl_dedup_server { create_item, list_items }

impl app {
    async def addItem -> None {
        if itemName.strip() {
            item = await create_item(itemName.strip());
            items = items.concat([item]);
            itemName = "";
        }
    }

    async def loadItems -> None {
        items = await list_items();
    }
}
