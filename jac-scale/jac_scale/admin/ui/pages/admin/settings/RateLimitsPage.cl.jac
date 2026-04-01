"""LLM Rate Limits management page for admin dashboard."""

cl {
    import from ....components.common.Card { Card, CardHeader, CardBody, StatsCard }
    import from ....components.common.Button { Button }
    import from ....components.common.Input { Input }
    import from ....components.common.Select { Select }
    import from ....components.common.Badge { Badge }
    import from ....components.common.Modal { Modal, ModalFooter }
    import from ....components.common.Alert { InlineAlert }
    import from ....components.tables.DataTable { DataTable, TableRow, TableCell }
    import from react { useEffect }
    import from ....context.AuthContext { useAuth }
    import from ....context.AlertContext { useAlert }
    import from ....services.llmLimitsService {
        getDefaultLimits,
        setDefaultLimits,
        getAllLimits,
        setUserLimits,
        deleteUserLimits,
        getAllUsage,
        resetUserUsage,
        getProviderKeys,
        setProviderKey,
        deleteProviderKey
    }
    import from ....services.userService { getUsers }

    def:pub RateLimitsPage -> JsxElement {
        # State
        has defaults: dict = {},
            userLimits: list = [],
            usageMap: dict = {},
            userList: list = [],
            loading: bool = True,
            # Default limits form
            defBudget: str = "0",
            defPeriod: str = "monthly",
            defRpm: str = "0",
            defTpm: str = "0",
            defModels: str = "",
            defEnabled: bool = True,
            # Edit modal state
            showEditModal: bool = False,
            editUsername: str = "",
            editBudget: str = "0",
            editPeriod: str = "monthly",
            editRpm: str = "0",
            editTpm: str = "0",
            editModels: str = "",
            editEnabled: bool = True,
            editError: str = "",
            # Add user modal
            showAddModal: bool = False,
            addUsername: str = "",
            addBudget: str = "0",
            addPeriod: str = "monthly",
            addRpm: str = "0",
            addTpm: str = "0",
            addModels: str = "",
            addError: str = "",
            # Per-provider API key state
            providerKeysList: list = [],
            providerKeysData: Any = {},
            selectedProvider: str = "openai",
            customProviderName: str = "",
            newProviderKey: str = "",
            # Per-user usage list
            allUsage: list = [];

        auth = useAuth();
        alert = useAlert();

        # ── Data loading ─────────────────────────────────────────────────
        async def loadData -> None {
            loading = True;
            try {
                # Load defaults
                defResult = await getDefaultLimits(auth["authToken"]);
                if defResult and defResult["ok"] and defResult["data"] {
                    d = defResult["data"];
                    defaults = d;
                    defBudget = str(d["budget_limit"] or 0);
                    defPeriod = str(d["budget_period"] or "monthly");
                    defRpm = str(d["rpm_limit"] or 0);
                    defTpm = str(d["tpm_limit"] or 0);
                    models = d["allowed_models"] or [];
                    defModels = ", ".join(models) if models else "";
                    defEnabled = d["enabled"] if d["enabled"] is not None else True;
                }
                # Load per-user limits
                limitsResult = await getAllLimits(auth["authToken"]);
                if limitsResult and limitsResult["ok"] and limitsResult["data"] {
                    items = limitsResult["data"]["items"];
                    userLimits = Array.from(items) if items else [];
                }
                # Load usage data
                usageResult = await getAllUsage(auth["authToken"]);
                if usageResult and usageResult["ok"] and usageResult["data"] {
                    uItems = usageResult["data"]["items"];
                    usageList = Array.from(uItems) if uItems else [];
                    allUsage = usageList;
                    # Also build lookup map for per-user limits table
                    uMap: dict = {};
                    for item in usageList {
                        uMap[item["username"]] = item;
                    }
                    usageMap = uMap;
                }
                # Load user list for add dropdown
                usersResult = await getUsers(auth["authToken"]);
                if usersResult and usersResult["ok"] and usersResult["data"] {
                    users = usersResult["data"]["users"];
                    userList = Array.from(users) if users else [];
                }
                # Load per-provider API keys
                keysResult = await getProviderKeys(auth["authToken"]);
                if keysResult and keysResult["ok"] and keysResult["data"] {
                    providerKeysData = keysResult["data"];
                    providerKeysList = Array.from(Object.keys(keysResult["data"]));
                }
            } except Exception as e {
                console.error("loadData error:", e);
            }
            loading = False;
        }

        useEffect(lambda -> None { loadData();}, []);

        # ── Default limits save ──────────────────────────────────────────
        async def handleSaveDefaults -> None {
            models_list = [
                m.strip()
                for m in defModels.split(",")
                if m.strip()
            ]
                if defModels.strip()
                else [];
            result = await setDefaultLimits(
                auth["authToken"],
                {
                    "budget_limit": parseFloat(defBudget) or 0,
                    "budget_period": defPeriod,
                    "rpm_limit": parseInt(defRpm) or 0,
                    "tpm_limit": parseInt(defTpm) or 0,
                    "allowed_models": models_list,
                    "enabled": defEnabled
                }
            );
            if result and result["ok"] {
                alert["showAlert"]("Default limits saved", "success");
            } else {
                alert["showAlert"]("Failed to save defaults", "error");
            }
        }

        # ── Edit user modal handlers ─────────────────────────────────────
        def openEditModal(user: dict) -> None {
            editUsername = user["username"] or "";
            editBudget = str(user["budget_limit"] or 0);
            editPeriod = str(user["budget_period"] or "monthly");
            editRpm = str(user["rpm_limit"] or 0);
            editTpm = str(user["tpm_limit"] or 0);
            models = user["allowed_models"] or [];
            editModels = ", ".join(models) if models else "";
            editEnabled = user["enabled"] if user["enabled"] is not None else True;
            editError = "";
            showEditModal = True;
        }

        async def handleSaveUser -> None {
            models_list = [
                m.strip()
                for m in editModels.split(",")
                if m.strip()
            ]
                if editModels.strip()
                else [];
            result = await setUserLimits(
                auth["authToken"],
                editUsername,
                {
                    "budget_limit": parseFloat(editBudget) or 0,
                    "budget_period": editPeriod,
                    "rpm_limit": parseInt(editRpm) or 0,
                    "tpm_limit": parseInt(editTpm) or 0,
                    "allowed_models": models_list,
                    "enabled": editEnabled
                }
            );
            if result and result["ok"] {
                alert["showAlert"](f"Limits updated for {editUsername}", "success");
                showEditModal = False;
                await loadData();
            } else {
                editError = "Failed to save limits";
            }
        }

        async def handleDeleteUser(username: str) -> None {
            result = await deleteUserLimits(auth["authToken"], username);
            if result and result["ok"] {
                alert["showAlert"](f"Limits removed for {username}", "success");
                await loadData();
            } else {
                alert["showAlert"]("Failed to remove limits", "error");
            }
        }

        async def handleResetUsage(username: str) -> None {
            result = await resetUserUsage(auth["authToken"], username);
            if result and result["ok"] {
                alert["showAlert"](f"Usage reset for {username}", "success");
                await loadData();
            } else {
                alert["showAlert"]("Failed to reset usage", "error");
            }
        }

        # ── Add user modal handlers ──────────────────────────────────────
        async def handleAddUser -> None {
            if not addUsername.strip() {
                addError = "Username is required";
                return;
            }
            models_list = [
                m.strip()
                for m in addModels.split(",")
                if m.strip()
            ]
                if addModels.strip()
                else [];
            result = await setUserLimits(
                auth["authToken"],
                addUsername.strip(),
                {
                    "budget_limit": parseFloat(addBudget) or 0,
                    "budget_period": addPeriod,
                    "rpm_limit": parseInt(addRpm) or 0,
                    "tpm_limit": parseInt(addTpm) or 0,
                    "allowed_models": models_list,
                    "enabled": True
                }
            );
            if result and result["ok"] {
                alert["showAlert"](f"Limits set for {addUsername}", "success");
                showAddModal = False;
                addUsername = "";
                addBudget = "0";
                addPeriod = "monthly";
                addRpm = "0";
                addTpm = "0";
                addModels = "";
                addError = "";
                await loadData();
            } else {
                addError = "Failed to set limits";
            }
        }

        # ── Provider key handlers ────────────────────────────────────────
        async def handleSetProviderKey -> None {
            p = (
                customProviderName.strip().lower()
                    if selectedProvider == "other"
                    else selectedProvider
            );
            k = newProviderKey.strip();
            if not p {
                alert["showAlert"]("Provider name is required", "error");
                return;
            }
            if not k {
                alert["showAlert"]("API key cannot be empty", "error");
                return;
            }
            result = await setProviderKey(auth["authToken"], p, k);
            if result and result["ok"] {
                customProviderName = "";
                newProviderKey = "";
                await loadData();
                alert["showAlert"](f"Key set for {p}", "success");
            } else {
                alert["showAlert"]("Failed to set provider key", "error");
            }
        }

        async def handleDeleteProviderKey(provider: str) -> None {
            result = await deleteProviderKey(auth["authToken"], provider);
            if result and result["ok"] {
                providerKeysList = [
                    p
                    for p in providerKeysList
                    if p != provider
                ];
                await loadData();
                alert["showAlert"](f"Key cleared for {provider}", "success");
            } else {
                alert["showAlert"]("Failed to clear provider key", "error");
            }
        }

        # ── Helpers ──────────────────────────────────────────────────────
        def formatCost(val: Any) -> str {
            if not val {
                return "$0.00";
            }
            return "$" + parseFloat(val).toFixed(2);
        }

        def getUserUsageVal(username: str, field: str) -> Any {
            u = usageMap[username];
            if u {
                return u[field] or 0;
            }
            return 0;
        }

        def formatNumber(val: Any) -> str {
            if not val {
                return "0";
            }
            n = parseInt(val);
            if n >= 1000000 {
                return (n / 1000000).toFixed(1) + "M";
            }
            if n >= 1000 {
                return (n / 1000).toFixed(1) + "K";
            }
            return str(n);
        }

        def formatTokens(tokens: Any) -> str {
            t = parseInt(tokens) or 0;
            if t >= 1000000 {
                return (t / 1000000).toFixed(1) + "M";
            }
            if t >= 1000 {
                return (t / 1000).toFixed(1) + "K";
            }
            return str(t);
        }

        # ── Table columns ───────────────────────────────────────────────
        limitsColumns = [
            {"key": "username", "label": "User"},
            {"key": "budget", "label": "Budget"},
            {"key": "period", "label": "Period"},
            {"key": "rpm", "label": "RPM"},
            {"key": "tpm", "label": "TPM"},
            {"key": "spend", "label": "Spend"},
            {"key": "requests", "label": "Requests"},
            {"key": "status", "label": "Status"},
            {"key": "actions", "label": "Actions", "align": "right"}
        ];

        periodOptions = [
            {"value": "daily", "label": "Daily"},
            {"value": "weekly", "label": "Weekly"},
            {"value": "monthly", "label": "Monthly"}
        ];

        # ── Render ───────────────────────────────────────────────────────
        if loading {
            return
                <div className="p-8 text-center text-slate-500">
                    Loading...
                </div>;
        }

        return
            <div className="space-y-4">
                <Card className="overflow-hidden">
                    <CardHeader title="LLM Provider API Keys"/>
                    <CardBody className="p-4">
                        <p className="text-xs text-slate-500 mb-3">
                            Set API keys per provider at runtime. When set, byllm calls for that provider use this key instead of jac.toml / environment variables.
                        </p>
                        {len(providerKeysList) > 0
                        and <div className="mb-3 space-y-2">
                            {[
                                <div
                                    key={provider}
                                    className="p-3 bg-slate-800 rounded-lg flex items-center justify-between"
                                >
                                    <div>
                                        <span
                                            className="text-xs text-slate-400 capitalize"
                                        >
                                            {provider}:
                                        </span>
                                        <span
                                            className="ml-2 text-sm text-white font-mono"
                                        >
                                            {providerKeysData[provider]["masked_key"]}
                                        </span>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Badge text="Active" variant="success"/>
                                        <Button
                                            variant="danger"
                                            size="sm"
                                            onClick={lambda -> None { handleDeleteProviderKey(
                                                provider
                                            );}}
                                        >
                                            Remove
                                        </Button>
                                    </div>
                                </div> for provider in providerKeysList
                            ]}
                        </div>}
                        {len(providerKeysList) == 0
                        and <div className="mb-3 p-3 bg-slate-800 rounded-lg">
                            <span className="text-xs text-slate-400">
                                No provider keys set — using jac.toml / environment variables
                            </span>
                        </div>}
                        <div className="space-y-2">
                            <div className="flex gap-2 items-end">
                                <div className="w-48">
                                    <Select
                                        label="Provider"
                                        value={selectedProvider}
                                        onChange={lambda e: Any  -> None { selectedProvider = e.target.value;}}
                                        options={[
                                            {
                                                "value": "openai",
                                                "label": "OpenAI (OPENAI_API_KEY)"
                                            },
                                            {
                                                "value": "anthropic",
                                                "label": "Anthropic (ANTHROPIC_API_KEY)"
                                            },
                                            {
                                                "value": "gemini",
                                                "label": "Gemini (GEMINI_API_KEY)"
                                            },
                                            {
                                                "value": "mistral",
                                                "label": "Mistral (MISTRAL_API_KEY)"
                                            },
                                            {
                                                "value": "groq",
                                                "label": "Groq (GROQ_API_KEY)"
                                            },
                                            {
                                                "value": "cohere",
                                                "label": "Cohere (COHERE_API_KEY)"
                                            },
                                            {
                                                "value": "azure",
                                                "label": "Azure OpenAI (AZURE_API_KEY)"
                                            },
                                            {"value": "other", "label": "Other…"}
                                        ]}
                                    />
                                </div>
                                {selectedProvider == "other"
                                and <Input
                                    value={customProviderName}
                                    onChange={lambda e: Any  -> None { customProviderName = e.target.value;}}
                                    placeholder="provider name"
                                />}
                                <div className="flex-1">
                                    <Input
                                        type="password"
                                        label="API Key"
                                        value={newProviderKey}
                                        onChange={lambda e: Any  -> None { newProviderKey = e.target.value;}}
                                        placeholder="sk-..."
                                    />
                                </div>
                                <Button onClick={handleSetProviderKey}>
                                    Set Key
                                </Button>
                            </div>
                        </div>
                    </CardBody>
                </Card>
                <div className="grid grid-cols-4 gap-3">
                    <StatsCard
                        label="Users with Limits"
                        value={str(len(userLimits))}
                        color="blue"
                    />
                    <StatsCard
                        label="Default Budget"
                        value={formatCost(defaults["budget_limit"] or 0)}
                        color="orange"
                    />
                    <StatsCard
                        label="Default RPM"
                        value={formatNumber(defaults["rpm_limit"] or 0)}
                        color="purple"
                    />
                    <StatsCard
                        label="Default TPM"
                        value={formatNumber(defaults["tpm_limit"] or 0)}
                        color="emerald"
                    />
                </div>
                <Card className="overflow-hidden">
                    <CardHeader title="Current Usage by User"/>
                    <CardBody className="p-0">
                        {len(allUsage) == 0
                        and <div className="p-6 text-center text-slate-500 text-sm">
                            No LLM usage recorded yet.
                        </div>}{len(allUsage) > 0
                        and <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead>
                                    <tr
                                        className="text-slate-400 border-b border-slate-700 text-xs uppercase"
                                    >
                                        <th className="text-left py-2 px-4">
                                            User
                                        </th>
                                        <th className="text-right py-2 px-3">
                                            Requests
                                        </th>
                                        <th className="text-right py-2 px-3">
                                            Tokens
                                        </th>
                                        <th className="text-right py-2 px-3">
                                            Cost
                                        </th>
                                        <th className="text-right py-2 px-3">
                                            Period
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {[
                                        <tr
                                            key={u["username"]}
                                            className="border-b border-slate-800 text-slate-300"
                                        >
                                            <td
                                                className="py-2 px-4 font-mono text-teal-300 text-xs"
                                            >
                                                {u["username"]}
                                            </td>
                                            <td className="text-right py-2 px-3">
                                                {formatNumber(u["total_requests"] or 0)}
                                            </td>
                                            <td className="text-right py-2 px-3">
                                                {formatTokens(u["total_tokens"] or 0)}
                                            </td>
                                            <td
                                                className="text-right py-2 px-3 text-amber-400"
                                            >
                                                {formatCost(u["total_cost"] or 0)}
                                            </td>
                                            <td
                                                className="text-right py-2 px-3 text-slate-500 text-xs"
                                            >
                                                {u["period"] or ""}
                                            </td>
                                        </tr> for u in allUsage
                                    ]}
                                </tbody>
                            </table>
                        </div>}
                    </CardBody>
                </Card>
                <Card className="overflow-hidden">
                    <CardHeader
                        title="Default Limits"
                        action={<Button onClick={handleSaveDefaults}>
                            Save Defaults
                        </Button>}
                    />
                    <CardBody className="p-4">
                        <p className="text-xs text-slate-500 mb-3">
                            Applied to all users who do not have specific overrides. Set 0 for unlimited.
                        </p>
                        <div className="grid grid-cols-5 gap-3">
                            <Input
                                label="Budget ($)"
                                type="number"
                                value={defBudget}
                                onChange={lambda e: Any  -> None { defBudget = e.target.value;}}
                                placeholder="0 = unlimited"
                            />
                            <Select
                                label="Period"
                                value={defPeriod}
                                onChange={lambda e: Any  -> None { defPeriod = e.target.value;}}
                                options={periodOptions}
                            />
                            <Input
                                label="Requests/min (RPM)"
                                type="number"
                                value={defRpm}
                                onChange={lambda e: Any  -> None { defRpm = e.target.value;}}
                                placeholder="0 = unlimited"
                            />
                            <Input
                                label="Tokens/min (TPM)"
                                type="number"
                                value={defTpm}
                                onChange={lambda e: Any  -> None { defTpm = e.target.value;}}
                                placeholder="0 = unlimited"
                            />
                            <Input
                                label="Allowed Models"
                                value={defModels}
                                onChange={lambda e: Any  -> None { defModels = e.target.value;}}
                                placeholder="gpt-4o, gpt-4o-mini"
                            />
                        </div>
                    </CardBody>
                </Card>
                <Card className="overflow-hidden">
                    <CardHeader
                        title="Per-User Limits"
                        action={<Button
                            onClick={lambda -> None { showAddModal = True;}}
                        >
                            Add User Override
                        </Button>}
                    />
                    <CardBody className="p-0">
                        {len(userLimits) == 0
                        and <div className="p-8 text-center text-slate-500 text-sm">
                            No user-specific limits configured. All users follow default limits.
                        </div>}{len(userLimits) > 0
                        and <DataTable columns={limitsColumns}>
                            {[
                                <TableRow key={item["username"]}>
                                    <TableCell>
                                        <span className="text-white font-medium">
                                            {item["username"]}
                                        </span>
                                    </TableCell>
                                    <TableCell>
                                        {formatCost(item["budget_limit"] or 0)}
                                    </TableCell>
                                    <TableCell>
                                        {str(item["budget_period"] or "monthly")}
                                    </TableCell>
                                    <TableCell>
                                        {formatNumber(item["rpm_limit"] or 0)}
                                    </TableCell>
                                    <TableCell>
                                        {formatNumber(item["tpm_limit"] or 0)}
                                    </TableCell>
                                    <TableCell>
                                        {formatCost(
                                            getUserUsageVal(
                                                item["username"], "total_cost"
                                            )
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        {formatNumber(
                                            getUserUsageVal(
                                                item["username"], "total_requests"
                                            )
                                        )}
                                    </TableCell>
                                    <TableCell>
                                        {(item["enabled"] is not False)
                                        and <Badge text="Active" variant="success"/>}{(
                                            item["enabled"] is False
                                        )
                                        and <Badge text="Disabled" variant="warning"/>}
                                    </TableCell>
                                    <TableCell align="right">
                                        <div className="flex gap-1 justify-end">
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={lambda -> None { openEditModal(
                                                    item
                                                );}}
                                            >
                                                Edit
                                            </Button>
                                            <Button
                                                variant="ghost"
                                                size="sm"
                                                onClick={lambda -> None { handleResetUsage(
                                                    item["username"]
                                                );}}
                                            >
                                                Reset
                                            </Button>
                                            <Button
                                                variant="danger"
                                                size="sm"
                                                onClick={lambda -> None { handleDeleteUser(
                                                    item["username"]
                                                );}}
                                            >
                                                Remove
                                            </Button>
                                        </div>
                                    </TableCell>
                                </TableRow> for item in userLimits
                            ]}
                        </DataTable>}
                    </CardBody>
                </Card>
                <Modal
                    isOpen={showEditModal}
                    onClose={lambda -> None { showEditModal = False;}}
                    title={"Edit Limits: " + editUsername}
                >
                    <div className="space-y-3">
                        {editError and <InlineAlert message={editError} type="error"/>}
                        <Input
                            label="Monthly Budget ($)"
                            type="number"
                            value={editBudget}
                            onChange={lambda e: Any  -> None { editBudget = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Select
                            label="Period"
                            value={editPeriod}
                            onChange={lambda e: Any  -> None { editPeriod = e.target.value;}}
                            options={periodOptions}
                        />
                        <Input
                            label="Requests/min (RPM)"
                            type="number"
                            value={editRpm}
                            onChange={lambda e: Any  -> None { editRpm = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Input
                            label="Tokens/min (TPM)"
                            type="number"
                            value={editTpm}
                            onChange={lambda e: Any  -> None { editTpm = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Input
                            label="Allowed Models (comma-separated)"
                            value={editModels}
                            onChange={lambda e: Any  -> None { editModels = e.target.value;}}
                            placeholder="gpt-4o, gpt-4o-mini (empty = all)"
                        />
                    </div>
                    <ModalFooter>
                        <Button
                            variant="ghost"
                            onClick={lambda -> None { showEditModal = False;}}
                        >
                            Cancel
                        </Button>
                        <Button onClick={handleSaveUser}>
                            Save
                        </Button>
                    </ModalFooter>
                </Modal>
                <Modal
                    isOpen={showAddModal}
                    onClose={lambda -> None { showAddModal = False;}}
                    title="Add User Override"
                >
                    <div className="space-y-3">
                        {addError and <InlineAlert message={addError} type="error"/>}
                        <div>
                            <label
                                className="block text-sm font-medium text-slate-300 mb-1"
                            >
                                User
                            </label>
                            <select
                                className="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-lg text-white text-sm"
                                value={addUsername}
                                onChange={lambda e: Any  -> None { addUsername = e.target.value;}}
                            >
                                <option value="">
                                    Select a user...
                                </option>
                                {[
                                    <option key={u["username"]} value={u["username"]}>
                                        {u["username"]}
                                    </option> for u in userList
                                ]}
                            </select>
                        </div>
                        <Input
                            label="Monthly Budget ($)"
                            type="number"
                            value={addBudget}
                            onChange={lambda e: Any  -> None { addBudget = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Select
                            label="Period"
                            value={addPeriod}
                            onChange={lambda e: Any  -> None { addPeriod = e.target.value;}}
                            options={periodOptions}
                        />
                        <Input
                            label="Requests/min (RPM)"
                            type="number"
                            value={addRpm}
                            onChange={lambda e: Any  -> None { addRpm = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Input
                            label="Tokens/min (TPM)"
                            type="number"
                            value={addTpm}
                            onChange={lambda e: Any  -> None { addTpm = e.target.value;}}
                            placeholder="0 = unlimited"
                        />
                        <Input
                            label="Allowed Models (comma-separated)"
                            value={addModels}
                            onChange={lambda e: Any  -> None { addModels = e.target.value;}}
                            placeholder="gpt-4o, gpt-4o-mini (empty = all)"
                        />
                    </div>
                    <ModalFooter>
                        <Button
                            variant="ghost"
                            onClick={lambda -> None { showAddModal = False;}}
                        >
                            Cancel
                        </Button>
                        <Button onClick={handleAddUser}>
                            Add
                        </Button>
                    </ModalFooter>
                </Modal>
            </div>;
    }
}
