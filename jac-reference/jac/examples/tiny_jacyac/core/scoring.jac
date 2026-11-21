import os;

obj Score {
    has points: int = 0,
        rank: str = "New voice",
        available: bool = True,
        service_pid: int = 0;
}

def:pub reputation(posts: int, likes: int) -> Score {
    points = max(0, posts) * 10 + max(0, likes) * 3;
    rank = "Community spark"
        if points >= 100
        else "Regular" if points >= 30 else "New voice";
    return Score(points=points, rank=rank, service_pid=os.getpid());
}
