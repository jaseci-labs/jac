"""Git state management hook — branch, status, commit, push, pull."""

import from react { useState, useRef, useEffect, useCallback }
import from ..services.ideService {
    gitStatus, gitBranches, gitCheckout, gitCreateBranch,
    gitDiff, gitDiffWorking, gitDiffStaged, gitDiffLastCommit, gitCommit, gitPush, gitPull,
    gitLog, gitRemoteAdd, gitRemotes, gitRemoteRemove, gitMerge,
    gitCheckpointCreate, gitCheckpointRestore, gitCheckpointDiff,
    gitStageFile, gitUnstageFile, gitCommitStaged, gitDeleteBranch,
    gitShowFile, gitReadWorkingFile,
    githubOps
}

"""Hook for git operations: status, branches, commit, push/pull."""
def:pub useGit(projectId: str, worktreePath: str = "") -> Any {
    has status: Any = None;
    has branches: list = [];
    has currentBranch: str = "";
    has commits: list = [];
    has remoteList: list = [];
    has isLoading: bool = False;
    has gitError: str = "";
    has lastRefresh: int = 0;
    has githubConnected: bool = False;
    has githubUsername: str = "";
    has githubLoading: bool = False;

    refreshTimerRef = useRef(None);

    useEffect(lambda -> Any {
        if projectId {
            refresh();
            loadGithubStatus();
        }
        return lambda -> None {
            if refreshTimerRef.current {
                clearTimeout(refreshTimerRef.current);
            }
        };
    }, [projectId, worktreePath]);

    async def refresh() -> None {
        if not projectId { return; }
        isLoading = True;
        gitError = "";

        try {
            statusResult = await gitStatus(projectId, worktreePath);
            branchResult = await gitBranches(projectId, worktreePath);

            if statusResult and statusResult.success {
                status = statusResult;
                currentBranch = statusResult.branch or "";
            }

            if branchResult and branchResult.success {
                branches = branchResult.branches or [];
                if branchResult.current {
                    currentBranch = branchResult.current;
                }
            }

            lastRefresh = Date.now();
        } except Exception as e {
            gitError = String(e);
        }

        isLoading = False;
    }

    async def switchBranch(branch: str) -> Any {
        if not projectId or not branch { return {"success": False}; }
        isLoading = True;
        result = await gitCheckout(projectId, branch, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def createBranch(name: str) -> Any {
        if not projectId or not name { return {"success": False}; }
        isLoading = True;
        result = await gitCreateBranch(projectId, name, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def doCommit(message: str) -> Any {
        if not projectId or not message { return {"success": False}; }
        isLoading = True;
        result = await gitCommit(projectId, message, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def doPush() -> Any {
        if not projectId { return {"success": False}; }
        isLoading = True;
        result = await gitPush(projectId, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def doPull() -> Any {
        if not projectId { return {"success": False}; }
        isLoading = True;
        result = await gitPull(projectId, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def fetchLog(limit: int = 20) -> None {
        if not projectId { return; }
        result = await gitLog(projectId, limit, worktreePath);
        if result and result.success {
            commits = result.commits or [];
        }
    }

    async def fetchRemotes() -> None {
        if not projectId { return; }
        result = await gitRemotes(projectId, worktreePath);
        if result and result.success {
            remoteList = result.remotes or [];
        }
    }

    async def addRemote(url: str) -> Any {
        if not projectId or not url { return {"success": False}; }
        result = await gitRemoteAdd(projectId, url, worktreePath);
        await fetchRemotes();
        return result;
    }

    async def removeRemote(name: str) -> Any {
        if not projectId or not name { return {"success": False}; }
        isLoading = True;
        result = await gitRemoteRemove(projectId, name, worktreePath);
        await fetchRemotes();
        isLoading = False;
        return result;
    }

    async def getDiff(fromRef: str = "", toRef: str = "") -> Any {
        if not projectId { return {"success": False}; }
        return await gitDiff(projectId, fromRef, toRef, worktreePath);
    }

    async def getWorkingDiff() -> Any {
        if not projectId { return {"success": False}; }
        return await gitDiffWorking(projectId, worktreePath);
    }

    async def getStagedDiff() -> Any {
        if not projectId { return {"success": False}; }
        return await gitDiffStaged(projectId, worktreePath);
    }

    async def getLastCommitDiff() -> Any {
        if not projectId { return {"success": False}; }
        return await gitDiffLastCommit(projectId, worktreePath);
    }

    async def mergeBranch(branchName: str) -> Any {
        if not projectId or not branchName { return {"success": False}; }
        isLoading = True;
        result = await gitMerge(projectId, branchName);
        await refresh();
        isLoading = False;
        return result;
    }

    async def stageFile(filePath: str) -> Any {
        if not projectId or not filePath { return {"success": False}; }
        result = await gitStageFile(projectId, filePath, worktreePath);
        await refresh();
        return result;
    }

    async def unstageFile(filePath: str) -> Any {
        if not projectId or not filePath { return {"success": False}; }
        result = await gitUnstageFile(projectId, filePath, worktreePath);
        await refresh();
        return result;
    }

    async def doCommitStaged(message: str) -> Any {
        if not projectId or not message { return {"success": False}; }
        isLoading = True;
        result = await gitCommitStaged(projectId, message, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def deleteBranch(branchName: str) -> Any {
        if not projectId or not branchName { return {"success": False}; }
        isLoading = True;
        result = await gitDeleteBranch(projectId, branchName, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def createCheckpoint() -> Any {
        if not projectId { return {"success": False}; }
        result = await gitCheckpointCreate(projectId, worktreePath);
        await refresh();
        return result;
    }

    async def restoreCheckpoint(ref: str) -> Any {
        if not projectId or not ref { return {"success": False}; }
        isLoading = True;
        result = await gitCheckpointRestore(projectId, ref, worktreePath);
        await refresh();
        isLoading = False;
        return result;
    }

    async def getCheckpointDiff(ref: str) -> Any {
        if not projectId { return {"success": False}; }
        return await gitCheckpointDiff(projectId, ref, worktreePath);
    }

    async def showFile(ref: str, filePath: str) -> Any {
        if not projectId or not ref or not filePath { return {"success": False, "content": ""}; }
        return await gitShowFile(projectId, ref, filePath, worktreePath);
    }

    async def readWorkingFile(filePath: str) -> Any {
        if not projectId or not filePath { return {"success": False, "content": ""}; }
        return await gitReadWorkingFile(projectId, filePath, worktreePath);
    }

    async def loadGithubStatus() -> None {
        result = await githubOps("status", {});
        if result and result.success {
            githubConnected = result.github_connected or False;
            githubUsername = result.github_username or "";
        }
    }

    async def connectGithub() -> None {
        githubLoading = True;
        result = await githubOps("connect", {});
        githubLoading = False;
        if result and result.success {
            url = result.authorize_url or "";
            if url { window.location.href = url; }
        }
    }

    async def disconnectGithub() -> None {
        githubLoading = True;
        result = await githubOps("disconnect", {});
        githubLoading = False;
        if result and result.success {
            githubConnected = False;
            githubUsername = "";
        }
    }

    async def githubPushProject() -> Any {
        githubLoading = True;
        result = await githubOps("push", {"project_id": projectId});
        githubLoading = False;
        return result;
    }

    async def githubPullProject() -> Any {
        githubLoading = True;
        result = await githubOps("pull", {"project_id": projectId});
        githubLoading = False;
        if result and result.success { await refresh(); }
        return result;
    }

    async def githubPushNew(repoName: str = "", repoPrivate: bool = True) -> Any {
        githubLoading = True;
        result = await githubOps("push_new", {
            "project_id": projectId,
            "repo_name": repoName,
            "repo_private": repoPrivate
        });
        githubLoading = False;
        if result and result.success {
            await refresh();
            await fetchRemotes();
        }
        return result;
    }

    async def githubCreatePR(title: str, head: str, base: str, body: str) -> Any {
        githubLoading = True;
        result = await githubOps("create_pr", {
            "project_id": projectId,
            "pr_title": title,
            "pr_head": head,
            "pr_base": base,
            "pr_body": body
        });
        githubLoading = False;
        return result;
    }

    return {
        "status": status,
        "branches": branches,
        "currentBranch": currentBranch,
        "commits": commits,
        "remoteList": remoteList,
        "isLoading": isLoading,
        "gitError": gitError,
        "lastRefresh": lastRefresh,
        "refresh": refresh,
        "switchBranch": switchBranch,
        "createBranch": createBranch,
        "doCommit": doCommit,
        "doCommitStaged": doCommitStaged,
        "doPush": doPush,
        "doPull": doPull,
        "fetchLog": fetchLog,
        "fetchRemotes": fetchRemotes,
        "addRemote": addRemote,
        "removeRemote": removeRemote,
        "getDiff": getDiff,
        "getWorkingDiff": getWorkingDiff,
        "getStagedDiff": getStagedDiff,
        "getLastCommitDiff": getLastCommitDiff,
        "mergeBranch": mergeBranch,
        "stageFile": stageFile,
        "unstageFile": unstageFile,
        "deleteBranch": deleteBranch,
        "createCheckpoint": createCheckpoint,
        "restoreCheckpoint": restoreCheckpoint,
        "getCheckpointDiff": getCheckpointDiff,
        "showFile": showFile,
        "readWorkingFile": readWorkingFile,
        "githubConnected": githubConnected,
        "githubUsername": githubUsername,
        "githubLoading": githubLoading,
        "loadGithubStatus": loadGithubStatus,
        "connectGithub": connectGithub,
        "disconnectGithub": disconnectGithub,
        "githubPushProject": githubPushProject,
        "githubPullProject": githubPullProject,
        "githubPushNew": githubPushNew,
        "githubCreatePR": githubCreatePR
    };
}
