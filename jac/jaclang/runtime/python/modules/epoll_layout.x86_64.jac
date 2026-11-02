"""struct epoll_event as x86_64 Linux packs it: the 64-bit data member follows events directly."""

glob EPOLL_EVENT_SIZE: int = 12,
     EPOLL_DATA_OFFSET: int = 4;
