"""Pure data mappers — shape jacBuilder walker payloads into the dicts the UI
consumes, and prettify model ids. No component state, so these live outside the
`useStudio` provider and are imported where needed.
"""

cl {
    # Prettify a raw model id for display, e.g. "claude-opus-4-6" → "Claude Opus
    # 4 6". Title-cases the id segments.
    def:pub prettyModel(mid: str) -> str {
        if mid == "" or mid == "default" {
            return "Default";
        }
        parts = mid.split("-");
        words = [];
        for w in parts {
            if len(w) > 0 {
                words = words + [w[0].upper() + w[1:]];
            }
        }
        return " ".join(words);
    }

    def:pub modelName(mid: str) -> str {
        return prettyModel(mid);
    }

    # Normalize jacBuilder's deployment_status / sandbox_status into the four
    # states jachammer's pills understand.
    def:pub jbStatus(p: any) -> str {
        raw = "";
        if ("sandbox_status" in p) and p["sandbox_status"] {
            raw = str(p["sandbox_status"]).lower();
        } elif ("deployment_status" in p) and p["deployment_status"] {
            raw = str(p["deployment_status"]).lower();
        }
        if raw == "" {
            return "stopped";
        }
        if ("run" in raw)
        or ("active" in raw)
        or ("ready" in raw)
        or ("healthy" in raw) {
            return "running";
        }
        if ("build" in raw)
        or ("deploy" in raw)
        or ("pend" in raw)
        or ("progress" in raw)
        or ("provision" in raw) {
            return "building";
        }
        if ("fail" in raw) or ("error" in raw) or ("crash" in raw) {
            return "failed";
        }
        return "stopped";
    }

    # Map a jacBuilder project (_project_to_dict) into a jachammer card dict.
    def:pub jbProj(p: any) -> dict {
        url = p["sandbox_url"]
            if ("sandbox_url" in p and p["sandbox_url"])
            else (
                p["deployment_url"]
                    if ("deployment_url" in p and p["deployment_url"])
                    else "jacbuilder.app"
            );
        status = jbStatus(p);
        return {
            "id": p["id"],
            "name": p["name"] if "name" in p else "project",
            "template": p["template_id"] if "template_id" in p else "app",
            "branch": p["active_branch"]
                if ("active_branch" in p and p["active_branch"])
                else "main",
            "status": status,
            "progress": 100 if status == "running" else 0,
            "region": p["deployment_subdomain"]
                if ("deployment_subdomain" in p and p["deployment_subdomain"])
                else "cloud",
            "url": url,
            "files": [],
            "services": [],
            "logs": [],
            "spec": {},
            "code": "",
            "updated": p["updated_at"]
                if ("updated_at" in p and p["updated_at"])
                else "synced"
        };
    }

    # Map a jacBuilder community template into a jachammer gallery-card dict.
    def:pub jbComm(c: any) -> dict {
        return {
            "id": c["comm_id"] if "comm_id" in c else (c["id"] if "id" in c else ""),
            "name": c["name"] if "name" in c else "project",
            "author": c["author"] if "author" in c else "someone",
            "stars": c["clones"]
                if "clones" in c
                else (c["forks"] if "forks" in c else 0),
            "template": c["template"] if "template" in c else "app",
            "desc": c["description"] if "description" in c else ""
        };
    }

    # Map one ai_chat history entry into a chat-bubble dict.
    def:pub jbMsg(m: any, i: int) -> dict {
        role = "ai" if (("role" in m) and m["role"] == "assistant") else "user";
        txt = m["content"] if "content" in m else (m["text"] if "text" in m else "");
        return {"id": f"m{i}", "role": role, "text": txt, "steps": [], "done": True};
    }
}
