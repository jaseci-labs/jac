import from c {
    def pthread_create(thread: int, attr: int, start: int, arg: int) -> i32;
}
import from c { def pthread_detach(thread: int) -> i32;  }
import from c { def pthread_join(thread: int, retval: int) -> i32;  }
import from c { def pthread_self -> int;  }
import from c { def pthread_mutex_init(mutex: int, attr: int) -> i32;  }
import from c { def pthread_mutex_destroy(mutex: int) -> i32;  }
import from c { def pthread_mutex_lock(mutex: int) -> i32;  }
import from c { def pthread_mutex_trylock(mutex: int) -> i32;  }
import from c { def pthread_mutex_unlock(mutex: int) -> i32;  }
import from c { def malloc(size: u64) -> int;  }
import from c { def free(pointer: int);  }
import from c { def atexit(handler: int) -> i32;  }

def:pub th_alloc(size: int) -> int;


def:pub th_free(ptr: int);


def:pub th_mutex_init(mutex: int) -> int;


def:pub th_mutex_destroy(mutex: int) -> int;


def:pub th_mutex_lock(mutex: int) -> int;


def:pub th_mutex_trylock(mutex: int) -> int;


def:pub th_mutex_unlock(mutex: int) -> int;


def:pub th_spawn(start: int, arg: int) -> int;


def:pub th_detach(handle: int) -> int;


def:pub th_join(handle: int) -> int;


def:pub th_self -> int;


def:pub th_at_exit(handler: int) -> int;
