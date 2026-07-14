"""jachammer ↔ hosted jacBuilder — walker RPC service layer.

One thin `async def:pub` per jacBuilder walker, mirroring jacBuilder's own
`services/ideService.cl.jac`. Each wrapper does a single `root spawn <walker>()`
and returns the walker's **first report dict**, or `{success: False, error}` on a
transport failure — so every caller in the store just checks `d["success"]`.

Walkers resolve by name (the native runtime lowers `root spawn X()` to a
`__jacSpawn("X", …)` call), so nothing is imported here. The JWT and API base
URL are attached automatically by the runtime — see `store.cl.jac`, which pins
`globalThis.__JAC_API_BASE_URL__` to the hosted backend on mount.
"""

cl {
    def _fail(e: any) -> dict {
        return {"success": False, "error": str(e)};
    }

    # ── account / billing ────────────────────────────────────────────────────
    # display_name_hint: on first call the backend stores it as the profile's
    # display name, so later calls (e.g. session restore) return a real name
    # instead of just the user_id UUID.
    async def:pub jbMe(display_name_hint: str) -> dict {
        try {
            res = root spawn me(display_name_hint=display_name_hint);
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Resolve a human display name via jac cloud's /user/me (the `me` walker and
    # the JWT carry only the user_id for SSO logins). Mirrors jacBuilder's
    # fetchUserInfo: profile.sso.<provider>.display_name → profile.display_name →
    # an email/username identity value.
    async def:pub jbUserInfo -> dict {
        try {
            base = globalThis.__jacGetApiBaseUrl__();
            token = globalThis.__jacGetLocalStorage__("jac_token");
            resp = await fetch(
                base + "/user/me",
                {"method": "GET", "headers": {"Authorization": "Bearer " + token}}
            );
            body = await resp.text();
            console.log(
                "[jh] /user/me status=", resp.status, "body=", str(body)[0:300]
            );
            if not resp.ok {
                return {"success": False};
            }
            data: any = JSON.parse(body);
            d: any = data.data;
            name = "";
            pic = "";
            if d {
                profile: any = d.profile;
                if profile {
                    ssoBlock: any = profile.sso;
                    if ssoBlock {
                        for k in Object.keys(ssoBlock) {
                            c: any = ssoBlock[k];
                            if c
                            and (
                                c.display_name
                                or c.first_name
                                or c.last_name
                                or c.picture
                            ) {
                                if c.display_name {
                                    name = str(c.display_name);
                                } elif c.first_name or c.last_name {
                                    name = (
                                        str(c.first_name or "") + " " + str(
                                            c.last_name or ""
                                        )
                                    ).strip();
                                }
                                if c.picture {
                                    pic = str(c.picture);
                                }
                                break;
                            }
                        }
                    }
                    if name == "" and profile.display_name {
                        name = str(profile.display_name);
                    }
                }
                idents: any = d.identities;
                if name == "" and idents {
                    for it in idents {
                        if (it.type == "email") and it.value and (name == "") {
                            name = str(it.value);
                        }
                    }
                    for it in idents {
                        if (it.type == "username") and it.value and (name == "") {
                            name = str(it.value);
                        }
                    }
                }
            }
            return {"success": True, "display_name": name, "picture_url": pic};
        } except Exception as e {
            return {"success": False, "error": str(e)};
        }
    }

    # ── projects ─────────────────────────────────────────────────────────────
    async def:pub jbProjectsList -> dict {
        try {
            res = root spawn project_ops(action="list");
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbProjectCreate(
        name: str, template_id: str, build_prompt: str
    ) -> dict {
        try {
            res = root spawn project_ops(
                action="create",
                name=name,
                template_id=template_id,
                build_prompt=build_prompt
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbProjectRename(project_id: str, name: str) -> dict {
        try {
            res = root spawn project_ops(
                action="rename", project_id=project_id, name=name
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbProjectDelete(project_id: str) -> dict {
        try {
            res = root spawn project_ops(action="delete", project_id=project_id);
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Claim the project session for this client (jacBuilder does this on open).
    # Establishes the session/sandbox ownership the preview + file walkers need.
    async def:pub jbClaimSession(project_id: str, connection_id: str) -> dict {
        try {
            res = root spawn project_ops(
                action="claim_session",
                project_id=project_id,
                connection_id=connection_id
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── templates ────────────────────────────────────────────────────────────
    async def:pub jbTemplatesList -> dict {
        try {
            res = root spawn template_ops(action="list");
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── community ────────────────────────────────────────────────────────────
    async def:pub jbCommunityList(search: str) -> dict {
        try {
            res = root spawn community_ops(
                action="list", search=search, tag="", time_range="all", sort_by="recent"
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbCommunityClone(comm_id: str, project_name: str) -> dict {
        try {
            res = root spawn community_submit(
                action="clone", comm_id=comm_id, project_name=project_name
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbCommunitySubmit(
        name: str, description: str, tags: any, project_id: str
    ) -> dict {
        try {
            res = root spawn community_submit(
                action="submit",
                name=name,
                description=description,
                tags=tags,
                jacpack_content_base64="",
                project_id=project_id
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── AI build chat ────────────────────────────────────────────────────────
    async def:pub jbChatStart(project_id: str, message: str) -> dict {
        try {
            res = root spawn ai_chat(
                project_id=project_id,
                message=message,
                current_file_path="",
                action="start",
                images=[],
                element_context=""
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbChatHistory(project_id: str) -> dict {
        try {
            res = root spawn ai_chat(project_id=project_id, action="load_history");
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Poll the running build turn: reports {processing, done}. This is the
    # reliable "is it finished" signal (load_history persists the assistant
    # message while still processing, so it can't tell us).
    async def:pub jbChatPoll(project_id: str) -> dict {
        try {
            res = root spawn ai_chat(project_id=project_id, action="poll");
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Finalize a build turn: writes the assistant message + clears the
    # processing flag. jacBuilder calls this after it sees the agent_done event.
    async def:pub jbChatPersist(
        project_id: str,
        response_text: str,
        promoted_files: list,
        is_error: bool,
        checkpoint_ref: str
    ) -> dict {
        try {
            res = root spawn ai_chat(
                project_id=project_id,
                action="persist_done",
                response_text=response_text,
                promoted_files=promoted_files,
                is_error=is_error,
                checkpoint_ref=checkpoint_ref,
                activities_log=[]
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbModelSwitch(project_id: str, model: str) -> dict {
        try {
            res = root spawn model_switch(project_id=project_id, model=model);
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── files (project staging dir) ──────────────────────────────────────────
    async def:pub jbFilesList(project_id: str) -> dict {
        try {
            res = root spawn ide_file_ops(action="list", project_id=project_id);
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbFileRead(project_id: str, path: str) -> dict {
        try {
            res = root spawn ide_file_ops(
                action="read", project_id=project_id, path=path
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── preview (sandbox workspace) ──────────────────────────────────────────
    # Spins up the project's live preview workspace. REQUIRED before ai_chat
    # (build turns) and ide_file_ops (file tree) work — both need a preview_dir.
    async def:pub jbPreviewStart(project_id: str) -> dict {
        try {
            res = root spawn preview_control(
                project_id=project_id, action="start", project_type="fullstack"
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbPreviewStatus(project_id: str) -> dict {
        try {
            res = root spawn preview_control(project_id=project_id, action="status");
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Mint a short-lived handoff auth URL for the sandbox preview. A native
    # WebView loads the preview as a TOP-LEVEL navigation, so the iframe-only
    # `/__auth?t=<token>&embed=1` handshake jacBuilder uses for its embedded
    # iframe is rejected (the sandbox proxy's embed check requires
    # `Sec-Fetch-Dest: iframe`/empty, but a WebView sends `document`) and bounces
    # to the builder login page. The handoff path (`/__auth?handoff=<h>`) has no
    # such check — this walker (jacBuilder's `preview_auth_ops`) signs a handoff
    # bound to the sandbox and returns a ready-to-load `auth_url`.
    async def:pub jbPreviewAuth(return_to: str) -> dict {
        try {
            res = root spawn preview_auth_ops(return_to=return_to);
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── deploy ───────────────────────────────────────────────────────────────
    # mode = "sandbox" (7-day shareable sandbox) or "permanent" (production K8s
    # namespace + public URL). jacBuilder's DeployPanel exposes both; jachammer
    # too. Default sandbox.
    async def:pub jbDeploy(project_id: str, mode: str) -> dict {
        try {
            res = root spawn deploy_ops(
                project_id=project_id, action="deploy", deploy_mode=mode
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    async def:pub jbDestroy(project_id: str, mode: str) -> dict {
        try {
            res = root spawn deploy_ops(
                project_id=project_id, action="destroy", deploy_mode=mode
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # Poll this after a deploy: reports[0].deployment.{status,url}. status stays
    # "deploying" until the pod is serving, then flips to "running" — that status
    # call is what promotes it, so the client MUST poll it to get the live URL.
    async def:pub jbDeployStatus(project_id: str, mode: str) -> dict {
        try {
            res = root spawn deploy_ops(
                project_id=project_id, action="status", deploy_mode=mode
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }

    # ── deploy telemetry ─────────────────────────────────────────────────────
    async def:pub jbMonitor(
        project_id: str, action: str, tail_lines: int, range_minutes: int
    ) -> dict {
        try {
            res = root spawn deploy_monitoring(
                project_id=project_id,
                action=action,
                tail_lines=tail_lines,
                range_minutes=range_minutes
            );
            return res.reports[0];
        } except Exception as e {
            return _fail(e);
        }
    }
}
