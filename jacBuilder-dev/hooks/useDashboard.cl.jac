"""Dashboard state hook — user info, project list, create project, import jacpack."""
import from react { useState, useEffect }
import from "@jac/runtime" { useNavigate }
import from ..services.ideService {
    ideListProjects,
    ideCreateProject,
    ideImportProject,
    ideDeleteProject,
    ideRenameProject,
    ideGetMe,
    ideListTemplates,
    ideListVersions,
    ideExportVersionDownload,
    communitySubmit,
    ideGetProjectThumbnail,
    ideBatchWrite,
    githubOps
}
import from ..utils.toast { notify }

"""Hook for dashboard: user info, projects, create/delete/import actions."""
def:pub useDashboard(onShareSuccess: Any = None) -> Any {
    has user: Any = None;
    has projects: list = [];
    has templates: list = [];
    has isLoading: bool = True;
    has createModalOpen: bool = False;
    has createMode: str = "template";
    has newProjectName: str = "";
    has selectedTemplate: str = "";
    has createError: str = "";
    has isCreating: bool = False;
    has jacpackUrl: str = "";
    has jacpackFile: Any = None;
    has shareModalOpen: bool = False;
    has shareTarget: Any = None;
    has shareName: str = "";
    has shareDescription: str = "";
    has shareTags: str = "";
    has shareAgreed: bool = False;
    has isSharing: bool = False;
    has shareError: str = "";
    has shareSuccess: bool = False;
    has thumbnails: Any = {};
    has renameModalOpen: bool = False;
    has renameTarget: Any = None;
    has renameName: str = "";
    has isRenaming: bool = False;
    has renameError: str = "";
    has deleteConfirmOpen: bool = False;
    has deleteConfirmTarget: Any = None;
    has isDeleting: bool = False;
    has folderFiles: list = [];
    has folderName: str = "";

    navigate = useNavigate();

    async def loadData() -> None {
        isLoading = True;
        meResult = await ideGetMe();
        if meResult and meResult.success {
            user = meResult.user;
        }
        projectsList = [];
        projectsResult = await ideListProjects();
        if projectsResult and projectsResult.success {
            projectsList = projectsResult.projects or [];
            projects = projectsList;
        }
        templatesResult = await ideListTemplates();
        if templatesResult and templatesResult.success {
            templates = templatesResult.templates or [];
        }
        isLoading = False;
        loadThumbnails(projectsList);
    }

    async def loadThumbnails(projectList: list) -> None {
        for p in projectList {
            if p.has_thumbnail {
                result = await ideGetProjectThumbnail(p.id);
                if result and result.success and result.image {
                    dataUri = "data:" + (result.mime_type or "image/jpeg") + ";base64," + result.image;
                    thumbnails = lambda prev: Any -> Any {
                        updated = Object.assign({}, prev);
                        updated[p.id] = dataUri;
                        return updated;
                    };
                }
            }
        }
    }

    useEffect(lambda {
        loadData();
    }, []);

    async def quickCreate(prompt: str) -> None {
        projectName = prompt.trim().slice(0, 40) or "My Project";
        isCreating = True;
        result = await ideCreateProject(projectName, "client");
        if result and result.success and result.project {
            navigate("/project/" + result.project.id + "?prompt=" + encodeURIComponent(prompt.trim()));
        }
        isCreating = False;
    }

    async def createProject(name: str, templateId: str) -> None {
        if not name.trim() or not templateId {
            createError = "Name and template are required";
            return;
        }
        isCreating = True;
        createError = "";
        result = await ideCreateProject(name.trim(), templateId);
        if result and result.success and result.project {
            createModalOpen = False;
            newProjectName = "";
            selectedTemplate = "";
            navigate("/project/" + result.project.id);
        } else {
            createError = (result.error if result and result.error else "Failed to create project");
        }
        isCreating = False;
    }

    async def importProject(name: str, url: str, file: Any) -> None {
        if not name.trim() {
            createError = "Project name is required";
            return;
        }
        if not url and not file {
            createError = "Provide a JacPack URL or upload a file";
            return;
        }
        isCreating = True;
        createError = "";
        base64Content = "";
        if file {
            try {
                arrayBuffer = await file.arrayBuffer();
                uint8 = Reflect.construct(Uint8Array, [arrayBuffer]);
                binaryString = Array.from(uint8).map(lambda b: Any -> Any { return String.fromCharCode(b); }).join("");
                base64Content = btoa(binaryString);
            } except Exception as e {
                createError = "Failed to read file: " + String(e);
                isCreating = False;
                return;
            }
        }
        result = await ideImportProject(name.trim(), url.trim(), base64Content);
        if result and result.success and result.project {
            createModalOpen = False;
            newProjectName = "";
            jacpackUrl = "";
            jacpackFile = None;
            navigate("/project/" + result.project.id);
        } else {
            createError = (result.error if result and result.error else "Failed to import project");
        }
        isCreating = False;
    }

    def openShareModal(project: Any) -> None {
        shareTarget = project;
        shareName = project.name or "";
        shareDescription = "";
        shareTags = "";
        shareAgreed = False;
        shareError = "";
        shareSuccess = False;
        shareModalOpen = True;
    }

    def closeShareModal() -> None {
        shareModalOpen = False;
        shareTarget = None;
        shareError = "";
        shareSuccess = False;
    }

    async def shareProject(projectId: str, name: str, description: str, tagsStr: str) -> None {
        if not name.trim() {
            shareError = "Name is required";
            return;
        }
        isSharing = True;
        shareError = "";
        shareSuccess = False;
        versionsResult = await ideListVersions(projectId);
        versions = (versionsResult.versions if versionsResult and versionsResult.success else []);
        versionId = "";
        if versions and versions.length > 0 {
            versionId = versions[0].id or "";
        }
        if not versionId {
            shareError = "No saved versions found. Save your project before sharing.";
            isSharing = False;
            return;
        }
        exportResult = await ideExportVersionDownload(projectId, versionId);
        if not exportResult or not exportResult.success {
            shareError = (exportResult.error if exportResult and exportResult.error else "Failed to export project");
            isSharing = False;
            return;
        }
        tags: list = [];
        if tagsStr.trim() {
            rawTags = tagsStr.split(",");
            for rawTag in rawTags {
                t = rawTag.trim();
                if t { tags.push(t); }
            }
        }
        result = await communitySubmit(name.trim(), description.trim(), tags, exportResult.content_base64 or "");
        if result and result.success {
            shareSuccess = True;
            shareModalOpen = False;
            notify("Shared", "Project shared to community", "success");
            if onShareSuccess { refreshFn = onShareSuccess; refreshFn.call(None); }
        } else {
            shareError = (result.error if result and result.error else "Failed to share project");
        }
        isSharing = False;
    }

    def openRenameModal(project: Any) -> None {
        renameTarget = project;
        renameName = project.name or "";
        renameError = "";
        renameModalOpen = True;
    }

    def closeRenameModal() -> None {
        renameModalOpen = False;
        renameTarget = None;
        renameError = "";
    }

    async def renameProject(projectId: str, newName: str) -> None {
        if not newName.trim() {
            renameError = "Name is required";
            return;
        }
        isRenaming = True;
        renameError = "";
        result = await ideRenameProject(projectId, newName.trim());
        if result and result.success {
            renameModalOpen = False;
            renameTarget = None;
            projectsResult = await ideListProjects();
            if projectsResult and projectsResult.success {
                projects = projectsResult.projects or [];
            }
        } else {
            renameError = (result.error if result and result.error else "Failed to rename project");
        }
        isRenaming = False;
    }

    def openDeleteConfirm(project: Any) -> None {
        deleteConfirmTarget = project;
        deleteConfirmOpen = True;
    }

    def closeDeleteConfirm() -> None {
        deleteConfirmOpen = False;
        deleteConfirmTarget = None;
    }

    async def createFromFolder(name: str, files: list) -> None {
        if not name.trim() {
            createError = "Project name is required";
            return;
        }
        if not files or files.length == 0 {
            createError = "No files to upload";
            return;
        }
        isCreating = True;
        createError = "";
        result = await ideCreateProject(name.trim(), "empty");
        if not result or not result.success or not result.project {
            createError = (result.error if result and result.error else "Failed to create project");
            isCreating = False;
            return;
        }
        projectId = result.project.id;
        batchResult = await ideBatchWrite(projectId, files);
        if not batchResult or not batchResult.success {
            createError = "Project created but file upload failed: " + (batchResult.error if batchResult and batchResult.error else "unknown error");
            isCreating = False;
            navigate("/project/" + projectId);
            return;
        }
        createModalOpen = False;
        newProjectName = "";
        folderFiles = [];
        folderName = "";
        isCreating = False;
        navigate("/project/" + projectId);
    }

    async def confirmDelete() -> None {
        if not deleteConfirmTarget { return; }
        pId = deleteConfirmTarget.id;
        deleteConfirmOpen = False;
        deleteConfirmTarget = None;
        await deleteProject(pId);
    }

    async def deleteProject(projectId: str) -> None {
        isDeleting = True;
        result = await ideDeleteProject(projectId);
        if result and result.success {
            # Remove deleted project from local state immediately
            projects = projects.filter(lambda p: Any -> Any { return p.id != projectId; });
            # Remove thumbnail for deleted project
            thumbnails = lambda prev: Any -> Any {
                updated = {};
                Object.keys(prev).forEach(lambda(k: Any) -> None {
                    if k != projectId {
                        updated[k] = prev[k];
                    }
                });
                return updated;
            };
            notify("Deleted", "Project deleted successfully", "success");
        } else {
            notify("Error", (result.error if result else "Failed to delete project"), "destructive");
        }
        isDeleting = False;
    }

    async def importFromGithub(repoName: str, cloneUrl: str) -> Any {
        isCreating = True;
        createError = "";
        result = await githubOps("import_repo", {
            "repo_name": repoName,
            "clone_url": cloneUrl
        });
        isCreating = False;
        if result and result.success {
            createModalOpen = False;
            navigate("/project/" + result.project.id);
        } else {
            createError = (result.error if result else "Import failed");
        }
        return result;
    }

    async def listGithubRepos(page: int = 1) -> Any {
        return await githubOps("list_repos", {"page": page, "per_page": 30});
    }

    async def getGithubStatus() -> Any {
        return await githubOps("status", {});
    }

    return {
        "user": user,
        "projects": projects,
        "templates": templates,
        "isLoading": isLoading,
        "createModalOpen": createModalOpen,
        "setCreateModalOpen": lambda v: bool { createModalOpen = v; },
        "createMode": createMode,
        "setCreateMode": lambda v: str { createMode = v; createError = ""; },
        "newProjectName": newProjectName,
        "setNewProjectName": lambda v: str { newProjectName = v; },
        "selectedTemplate": selectedTemplate,
        "setSelectedTemplate": lambda v: str { selectedTemplate = v; },
        "jacpackUrl": jacpackUrl,
        "setJacpackUrl": lambda v: str { jacpackUrl = v; },
        "jacpackFile": jacpackFile,
        "setJacpackFile": lambda v: Any { jacpackFile = v; },
        "createError": createError,
        "isCreating": isCreating,
        "quickCreate": quickCreate,
        "createProject": createProject,
        "importProject": importProject,
        "createFromFolder": createFromFolder,
        "folderFiles": folderFiles,
        "setFolderFiles": lambda v: list { folderFiles = v; },
        "folderName": folderName,
        "setFolderName": lambda v: str { folderName = v; },
        "deleteProject": deleteProject,
        "importFromGithub": importFromGithub,
        "listGithubRepos": listGithubRepos,
        "getGithubStatus": getGithubStatus,
        "shareModalOpen": shareModalOpen,
        "shareTarget": shareTarget,
        "shareName": shareName,
        "setShareName": lambda v: str { shareName = v; },
        "shareDescription": shareDescription,
        "setShareDescription": lambda v: str { shareDescription = v; },
        "shareTags": shareTags,
        "setShareTags": lambda v: str { shareTags = v; },
        "shareAgreed": shareAgreed,
        "setShareAgreed": lambda v: bool { shareAgreed = v; },
        "isSharing": isSharing,
        "shareError": shareError,
        "shareSuccess": shareSuccess,
        "openShareModal": openShareModal,
        "closeShareModal": closeShareModal,
        "shareProject": shareProject,
        "thumbnails": thumbnails,
        "renameModalOpen": renameModalOpen,
        "renameTarget": renameTarget,
        "renameName": renameName,
        "setRenameName": lambda v: str { renameName = v; },
        "isRenaming": isRenaming,
        "renameError": renameError,
        "openRenameModal": openRenameModal,
        "closeRenameModal": closeRenameModal,
        "renameProject": renameProject,
        "deleteConfirmOpen": deleteConfirmOpen,
        "deleteConfirmTarget": deleteConfirmTarget,
        "isDeleting": isDeleting,
        "openDeleteConfirm": openDeleteConfirm,
        "closeDeleteConfirm": closeDeleteConfirm,
        "confirmDelete": confirmDelete
    };
}
