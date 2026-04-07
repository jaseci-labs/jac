"""Community gallery state hook — browse, clone, and manage community submissions."""
import from react { useState, useEffect, useRef, useCallback }
import from "@jac/runtime" { useNavigate }
import from ..services.ideService { communityList, communityClone, communityRemove }
import from ..utils.toast { notify }

"""Hook for community gallery state and actions."""
def:pub useCommunity() -> Any {
    has items: list = [];
    has isLoading: bool = False;
    has searchQuery: str = "";
    has selectedTag: str = "";
    has cloneModalOpen: bool = False;
    has cloneTarget: Any = None;
    has cloneName: str = "";
    has isCloning: bool = False;
    has cloneError: str = "";
    has itemCount: int = 0;
    has removeConfirmId: str = "";

    navigate = useNavigate();
    debounceRef = useRef(None);

    async def loadCommunity() -> None {
        isLoading = True;
        result = await communityList(searchQuery, selectedTag);
        if result and result.success {
            loaded = result.items or [];
            items = loaded;
            itemCount = loaded.length;
        } else {
            items = [];
            itemCount = 0;
        }
        isLoading = False;
    }

    useEffect(lambda {
        if debounceRef.current {
            clearTimeout(debounceRef.current);
        }
        debounceRef.current = setTimeout(lambda { loadCommunity(); }, 350);
        return lambda {
            if debounceRef.current { clearTimeout(debounceRef.current); }
        };
    }, [searchQuery, selectedTag]);

    def openCloneModal(item: Any) -> None {
        cloneTarget = item;
        cloneName = item.name or "";
        cloneError = "";
        cloneModalOpen = True;
    }

    def closeCloneModal() -> None {
        cloneModalOpen = False;
        cloneTarget = None;
        cloneName = "";
        cloneError = "";
    }

    async def doClone() -> None {
        if not cloneTarget { return; }
        safeName = (cloneName or cloneTarget.name).replace("/", "-").replace("\\", "-").replace("..", "-").replace("\0", "").trim();
        if not safeName {
            cloneError = "Please enter a valid project name";
            return;
        }
        isCloning = True;
        cloneError = "";
        result = await communityClone(cloneTarget.id, safeName);
        if result and result.success and result.project {
            cloneModalOpen = False;
            cloneTarget = None;
            cloneName = "";
            navigate("/project/" + result.project.id);
        } else {
            cloneError = (result.error if result and result.error else "Clone failed");
        }
        isCloning = False;
    }

    def confirmRemove(commId: str) -> None {
        removeConfirmId = commId;
    }

    def cancelRemove() -> None {
        removeConfirmId = "";
    }

    async def doRemove() -> None {
        commId = removeConfirmId;
        if not commId { return; }
        removeConfirmId = "";
        result = await communityRemove(commId);
        if result and result.success {
            notify("Removed", "Project removed from community", "success");
            loadCommunity();
        } else {
            notify("Error", (result.error if result and result.error else "Failed to remove"), "error");
        }
    }

    return {
        "items": items,
        "isLoading": isLoading,
        "itemCount": itemCount,
        "searchQuery": searchQuery,
        "setSearchQuery": lambda v: str { searchQuery = v; },
        "selectedTag": selectedTag,
        "setSelectedTag": lambda v: str { selectedTag = v; },
        "cloneModalOpen": cloneModalOpen,
        "cloneTarget": cloneTarget,
        "cloneName": cloneName,
        "setCloneName": lambda v: str { cloneName = v; },
        "isCloning": isCloning,
        "cloneError": cloneError,
        "openCloneModal": openCloneModal,
        "closeCloneModal": closeCloneModal,
        "doClone": doClone,
        "removeConfirmId": removeConfirmId,
        "confirmRemove": confirmRemove,
        "cancelRemove": cancelRemove,
        "doRemove": doRemove,
        "refresh": loadCommunity
    };
}
