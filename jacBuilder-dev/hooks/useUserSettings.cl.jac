"""Hook for managing user-level global environment variables."""

import from ..services.ideService { ideUserEnvOps }

def:pub useUserSettings() -> Any {
    has globalVars: list = [];
    has globalVarsLoading: bool = False;
    has globalVarsSaving: bool = False;
    has globalVarsError: str = "";
    has settingsOpen: bool = False;

    async def loadGlobalVars() -> None {
        globalVarsLoading = True;
        result = await ideUserEnvOps("list_global", []);
        globalVarsLoading = False;
        if result and result.success {
            globalVars = result.env_list or [];
        }
    }

    def updateGlobalVar(keyName: str, newVal: str) -> None {
        globalVars = globalVars.map(lambda (v: Any) -> Any {
            if v.key == keyName {
                return {"key": v.key, "value": newVal};
            }
            return v;
        });
    }

    def deleteGlobalVar(keyName: str) -> None {
        globalVars = globalVars.filter(lambda (v: Any) -> bool { return v.key != keyName; });
    }

    def addGlobalVar(keyName: str, val: str) -> None {
        trimmed = keyName.trim() if keyName else "";
        if not trimmed { return; }
        globalVars = globalVars.concat([{"key": trimmed, "value": val}]);
    }

    async def saveGlobalVars() -> None {
        globalVarsSaving = True;
        result = await ideUserEnvOps("save_global", globalVars);
        globalVarsSaving = False;
        if result and result.success {
            globalVarsError = "";
        } else {
            globalVarsError = (result.error if result and result.error else "Save failed");
        }
    }

    def openSettings() -> None {
        settingsOpen = True;
        loadGlobalVars();
    }

    def closeSettings() -> None {
        settingsOpen = False;
    }

    return {
        "globalVars": globalVars,
        "globalVarsLoading": globalVarsLoading,
        "globalVarsSaving": globalVarsSaving,
        "globalVarsError": globalVarsError,
        "settingsOpen": settingsOpen,
        "openSettings": openSettings,
        "closeSettings": closeSettings,
        "loadGlobalVars": loadGlobalVars,
        "updateGlobalVar": updateGlobalVar,
        "deleteGlobalVar": deleteGlobalVar,
        "addGlobalVar": addGlobalVar,
        "saveGlobalVars": saveGlobalVars
    };
}
