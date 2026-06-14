"""Firestore-backed database implementation (future extension point).

FirestoreDb inherits the full Db method surface; every method falls through to
Db's NotImplementedError defaults until real Firestore implementations are
provided. To finish wiring it up, implement the methods (see MongoDb / RedisDb
for the pattern) and register FirestoreDb in kvstore().
"""
import from jac_scale.db { Db }

obj FirestoreDb(Db) {}
