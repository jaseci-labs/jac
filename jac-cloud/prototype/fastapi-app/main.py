"""File covering example FastAPI implementation."""

from typing import List, Optional

from fastapi import FastAPI, HTTPException, Path, Query

from pydantic import BaseModel


app = FastAPI()


# ----- Models -----
class Item(BaseModel):
    """Base model v1."""

    id: int
    name: str
    description: Optional[str] = None
    price: float
    in_stock: bool = True


# In-memory storage for demo purposes
items_db: List[Item] = []


# ----- Basic Endpoints -----
@app.get("/")
def read_root() -> dict:
    """Get root."""
    return {"Hello": "World", "message": "FastAPI is running on Elastic Beanstalkv2!"}


@app.get("/health")
def health_check() -> dict:
    """Health check."""
    return {"status": "healthy"}


# ----- Item Endpoints -----
@app.post("/items", response_model=Item)
def create_item(item: Item) -> Item:
    """Create a new item."""
    items_db.append(item)
    return item


@app.get("/items", response_model=List[Item])
def get_items(skip: int = 0, limit: int = 10) -> List[Item]:
    """Get all items with optional pagination."""
    return items_db[skip : skip + limit]


item_id_path = Path(..., description="The ID of the item to retrieve")


@app.get("/items/{item_id}", response_model=Item)
def get_item(item_id: int = item_id_path) -> Item:
    """Get item."""
    for item in items_db:
        if item.id == item_id:
            return item
    raise HTTPException(status_code=404, detail="Item not found")


@app.put("/items/{item_id}", response_model=Item)
def update_item(item_id: int, updated_item: Item) -> Item:
    """Update an existing item."""
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            items_db[idx] = updated_item
            return updated_item
    raise HTTPException(status_code=404, detail="Item not found")


@app.delete("/items/{item_id}")
def delete_item(item_id: int) -> dict:
    """Delete an item by ID."""
    for idx, item in enumerate(items_db):
        if item.id == item_id:
            items_db.pop(idx)
            return {"message": f"Item {item_id} deleted"}
    raise HTTPException(status_code=404, detail="Item not found")


# ----- Query Example -----
# Define at module level
name_query = Query(None, description="Search items by name")


@app.get("/search")
def search_items(name: Optional[str] = name_query) -> List[Item]:
    """Search items by name."""
    if name:
        return [item for item in items_db if name.lower() in item.name.lower()]
    return items_db
