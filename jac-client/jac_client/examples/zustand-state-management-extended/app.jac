# Demo app showing sliced store usage
cl import from .store { useAppStore }

cl {
    def UserPanel() -> any {
        user = useAppStore(lambda state: any { return state.user; });
        isAuthenticated = useAppStore(lambda state: any { return state.isAuthenticated; });
        login = useAppStore(lambda state: any { return state.login; });
        logout = useAppStore(lambda state: any { return state.logout; });

        return <div style={{"border": "1px solid #e2e8f0", "borderRadius": "12px", "padding": "20px", "backgroundColor": "white"}}>
            <h3 style={{"margin": "0 0 15px", "color": "#0f172a"}}>User Slice</h3>

            {isAuthenticated and
                <div>
                    <p style={{"margin": "0 0 10px", "color": "#475569"}}>
                        Logged in as: <strong>{user.username}</strong> ({user.role})
                    </p>
                    <button
                        onClick={lambda -> None { logout(); }}
                        style={{"padding": "8px 16px", "backgroundColor": "#ef4444", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}>
                        Logout
                    </button>
                </div>
            or
                <div>
                    <p style={{"margin": "0 0 10px", "color": "#475569"}}>Not logged in</p>
                    <button
                        onClick={lambda -> None { login("demo_user", "admin"); }}
                        style={{"padding": "8px 16px", "backgroundColor": "#22c55e", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}>
                        Login as Admin
                    </button>
                </div>
            }
        </div>;
    }

    def SettingsPanel() -> any {
        theme = useAppStore(lambda state: any { return state.theme; });
        notifications = useAppStore(lambda state: any { return state.notifications; });
        setTheme = useAppStore(lambda state: any { return state.setTheme; });
        toggleNotifications = useAppStore(lambda state: any { return state.toggleNotifications; });

        return <div style={{"border": "1px solid #e2e8f0", "borderRadius": "12px", "padding": "20px", "backgroundColor": "white"}}>
            <h3 style={{"margin": "0 0 15px", "color": "#0f172a"}}>Settings Slice</h3>

            <div style={{"marginBottom": "15px"}}>
                <label style={{"display": "block", "marginBottom": "6px", "color": "#475569"}}>Theme</label>
                <select
                    value={theme}
                    onChange={lambda e: any -> None { setTheme(e.target.value); }}
                    style={{"padding": "8px", "borderRadius": "6px", "border": "1px solid #cbd5e1", "width": "100%"}}>
                    <option value="light">Light</option>
                    <option value="dark">Dark</option>
                    <option value="auto">Auto</option>
                </select>
            </div>

            <label style={{"display": "flex", "alignItems": "center", "gap": "8px", "cursor": "pointer"}}>
                <input
                    type="checkbox"
                    checked={notifications}
                    onChange={lambda -> None { toggleNotifications(); }}
                />
                <span style={{"color": "#475569"}}>Enable notifications</span>
            </label>
        </div>;
    }

    def CartPanel() -> any {
        items = useAppStore(lambda state: any { return state.items; });
        total = useAppStore(lambda state: any { return state.total; });
        addItem = useAppStore(lambda state: any { return state.addItem; });
        removeItem = useAppStore(lambda state: any { return state.removeItem; });
        clearCart = useAppStore(lambda state: any { return state.clearCart; });

        return <div style={{"border": "1px solid #e2e8f0", "borderRadius": "12px", "padding": "20px", "backgroundColor": "white"}}>
            <h3 style={{"margin": "0 0 15px", "color": "#0f172a"}}>Cart Slice</h3>

            <div style={{"marginBottom": "15px"}}>
                <button
                    onClick={lambda -> None {
                        addItem({"id": String(Date.now()), "name": "Product " + String(items.length + 1), "price": 10 + (items.length * 5)});
                    }}
                    style={{"padding": "8px 16px", "backgroundColor": "#3b82f6", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer", "marginRight": "8px"}}>
                    Add Random Item
                </button>

                {items.length > 0 and
                    <button
                        onClick={lambda -> None { clearCart(); }}
                        style={{"padding": "8px 16px", "backgroundColor": "#94a3b8", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}>
                        Clear Cart
                    </button>
                }
            </div>

            <div>
                <p style={{"margin": "0 0 10px", "fontWeight": "600", "color": "#0f172a"}}>
                    Items: {items.length} | Total: ${total}
                </p>

                {items.length > 0 and
                    <ul style={{"margin": "0", "padding": "0", "listStyle": "none"}}>
                        {items.map(lambda item: any -> any {
                            return <li key={item.id} style={{"padding": "8px", "backgroundColor": "#f8fafc", "borderRadius": "6px", "marginBottom": "6px", "display": "flex", "justifyContent": "space-between", "alignItems": "center"}}>
                                <span>{item.name} - ${item.price}</span>
                                <button
                                    onClick={lambda -> None { removeItem(item.id); }}
                                    style={{"padding": "4px 8px", "backgroundColor": "#ef4444", "color": "white", "border": "none", "borderRadius": "4px", "fontSize": "12px", "cursor": "pointer"}}>
                                    Remove
                                </button>
                            </li>;
                        })}
                    </ul>
                }
            </div>
        </div>;
    }

    def StateDebugger() -> any {
        fullState = useAppStore();

        return <details style={{"marginTop": "20px", "padding": "15px", "backgroundColor": "#0f172a", "borderRadius": "12px"}}>
            <summary style={{"color": "#e2e8f0", "cursor": "pointer", "fontWeight": "600"}}>
                Full Store State (Debug)
            </summary>
            <pre style={{"marginTop": "10px", "color": "#e2e8f0", "fontSize": "12px", "overflowX": "auto"}}>
                {JSON.stringify(fullState, None, 2)}
            </pre>
        </details>;
    }

    def app() -> any {
        return <main style={{"minHeight": "100vh", "backgroundColor": "#f8fafc", "padding": "40px","fontFamily":"Sans-Serif"}}>
            <div style={{"maxWidth": "900px", "margin": "0 auto"}}>
                <header style={{"marginBottom": "30px"}}>
                    <p style={{"margin": "0 0 6px", "textTransform": "uppercase", "color": "#94a3b8", "letterSpacing": "0.2em", "fontSize": "12px"}}>
                        Production Pattern
                    </p>
                    <h1 style={{"margin": "0", "fontSize": "36px", "color": "#0f172a"}}>
                        Sliced Zustand Store
                    </h1>
                    <p style={{"marginTop": "8px", "color": "#475569"}}>
                        State organized by feature domain: User, Settings, Cart. Each slice is independent and composable.
                    </p>
                </header>

                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(280px, 1fr))", "gap": "20px"}}>
                    <UserPanel />
                    <SettingsPanel />
                    <CartPanel />
                </div>

                <StateDebugger />
            </div>
        </main>;
    }
}
