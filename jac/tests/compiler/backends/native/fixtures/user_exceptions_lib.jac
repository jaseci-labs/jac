"""A user exception hierarchy raised from its own module (DB-API shape)."""

obj:pub Error(Exception) {}

obj:pub DatabaseError(Error) {}

obj:pub ProgrammingError(DatabaseError) {}

def:pub bind(i: int) -> int {
    if i > 0 {
        raise ProgrammingError("Error binding parameter " + str(i));
    }
    return i;
}
