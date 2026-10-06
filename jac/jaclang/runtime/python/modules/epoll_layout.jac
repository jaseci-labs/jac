"""struct epoll_event with natural alignment (every Linux architecture but x86_64)."""

glob EPOLL_EVENT_SIZE: int = 16,
     EPOLL_DATA_OFFSET: int = 8;
