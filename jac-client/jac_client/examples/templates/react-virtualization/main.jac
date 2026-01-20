"""Main entry point for react-virtualization."""

# Client-side imports (useState is auto-injected when using `has` variables)
cl import from react { useEffect, useRef, Fragment, useState, useMemo }
cl import from .components.Button { Button }
cl import from "@tanstack/react-virtual" { useVirtualizer }

cl import ".styles.css";


# Client-side component
cl {
        # Generate sample user data
    def generate_users(count: int) -> list {
        users = [];
        first_names = ["John", "Jane", "Mike", "Sarah", "David", "Emily", "Chris", "Anna", "Tom", "Lisa"];
        last_names = ["Smith", "Johnson", "Brown", "Taylor", "Anderson", "Thomas", "Jackson", "White", "Harris", "Martin"];
        departments = ["Engineering", "Sales", "Marketing", "HR", "Finance", "Operations", "IT", "Legal"];

        for i=0 to i<count by i+=1 {
            user = {
                "id": i + 1,
                "firstName": first_names[i % (first_names.length)],
                "lastName": last_names[i % (last_names.length)],
                "email": f"{first_names[i % (first_names.length)].toLowerCase()}.{last_names[i % (last_names.length)].toLowerCase()}{i}@company.com",
                "department": departments[i % (departments.length)],
                "salary": 50000 + (i * 123) % 100000,
                "age": 22 + (i * 7) % 40,
                "joinDate": f"202{i % 4}-{(i % 12) + 1:02d}-{(i % 28) + 1:02d}"
            };
            users.push(user);
        }

        return users;
    }

    # Simple List Virtualizer - Most common use case
    def SimpleListVirtualizer() -> any {
        parentRef = useRef(None);
        items = generate_users(10000);

        rowVirtualizer = useVirtualizer({
            "count": (items.length),
            "getScrollElement": lambda -> any { return parentRef.current; },
            "estimateSize": lambda -> int { return 60; },
            "overscan": 10,
        });

        return <div className="section">
            <h2 className="section-title">Simple List (10,000 Users)</h2>
            <p className="section-description">
                Efficiently renders large lists - only DOM elements for visible items are created
            </p>
            <div ref={parentRef} className="list-container">
                <div className="list-inner" style={{"height": f"{rowVirtualizer.getTotalSize()}px"}}>
                    {
                        rowVirtualizer.getVirtualItems().map(lambda virtualRow: any, index: int -> any {
                            item = items[virtualRow.index];
                            return <div
                                key={virtualRow.key}
                                className={("list-item even" if virtualRow.index % 2 == 0 else "list-item odd")}
                                style={{
                                    "height": f"{virtualRow.size}px",
                                    "transform": f"translateY({virtualRow.start}px)"
                                }}
                            >
                                <div className="list-item-left">
                                    <div className="list-item-name">{item['firstName']} {item['lastName']}</div>
                                    <div className="list-item-email">{item['email']}</div>
                                </div>
                                <div className="list-item-right">
                                    <div className="list-item-department">{item['department']}</div>
                                    <div className="list-item-salary">{item["salary"]}</div>
                                </div>
                            </div>;
                        })
                    }
                </div>
            </div>
        </div>;
    }

    # Data Table Virtualizer with sortable columns
    def DataTableVirtualizer() -> any {
        parentRef = useRef(None);
         allUsers = generate_users(50000);
         sortField = "id";
         sortDirection = "asc";

        # Sort data based on current sort state
        sortedUsers = useMemo(lambda -> list {
            sorted_list = allUsers.slice();  # Create a copy

            if sortField == "name" {
                sorted_list.sort(lambda a: dict, b: dict -> int {
                    nameA = f"{a['firstName']} {a['lastName']}";
                    nameB = f"{b['firstName']} {b['lastName']}";
                    if sortDirection == "asc" {
                        return -1 if nameA < nameB else 1 if nameA > nameB else 0;
                    } else {
                        return 1 if nameA < nameB else -1 if nameA > nameB else 0;
                    }
                });
            } elif sortField == "department" {
                sorted_list.sort(lambda a: dict, b: dict -> int {
                    if sortDirection == "asc" {
                        return -1 if a['department'] < b['department'] else 1 if a['department'] > b['department'] else 0;
                    } else {
                        return 1 if a['department'] < b['department'] else -1 if a['department'] > b['department'] else 0;
                    }
                });
            } elif sortField == "salary" {
                sorted_list.sort(lambda a: dict, b: dict -> int {
                    if sortDirection == "asc" {
                        return a['salary'] - b['salary'];
                    } else {
                        return b['salary'] - a['salary'];
                    }
                });
            } else {
                sorted_list.sort(lambda a: dict, b: dict -> int {
                    if sortDirection == "asc" {
                        return a['id'] - b['id'];
                    } else {
                        return b['id'] - a['id'];
                    }
                });
            }

            return sorted_list;
        }, [allUsers, sortField, sortDirection]);

        rowVirtualizer = useVirtualizer({
            "count": (sortedUsers.length),
            "getScrollElement": lambda -> any { return parentRef.current; },
            "estimateSize": lambda -> int { return 45; },
            "overscan": 15,
        });

        def handle_sort(field: str) -> None {
            if sortField == field {
                sortDirection = "desc" if sortDirection == "asc" else "asc";
            } else {
                sortField = field;
                sortDirection = "asc";
            }
        }

        def get_sort_indicator(field: str) -> str {
            if sortField == field {
                return " ↓" if sortDirection == "desc" else " ↑";
            }
            return "";
        }

        return <div className="section">
            <h2 className="section-title">Data Table (50,000 Users)</h2>
            <p className="section-description">
                Sortable columns with virtualized rows - handles massive datasets smoothly
            </p>
            <div className="table-container">
                <div className="table-header">
                    <div onClick={lambda: handle_sort("id")} className="table-header-cell">
                        ID{get_sort_indicator("id")}
                    </div>
                    <div onClick={lambda: handle_sort("name")} className="table-header-cell">
                        Name{get_sort_indicator("name")}
                    </div>
                    <div onClick={lambda: handle_sort("department")} className="table-header-cell">
                        Department{get_sort_indicator("department")}
                    </div>
                    <div onClick={lambda: handle_sort("salary")} className="table-header-cell">
                        Salary{get_sort_indicator("salary")}
                    </div>
                    <div>Join Date</div>
                </div>

                <div ref={parentRef} className="table-body">
                    <div className="table-body-inner" style={{"height": f"{rowVirtualizer.getTotalSize()}px"}}>
                        {
                            rowVirtualizer.getVirtualItems().map(lambda virtualRow: any, index: int -> any {
                                user = sortedUsers[virtualRow.index];
                                return <div
                                    key={virtualRow.key}
                                    className={("table-row even" if virtualRow.index % 2 == 0 else "table-row odd")}
                                    style={{
                                        "height": f"{virtualRow.size}px",
                                        "transform": f"translateY({virtualRow.start}px)"
                                    }}
                                >
                                    <div className="table-cell-id"> No. {user['id']}</div>
                                    <div className="table-cell-name">{user['firstName']} {user['lastName']}</div>
                                    <div>
                                        <span className="table-cell-badge">{user['department']}</span>
                                    </div>
                                    <div className="table-cell-salary">{user["salary"]}</div>
                                    <div className="table-cell-date">{user['joinDate']}</div>
                                </div>;
                            })
                        }
                    </div>
                </div>
            </div>
        </div>;
    }

    # Grid Virtualizer - Useful for spreadsheet-like interfaces
    def GridVirtualizerFixed() -> any {
        parentRef = useRef(None);
         data = generate_users(5000);

        rowVirtualizer = useVirtualizer({
            "count": (data.length),
            "getScrollElement": lambda -> any { return parentRef.current; },
            "estimateSize": lambda -> int { return 45; },
            "overscan": 5,
        });

        columnVirtualizer = useVirtualizer({
            "horizontal": True,
            "count": 8,  # 8 columns
            "getScrollElement": lambda -> any { return parentRef.current; },
            "estimateSize": lambda index: int -> int { return 150 if index == 2 else 120; },  # Email column wider
            "overscan": 3,
        });

        columns = ["ID", "First Name", "Email", "Last Name", "Dept", "Salary", "Age", "Join Date"];

        def get_cell_value(user: dict, col_index: int) -> str {
            if col_index == 0 {
                return (user['id']);
            } elif col_index == 1 {
                return user['firstName'];
            } elif col_index == 2 {
                return user['email'];
            } elif col_index == 3 {
                return user['lastName'];
            } elif col_index == 4 {
                return user['department'];
            } elif col_index == 5 {
                return user['salary'];
            } elif col_index == 6 {
                return (user['age']);
            } else {
                return user['joinDate'];
            }
        }

        return <div className="section">
            <h2 className="section-title">Grid Virtualizer (5,000 rows × 8 columns)</h2>
            <p className="section-description">
                2D virtualization - efficient for spreadsheet-like data with many columns
            </p>
            <div ref={parentRef} className="grid-container">
                <div
                    className="grid-inner"
                    style={{
                        "height": f"{rowVirtualizer.getTotalSize()}px",
                        "width": f"{columnVirtualizer.getTotalSize()}px"
                    }}
                >
                    {
                        columnVirtualizer.getVirtualItems().map(lambda virtualColumn: any, index: int -> any {
                            return <div
                                key={f"header-{virtualColumn.key}"}
                                className="grid-header-cell"
                                style={{
                                    "width": f"{virtualColumn.size}px",
                                    "transform": f"translateX({virtualColumn.start}px)"
                                }}
                            >
                                {columns[virtualColumn.index]}
                            </div>;
                        })
                    }

                    {
                        rowVirtualizer.getVirtualItems().map(lambda virtualRow: any, rowIdx: int -> any {
                            user = data[virtualRow.index];
                            return <Fragment key={virtualRow.key}>
                                {
                                    columnVirtualizer.getVirtualItems().map(lambda virtualColumn: any, colIdx: int -> any {
                                        return <div
                                            key={virtualColumn.key}
                                            className={("grid-cell even" if virtualRow.index % 2 == 0 else "grid-cell odd")}
                                            style={{
                                                "width": f"{virtualColumn.size}px",
                                                "height": f"{virtualRow.size}px",
                                                "transform": f"translateX({virtualColumn.start}px) translateY({virtualRow.start + 48}px)"
                                            }}
                                        >
                                            {get_cell_value(user, virtualColumn.index)}
                                        </div>;
                                    })
                                }
                            </Fragment>;
                        })
                    }
                </div>
            </div>
        </div>;
    }

    def:pub app() -> any {
        [activeTab, setActiveTab ]= useState("list");

        return <div className="app-container">
            <div className="app-header">
                <h1 className="app-title">React Virtualization Examples</h1>
                <p className="app-description">
                    Demonstrates efficient rendering of large datasets using @tanstack/react-virtual.
                    Virtualization only renders visible items, dramatically improving performance.
                </p>
            </div>

            <div className="tabs-container">
                <button
                    onClick={lambda -> None { return setActiveTab("list"); }}
                    className={("tab-button active" if activeTab == "list" else "tab-button")}
                >
                    Simple List
                </button>
                <button
                    onClick={lambda -> None { return setActiveTab("table"); }}
                    className={("tab-button active" if activeTab == "table" else "tab-button")}
                >
                    Data Table
                </button>
                <button
                    onClick={lambda -> None { return setActiveTab("grid"); }}
                    className={("tab-button active" if activeTab == "grid" else "tab-button")}
                >
                    Grid
                </button>
            </div>

            <div>
                {activeTab == "list" and <SimpleListVirtualizer />}
                {activeTab == "table" and <DataTableVirtualizer />}
                {activeTab == "grid" and <GridVirtualizerFixed />}
            </div>

            <div className="info-box">
                <h3 className="info-box-title">Why Virtualization?</h3>
                <ul className="info-box-list">
                    <li><strong>Performance:</strong> Only renders visible items instead of all {50000} rows</li>
                    <li><strong>Memory Efficient:</strong> Minimal DOM nodes regardless of data size</li>
                    <li><strong>Smooth Scrolling:</strong> Maintains 60fps even with huge datasets</li>
                    <li><strong>Flexible:</strong> Works with lists, tables, grids, and custom layouts</li>
                </ul>
            </div>
        </div>;
    }
}
