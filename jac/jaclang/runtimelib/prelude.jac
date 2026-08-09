import from collections.abc {
    AsyncIterable,
    AsyncIterator,
    Awaitable,
    Callable,
    Coroutine,
    Iterable,
    Iterator,
    Mapping,
    MutableMapping,
    MutableSequence,
    Sequence
}
import from typing { Annotated, ClassVar, Literal }

glob AMBIENT_PROTOCOLS: tuple = (
         AsyncIterable,
         AsyncIterator,
         Awaitable,
         Callable,
         Coroutine,
         Iterable,
         Iterator,
         Mapping,
         MutableMapping,
         MutableSequence,
         Sequence
     ),
     AMBIENT_FORMS: tuple = (Annotated, ClassVar, Literal);
