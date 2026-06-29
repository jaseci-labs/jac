"""Firestore kvstore() demo.

A tiny REST app that stores and retrieves key-value pairs using
kvstore() backed by Google Cloud Firestore.

Setup
-----
1. Install the firebase optional dependency group:

       pip install jac-scale[firebase]

2. Point the Firestore client at your Firebase project.  Either:

   a) Set the environment variable:

          export FIREBASE_PROJECT_ID="my-firebase-project"
          # or: export FIRESTORE_PROJECT_ID="my-firebase-project"

   b) Or uncomment the [plugins.scale.database] section in jac.toml
      and fill in your project ID.

3. Authenticate with Application Default Credentials:

       # Inside GCP / Firebase: works automatically.
       # Local development:
       export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
       # or: gcloud auth application-default login

4. Run:

       jac start app.jac

5. Try it:

       # Store a value
       curl -X POST http://localhost:8000/walker/set_value \
         -H "Content-Type: application/json" \
         -d '{"key": "greeting", "value": {"text": "Hello, Firestore!"}}'

       # Retrieve it
       curl http://localhost:8000/walker/get_value?key=greeting

       # Check if it exists
       curl http://localhost:8000/walker/exists?key=greeting

       # Delete it
       curl -X POST http://localhost:8000/walker/delete_value \
         -H "Content-Type: application/json" \
         -d '{"key": "greeting"}'

       # List all keys in a collection
       curl http://localhost:8000/walker/list_collection?col_name=items

       # Insert multiple documents at once
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

       # Query with filters
       curl -X POST http://localhost:8000/walker/query \
         -H "Content-Type: application/json" \
         -d '{"col_name": "items", "filter": {"price": {"$gte": 1.0}}}'
"""

import from jaclang.scale.lib { kvstore }

# Open a Firestore-backed kvstore.
# The db_name is used as a namespace prefix on collection names
# (e.g. "demo__items") so multiple apps can share one project.
glob db = kvstore(db_name='demo', db_type='firestore');


"""Set (upsert) a key-value pair."""
walker set_value {
    has key: str,
        value: dict,
        col_name: str = 'default';

    can fire with Root entry {
        db.set(self.key, self.value, self.col_name);
        report {
            "ok": True,
            "key": self.key,
            "message": f"Stored '{self.key}' in collection '{self.col_name}'"
        };
    }
}


"""Get a value by key."""
walker get_value {
    has key: str,
        col_name: str = 'default';

    can fire with Root entry {
        result = db.get(self.key, self.col_name);
        if result is None {
            report {"ok": False, "error": f"Key '{self.key}' not found"};
        } else {
            report {"ok": True, "key": self.key, "value": result};
        }
    }
}


"""Check if a key exists."""
walker exists {
    has key: str,
        col_name: str = 'default';

    can fire with Root entry {
        found = db.exists(self.key, self.col_name);
        report {"ok": True, "key": self.key, "exists": found};
    }
}


"""Delete a key."""
walker delete_value {
    has key: str,
        col_name: str = 'default';

    can fire with Root entry {
        deleted = db.delete(self.key, self.col_name);
        report {
            "ok": True,
            "key": self.key,
            "deleted": deleted,
            "message": f"Deleted {deleted} document(s)"
        };
    }
}


"""Insert multiple documents into a collection."""
walker bulk_insert {
    has col_name: str = 'items',
        documents: list = [];

    can fire with Root entry {
        result = db.insert_many(self.col_name, self.documents);
        report {
            "ok": True,
            "inserted_ids": result.inserted_ids,
            "count": len(result.inserted_ids)
        };
    }
}


"""Query documents with Mongo-style filters."""
walker query {
    has col_name: str = 'items',
        filter: dict = {};

    can fire with Root entry {
        results = list(db.find(self.col_name, self.filter));
        report {"ok": True, "count": len(results), "results": results};
    }
}


"""Find a single document matching a filter."""
walker find_one {
    has col_name: str = 'items',
        filter: dict = {};

    can fire with Root entry {
        result = db.find_one(self.col_name, self.filter);
        if result is None {
            report {"ok": False, "error": "No matching document found"};
        } else {
            report {"ok": True, "result": result};
        }
    }
}


"""Update documents matching a filter."""
walker update_docs {
    has col_name: str = 'items',
        filter: dict = {},
        update: dict = {};

    can fire with Root entry {
        result = db.update_many(self.col_name, self.filter, {'$set': self.update});
        report {
            "ok": True,
            "matched": result.matched_count,
            "modified": result.modified_count
        };
    }
}


"""Delete documents matching a filter."""
walker delete_docs {
    has col_name: str = 'items',
        filter: dict = {};

    can fire with Root entry {
        result = db.delete_many(self.col_name, self.filter);
        report {"ok": True, "deleted": result.deleted_count};
    }
}


"""Get a document by its _id."""
walker get_by_id {
    has col_name: str = 'items',
        id: str;

    can fire with Root entry {
        result = db.find_by_id(self.col_name, self.id);
        if result is None {
            report {"ok": False, "error": f"Document '{self.id}' not found"};
        } else {
            report {"ok": True, "result": result};
        }
    }
}


"""Health check — verify the Firestore connection works."""
walker health {
    can fire with Root entry {
        # Read-only probe: confirm the Firestore connection is live.
        # exists() issues a single document.get() — a read-only Firestore
        # call that succeeds even when the document is absent, so we
        # catch connection errors with a try/except instead.
        try {
            db.exists('__health_check__', '_system');
            report {"ok": True, "status": "firestore connected"};
        } except e {
            report {"ok": False, "status": f"firestore unreachable: {e}"};
        }
    }
}
