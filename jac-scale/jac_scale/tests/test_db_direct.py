import os

from testcontainers.mongodb import MongoDbContainer


def close_mongo_client():
    try:
        import jac_scale.db as db_mod

        if hasattr(db_mod, "_client") and db_mod._client:
            db_mod._client.close()
            db_mod._client = None
    except ImportError:
        pass


class TestDirectDb:
    mongo_container: MongoDbContainer
    mongo_uri: str

    @classmethod
    def setup_class(cls):
        cls.mongo_container = MongoDbContainer("mongo:latest")
        cls.mongo_container.start()
        cls.mongo_uri = cls.mongo_container.get_connection_url()
        os.environ["MONGODB_URI"] = cls.mongo_uri

    @classmethod
    def teardown_class(cls):
        cls.mongo_container.stop()
        if "MONGODB_URI" in os.environ:
            del os.environ["MONGODB_URI"]

        close_mongo_client()

    def test_direct_db_access(self):
        """Test db() builtin via JacRuntime (plugin hook)."""
        from jac_scale.db import Db
        from jaclang.pycore.runtime import JacRuntime

        # Test default db name
        db = JacRuntime.db()
        assert isinstance(db, Db)
        assert db.db_name == "jac_db"

        # Test custom db name
        db_custom = JacRuntime.db(db_name="my_custom_db")
        assert isinstance(db_custom, Db)
        assert db_custom.db_name == "my_custom_db"

        # Verify CRUD operations
        col_name = "direct_access_test"
        doc = {"key": "value", "num": 42}

        # Insert
        insert_res = db.insert_one(col_name, doc)
        assert insert_res.inserted_id is not None

        # Find One
        found = db.find_one(col_name, {"key": "value"})
        assert found is not None
        assert found["num"] == 42

        # Find (Cursor)
        cursor = db.find(col_name, {"num": 42})
        results = list(cursor)
        assert len(results) == 1
        assert results[0]["key"] == "value"

        # Update
        update_res = db.update_one(col_name, {"key": "value"}, {"$set": {"num": 100}})
        assert update_res.modified_count == 1

        updated = db.find_one(col_name, {"key": "value"})
        assert updated["num"] == 100

        # Delete
        delete_res = db.delete_one(col_name, {"key": "value"})
        assert delete_res.deleted_count == 1

        deleted = db.find_one(col_name, {"key": "value"})
        assert deleted is None

    def test_db_builtin_import(self):
        """Test that db is available as a builtin."""
        from jaclang.runtimelib.builtin import db

        # Verify it's callable
        assert callable(db)

        # Test it returns correct instance
        from jac_scale.db import Db

        db_instance = db()
        assert isinstance(db_instance, Db)

    def test_multiple_db_connections(self):
        """Test multiple database connections with different names."""
        from jaclang.pycore.runtime import JacRuntime

        # Create multiple database connections
        db1 = JacRuntime.db(db_name="db_one")
        db2 = JacRuntime.db(db_name="db_two")

        assert db1.db_name == "db_one"
        assert db2.db_name == "db_two"

        # Test operations on different databases
        db1.insert_one("test_col", {"source": "db1"})
        db2.insert_one("test_col", {"source": "db2"})

        doc1 = db1.find_one("test_col", {"source": "db1"})
        doc2 = db2.find_one("test_col", {"source": "db2"})

        assert doc1 is not None
        assert doc1["source"] == "db1"
        assert doc2 is not None
        assert doc2["source"] == "db2"
