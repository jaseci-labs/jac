# Firestore kvstore() Demo

A minimal REST app demonstrating `kvstore()` backed by Google Cloud Firestore.

## Prerequisites

```bash
pip install jac-scale[firebase]
```

## Configuration

Set your Firebase project ID via environment variable:

```bash
export FIREBASE_PROJECT_ID="my-firebase-project"
# or: export FIRESTORE_PROJECT_ID="my-firebase-project"
```

For local development, authenticate with Application Default Credentials:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
# or: gcloud auth application-default login
```

## Run

```bash
jac start app.jac
```

## API Walkthrough

```bash
# Health check
curl http://localhost:8000/walker/health

# Store a value
curl -X POST http://localhost:8000/walker/set_value \
  -H "Content-Type: application/json" \
  -d '{"key": "greeting", "value": {"text": "Hello, Firestore!"}}'

# Retrieve it
curl http://localhost:8000/walker/get_value?key=greeting

# Bulk insert
curl -X POST http://localhost:8000/walker/bulk_insert \
  -H "Content-Type: application/json" \
  -d '{
    "col_name": "items",
    "documents": [
      {"_id": "apple", "name": "Apple", "price": 1.20},
      {"_id": "banana", "name": "Banana", "price": 0.50},
      {"_id": "cherry", "name": "Cherry", "price": 3.00}
    ]
  }'

# Query with filters ( Mongo-style operators)
curl -X POST http://localhost:8000/walker/query \
  -H "Content-Type: application/json" \
  -d '{"col_name": "items", "filter": {"price": {"$gte": 1.0}}}'

# Update matching documents
curl -X POST http://localhost:8000/walker/update_docs \
  -H "Content-Type: application/json" \
  -d '{"col_name": "items", "filter": {"name": "Apple"}, "update": {"price": 1.50}}'

# Delete matching documents
curl -X POST http://localhost:8000/walker/delete_docs \
  -H "Content-Type: application/json" \
  -d '{"col_name": "items", "filter": {"price": {"$lt": 1.0}}}'
```

## Key Points

- **Same API as MongoDB**: `kvstore()` provides an identical interface whether you use `db_type='mongodb'`, `db_type='firestore'`, or `db_type='redis'`. Switch backends by changing one line.
- **Namespaced collections**: Collections are stored as `{db_name}__{col_name}` in Firestore, so multiple apps can safely share one project.
- **No raw SDK calls**: Everything goes through the `Db` abstraction with no coupling to `google-cloud-firestore` internals.
