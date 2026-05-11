"""Guarded re-exports for motor async MongoDB driver (install group: [data])."""

with entry {
    try {
        import from motor.motor_asyncio { AsyncIOMotorClient }
        HAS_MOTOR = True;
    } except ImportError {
        AsyncIOMotorClient = None;
        HAS_MOTOR = False;
    }
}
