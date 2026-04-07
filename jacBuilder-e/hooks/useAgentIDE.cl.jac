"""Lightweight IDE hook for Agent page — project switching, preview, terminal, file viewer."""

import from react { useState, useEffect, useRef }
import from ..services.ideService {
    ideGetMe, ideListProjects, ideOpenProject, ideSetup, ideListFiles, ideReadFile,
    ideListVersions, sendWsRequest, closePreviewWs, idePreviewScreenshot,
    idePreviewStartWithWorktree
}

"""Hook for agent-mode IDE state: multi-project, preview, terminal, read-only file viewer."""
def:pub useAgentIDE() -> Any {
    has userId: str = "";
    has projectId: str = "";
    has project: Any = None;
    has projects: list = [];
    has isLoading: bool = True;
    has fileList: list = [];
    has versions: list = [];
    has terminalContent: str = "";
    has previewUrl: str = "";
    has previewStatus: str = "stopped";
    has previewPort: int = 0;
    has previewRefreshKey: int = 0;
    has previewWorktreePath: str = "";
    has viewerFile: Any = None;

    logOffsetRef = useRef(0);
    previewStatusRef = useRef("stopped");
    idleCountRef = useRef(0);

    useEffect(lambda {
        previewStatusRef.current = previewStatus;
    }, [previewStatus]);

    useEffect(lambda {
        _init();
        return lambda -> None {
            previewStatusRef.current = "stopped";
            closePreviewWs();
        };
    }, []);

    async def _init() -> None {
        isLoading = True;
        meResult = await ideGetMe();
        if meResult and meResult.success and meResult.user {
            userId = meResult.user.user_id or "";
        }
        projResult = await ideListProjects();
        if projResult and projResult.success {
            projects = projResult.projects or [];

            # Restore last selected project from localStorage
            savedPid = localStorage.getItem("jac_agent_project") or "";
            if savedPid {
                found = False;
                for p in projResult.projects {
                    if p.id == savedPid {
                        found = True;
                        break;
                    }
                }
                if found {
                    await switchProject(savedPid);
                }
            }
        }
        isLoading = False;
    }

    async def refreshProjects() -> None {
        projResult = await ideListProjects();
        if projResult and projResult.success {
            projects = projResult.projects or [];
        }
    }

    async def switchProject(pid: str) -> None {
        if not pid or pid == projectId { return; }
        projectId = pid;
        localStorage.setItem("jac_agent_project", pid);
        project = None;
        fileList = [];
        versions = [];
        previewWorktreePath = "";

        openResult = await ideOpenProject(pid);
        if openResult and openResult.success and openResult.project {
            project = openResult.project;
        }

        setupResult = await ideSetup(pid);
        if setupResult and setupResult.success {
            filesResult = await ideListFiles(pid);
            if filesResult and filesResult.success {
                fileList = filesResult.files or [];
            }
        }

        versResult = await ideListVersions(pid);
        if versResult and versResult.success {
            versions = versResult.versions or [];
        }
    }

    async def refreshFiles() -> None {
        if not projectId { return; }
        result = await ideListFiles(projectId);
        if result and result.success {
            fileList = result.files or [];
        }
    }

    async def refreshVersions() -> None {
        if not projectId { return; }
        result = await ideListVersions(projectId);
        if result and result.success {
            versions = result.versions or [];
        }
    }

    async def viewFile(path: str) -> None {
        if not projectId or not path { return; }
        result = await ideReadFile(projectId, path);
        if result and result.success {
            viewerFile = {
                "path": path,
                "content": result.content or "",
                "isBinary": result.is_binary or False,
                "mimeType": result.mime_type or ""
            };
        }
    }

    def closeViewer() -> None {
        viewerFile = None;
    }

    def _startWsPolling(uid: str, pid: str) -> None {
        def pollStatus() -> None {
            if previewStatusRef.current != "starting" { return; }
            sendWsRequest("status", uid, pid, 0, lambda(msg: Any) {
                if not msg or not msg.data { return; }
                data = msg.data;
                if data.status == "running" {
                    previewUrl = data.url or "";
                    previewPort = data.port or 0;
                    previewStatus = "running";
                    previewStatusRef.current = "running";
                    capturePid = pid;
                    setTimeout(lambda {
                        idePreviewScreenshot(capturePid);
                    }, 8000);
                } elif data.status == "error" or data.status == "stopped" {
                    previewStatus = data.status;
                    previewStatusRef.current = data.status;
                }
            });
            setTimeout(lambda {
                if previewStatusRef.current == "starting" {
                    pollStatus();
                }
            }, 2000);
        }

        def pollLog() -> None {
            status = previewStatusRef.current;
            if status != "starting" and status != "running" { return; }
            sendWsRequest("log", uid, pid, logOffsetRef.current, lambda(msg: Any) {
                if not msg or not msg.data { return; }
                data = msg.data;
                if data.success and data.content {
                    terminalContent = lambda prev: Any -> Any { return prev + data.content; };
                    logOffsetRef.current = data.offset or logOffsetRef.current;
                    idleCountRef.current = 0;
                } else {
                    idleCountRef.current = idleCountRef.current + 1;
                }
            });
            setTimeout(lambda {
                s = previewStatusRef.current;
                if s != "starting" and s != "running" { return; }
                pollLog();
            }, (1500 if previewStatusRef.current == "starting" else (Math.min(1500 + idleCountRef.current * 500, 10000) if idleCountRef.current > 5 else 2000)));
        }

        idleCountRef.current = 0;
        setTimeout(pollStatus, 1000);
        setTimeout(pollLog, 1000);
    }

    def startPreview(worktreePath: str = "") -> None {
        if not projectId { return; }
        terminalContent = "";
        logOffsetRef.current = 0;
        previewStatus = "starting";
        previewStatusRef.current = "starting";
        previewWorktreePath = worktreePath;

        if worktreePath {
            idePreviewStartWithWorktree(projectId, worktreePath).then(lambda(res: Any) {
                if res and res.success {
                    previewUrl = res.url or "";
                    previewPort = res.port or 0;
                }
            });
        } else {
            sendWsRequest("start", userId, projectId, 0, lambda(msg: Any) {
                if msg and msg.data and msg.data.success {
                    previewUrl = msg.data.url or "";
                    previewPort = msg.data.port or 0;
                }
            });
        }
        _startWsPolling(userId, projectId);
    }

    def stopPreview() -> None {
        if not projectId { return; }
        previewStatus = "stopped";
        previewStatusRef.current = "stopped";
        previewUrl = "";
        previewPort = 0;
        previewWorktreePath = "";
        sendWsRequest("stop", userId, projectId, 0, lambda(_: Any) {});
    }

    # Stub functions that useClaudeChat calls on `ide`
    def openFile(path: str) -> None {}
    def closeTab(path: str) -> None {}
    has activeTab: str = "";

    return {
        "userId": userId,
        "projectId": projectId,
        "project": project,
        "projects": projects,
        "isLoading": isLoading,
        "files": fileList,
        "versions": versions,
        "terminalContent": terminalContent,
        "previewUrl": previewUrl,
        "previewStatus": previewStatus,
        "previewPort": previewPort,
        "previewRefreshKey": previewRefreshKey,
        "previewWorktreePath": previewWorktreePath,
        "viewerFile": viewerFile,
        "activeTab": activeTab,
        "switchProject": switchProject,
        "refreshProjects": refreshProjects,
        "refreshFiles": refreshFiles,
        "refreshVersions": refreshVersions,
        "viewFile": viewFile,
        "closeViewer": closeViewer,
        "startPreview": startPreview,
        "stopPreview": stopPreview,
        "refreshPreview": lambda -> None { previewRefreshKey = previewRefreshKey + 1; },
        "openFile": openFile,
        "closeTab": closeTab
    };
}
