"""Hook for managing project environment variables."""

import from ..services.ideService { ideEnvOps }

def:pub useProjectSettings(projectId: str) -> Any {
    has projectVars: list = [];
    has projectVarsLoading: bool = False;
    has projectVarsSaving: bool = False;
    has projectVarsError: str = "";

    async def loadProjectVars() -> None {
        if not projectId { return; }
        projectVarsLoading = True;
        result = await ideEnvOps(projectId, "list_project", []);
        projectVarsLoading = False;
        if result and result.success {
            projectVars = result.env_list or [];
        }
    }

    def updateProjectVar(keyName: str, newVal: str) -> None {
        projectVars = projectVars.map(lambda (v: Any) -> Any {
            if v.key == keyName {
                return {"key": v.key, "value": newVal};
            }
            return v;
        });
    }

    def deleteProjectVar(keyName: str) -> None {
        projectVars = projectVars.filter(lambda (v: Any) -> bool { return v.key != keyName; });
    }

    def addProjectVar(keyName: str, val: str) -> None {
        trimmed = keyName.trim() if keyName else "";
        if not trimmed { return; }
        projectVars = projectVars.concat([{"key": trimmed, "value": val}]);
    }

    async def saveProjectVars() -> None {
        projectVarsSaving = True;
        result = await ideEnvOps(projectId, "save_project", projectVars);
        projectVarsSaving = False;
        if result and result.success {
            projectVarsError = "";
        } else {
            projectVarsError = (result.error if result and result.error else "Save failed");
        }
    }

    return {
        "projectVars": projectVars,
        "projectVarsLoading": projectVarsLoading,
        "projectVarsSaving": projectVarsSaving,
        "projectVarsError": projectVarsError,
        "loadProjectVars": loadProjectVars,
        "updateProjectVar": updateProjectVar,
        "deleteProjectVar": deleteProjectVar,
        "addProjectVar": addProjectVar,
        "saveProjectVars": saveProjectVars
    };
}
