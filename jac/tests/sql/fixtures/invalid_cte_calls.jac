"""Expected errors: CTEs accept queries and temporary aliases are automatic."""
import from jaclang.sql { cte, select, int64, named }
with entry {
    cte("people");
    cte(int64(1));
    q = select([named("n", int64(1))]);
    q.as_source("kids");
}
