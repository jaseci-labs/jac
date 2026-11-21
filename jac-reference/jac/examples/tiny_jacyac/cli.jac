import argparse;
import asyncio;
import getpass;
import json;
import os;
import sys;
import urllib.request;
import from pathlib { Path }
import from jaclang.server { sv_client }
import from core.feed { join, publish, toggle_like, remove_post, load_feed }

def auth_request(base: str, username: str, password: str) -> str {
    payload = json.dumps(
        {
            "identity": {"type": "username", "value": username},
            "credential": {"type": "password", "password": password}
        }
    ).encode();
    request = urllib.request.Request(
        base + "/api/feed/user/login",
        data=payload,
        headers={"Content-Type": "application/json"}
    );
    with urllib.request.urlopen(request, timeout=15) as response {
        return str(json.loads(response.read())["data"]["token"]);
    }
}

async def main -> int {
    parser = argparse.ArgumentParser(
        description="Tiny JacYac: your community in a terminal."
    );
    parser.add_argument(
        "--url", `default=os.environ.get("TINY_JACYAC_URL", "http://127.0.0.1:8000")
    );
    parser.add_argument(
        "command",
        choices=["login", "logout", "feed", "post", "like", "delete", "score"]
    );
    parser.add_argument("value", nargs="?", `default="");
    args = parser.parse_args();
    base = str(args.url).rstrip("/");
    credentials = Path(
        os.environ.get("TINY_JACYAC_SESSION", str(Path.home() / ".tiny-jacyac.json"))
    );
    os.environ["JAC_APP_FEED_URL"] = base + "/api/feed";
    try {
        if args.command == "logout" {
            credentials.unlink(missing_ok=True);
            print("Signed out.");
            return 0;
        }
        if args.command == "login" {
            if not args.value {
                parser.error("login needs a username");
            }
            password = os.environ.get("TINY_JACYAC_PASSWORD")
                or getpass.getpass("Password: ");
            token = auth_request(base, str(args.value), password);
            sv_client.set_bearer_token(token);
            name = await join(str(args.value));
            fd = os.open(
                str(credentials), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600
            );
            with os.fdopen(fd, "w") as handle {
                json.dump({"url": base, "token": token}, handle);
            }
            credentials.chmod(0o600);
            print("Signed in as @" + name);
            return 0;
        }
        if credentials.exists() {
            saved = json.loads(credentials.read_text());
            if saved.get("url") == base {
                sv_client.set_bearer_token(str(saved["token"]));
            }
        }
        if args.command in ["post", "like", "delete"] and not args.value {
            parser.error(args.command + " needs text or a post ID");
        }
        if args.command == "post" {
            print(await publish(str(args.value)));
        } elif args.command == "like" {
            print("Liked" if await toggle_like(str(args.value)) else "Unliked");
        } elif args.command == "delete" {
            await remove_post(str(args.value));
            print("Deleted");
        } else {
            feed = await load_feed();
            if args.command == "score" {
                print(
                    f"{feed.score.points} points · {feed.score.rank}"
                        if feed.score.available
                        else "Score unavailable"
                );
            } else {
                for post in feed.posts {
                    print(
                        f"{post.id}  @{post.author}  {post.likes} likes\n  {post.body}"
                    );
                }
                if not feed.posts {
                    print("No thoughts yet. Say hello!");
                }
            }
        }
        return 0;
    } except Exception as e {
        print("Tiny JacYac: " + str(e), file=sys.stderr);
        return 1;
    }
}

with entry:__main__ {
    sys.`exit(asyncio.run(main()));
}
