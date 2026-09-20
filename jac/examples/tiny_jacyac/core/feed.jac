import os;
import datetime;
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.server.bridge { BridgeError }
import from core.scoring { Score, reputation }

node Profile {
    has username: str;
}

node Post {
    has body: str,
        author: str,
        owner: str,
        created: str;
}

node Like {
    has post_id: str,
        owner: str;
}

obj PostView {
    has id: str,
        body: str,
        author: str,
        created: str,
        likes: int = 0,
        liked: bool = False,
        mine: bool = False;
}

obj Feed {
    has posts: list[PostView] = [],
        viewer: str = "",
        score: Score = Score(),
        service_pid: int = 0;
}

def me -> Profile {
    profiles = [root-->[?:Profile]];
    if jid(root) == jid(root.shared) or not profiles {
        raise ValueError("Please sign in first.");
    }
    return profiles[0];
}

def:pub join(username: str) -> str {
    manager = JacRuntime.get_user_manager(JacRuntime.get_base_path_dir() or ".");
    user = manager.find_user_by_identity(username.strip());
    if not user or manager.get_root_id(str(user["user_id"])) != jid(root) {
        raise ValueError("This username does not belong to your signed-in account.");
    }
    name = manager.get_username(str(user["user_id"])) or username.strip();
    profiles = [root-->[?:Profile]];
    if not profiles {
        root ++> Profile(username=name);
    } else {
        profiles[0].username = name;
    }
    return name;
}

def:pub publish(body: str) -> str {
    profile = me();
    text = body.strip();
    if not text or len(text) > 280 {
        raise ValueError("Write between 1 and 280 characters.");
    }
    post = root.shared ++> Post(
        body=text,
        author=profile.username,
        owner=jid(root),
        created=datetime.datetime.now(datetime.UTC).isoformat()
    );
    grant(post, level=AccessLevel.READ);
    return jid(post);
}

def:pub toggle_like(post_id: str) -> bool {
    me();
    posts = [root.shared-->[?:Post]];
    if not any(jid(p) == post_id for p in posts) {
        raise ValueError("That post is no longer available.");
    }
    for like in [root.shared-->[?:Like]] {
        if like.post_id == post_id and like.owner == jid(root) {
            del like;
            return False;
        }
    }
    like = root.shared ++> Like(post_id=post_id, owner=jid(root));
    grant(like, level=AccessLevel.READ);
    return True;
}

def:pub remove_post(post_id: str) -> bool {
    me();
    for post in [root.shared-->[?:Post]] {
        if jid(post) == post_id {
            if post.owner != jid(root) {
                raise ValueError("You can only delete your own posts.");
            }
            del post;
            return True;
        }
    }
    raise ValueError("That post is no longer available.");
}

async def:pub load_feed -> Feed {
    posts = [root.shared-->[?:Post]];
    likes = [root.shared-->[?:Like]];
    profiles = [root-->[?:Profile]];
    mine = [
        p
        for p in posts
        if p.owner == jid(root)
    ];
    mine_ids = {jid(p) for p in mine};
    score = Score(available=False);
    try {
        score = await reputation(
            len(mine),
            sum(
                1
                for l in likes
                if l.post_id in mine_ids
            )
        );
    } except BridgeError {}
    posts.sort(key=lambda (p: Post) { p.created; }, reverse=True);
    views = [
        PostView(
            id=jid(p),
            body=p.body,
            author=p.author,
            created=p.created,
            likes=sum(
                1
                for l in likes
                if l.post_id == jid(p)
            ),
            liked=any(l.post_id == jid(p) and l.owner == jid(root) for l in likes),
            mine=p.owner == jid(root)
        ) for p in posts[:50]
    ];
    return Feed(
        posts=views,
        viewer=profiles[0].username if profiles else "",
        score=score,
        service_pid=os.getpid()
    );
}
