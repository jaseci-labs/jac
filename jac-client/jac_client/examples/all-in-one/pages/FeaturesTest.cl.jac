# # Features Test Page - Client-side UI
# # Demonstrates: props, exports, cl files, TypeScript imports, string methods,
# # imports from JAC/JS/TS, spawning walkers from cl file

import from "@jac-client/utils" { Link, useNavigate }
import from react { useState, useEffect }

# # Import TypeScript component
# import from ..components.PieChart { PieChart }

# # Import JavaScript helpers
import from ..utils.helpers { generateId, calculatePercentage, sumBy }

# # Import from other JAC files
import from ..utils.formatters { formatCurrency }

# ============================================================================
# REUSABLE COMPONENTS WITH PROPS
# ============================================================================

    # Button component demonstrating props - NEW PATTERN: Direct parameters
    def:pub TestButton(text: str, onClick: any, variant: str) -> any {
        bg_color = "#3b82f6" if variant == "primary" else "#6b7280";
        hover_color = "#2563eb" if variant == "primary" else "#4b5563";

        return <button
            onClick={onClick}
            style={{
                "padding": "10px 20px",
                "backgroundColor": bg_color,
                "color": "white",
                "border": "none",
                "borderRadius": "6px",
                "cursor": "pointer",
                "fontSize": "14px",
                "fontWeight": "600",
                "transition": "all 0.2s"
            }}
            onMouseOver={lambda e: any -> None {
                e.target.style.backgroundColor = hover_color;
            }}
            onMouseOut={lambda e: any -> None {
                e.target.style.backgroundColor = bg_color;
            }}
        >
            {text}
        </button>;
    }

    # # Card component with props - NEW PATTERN: Direct parameters
    def:pub TestCard(title: str, children: any, color: str) -> any {
        return <div style={{
            "backgroundColor": "white",
            "border": "1px solid #e5e7eb",
            "borderRadius": "8px",
            "padding": "20px",
            "marginBottom": "20px",
            "boxShadow": "0 1px 3px rgba(0,0,0,0.1)"
        }}>
            <div style={{
                "backgroundColor": color,
                "padding": "10px",
                "borderRadius": "6px",
                "marginBottom": "15px"
            }}>
                <h3 style={{
                    "margin": "0",
                    "fontSize": "18px",
                    "fontWeight": "600",
                    "color": "#1f2937"
                }}>{title}</h3>
            </div>
            <div>{children}</div>
        </div>;
    }

    # Result display component - NEW PATTERN: Direct parameters
    def:pub ResultDisplay(data: any, label: str) -> any {
        if not data {
            return <div style={{"color": "#9ca3af", "fontStyle": "italic"}}>
                No data to display
            </div>;
        }

        return <div style={{
            "backgroundColor": "#f9fafb",
            "padding": "15px",
            "borderRadius": "6px",
            "border": "1px solid #e5e7eb"
        }}>
            <strong style={{"color": "#374151"}}>{label}:</strong>
            <pre style={{
                "marginTop": "10px",
                "padding": "10px",
                "backgroundColor": "#1f2937",
                "color": "#10b981",
                "borderRadius": "4px",
                "overflow": "auto",
                "fontSize": "12px",
                "fontFamily": "monospace"
            }}>
                {JSON.stringify(data, None, 2)}
            </pre>
        </div>;
    }

    # ============================================================================
    # MAIN PAGE COMPONENT
    # ============================================================================

    def:pub FeaturesTest() -> any {
        navigate = useNavigate();

        # State management
        has testMessage: str = "";
        has testData: list = [];
        has stringInput: str = "Hello JAC World!";
        has stringResult: any = None;
        has numberList: str = "1,2,3,4,5";
        has listResult: any = None;
        has complexResult: any = None;
        has loading: bool = false;

        # Load test data on mount
        useEffect(lambda -> None {
            async def loadData() -> None {
                try {
                    result = root spawn read_test_data();
                    testData = result.reports if result.reports[0] else [];
                } except Exception as e {
                    console.log("Error loading data:", e);
                }
            }
            loadData();
        }, []);

        # ========================================================================
        # EVENT HANDLERS - Demonstrating Walker Spawning from CL
        # ========================================================================

        # Create test data
        async def handleCreate() -> None {
            if not testMessage.trim() {
                alert("Please enter a message");
                return;
            }

            loading = true;
            try {
                response = root spawn create_test_data(message=testMessage.trim());
                new_item = response.reports[0][0];
                testData = testData.concat([new_item]);
                testMessage = "";
                alert("Data created successfully!");
            } except Exception as e {
                console.error("Error creating data:", e);
                alert("Error creating data: " + e.toString());
            }
            loading = false;
        }

        # Update test data
        async def handleUpdate(item_id: any) -> None {
            new_msg = prompt("Enter new message:");
            if not new_msg {
                return;
            }

            loading = true;
            try {
                item_id spawn update_test_data(new_message=new_msg);
                # Reload data
                result = root spawn read_test_data();
                testData = result.reports if result.reports[0] else [];
                alert("Data updated successfully!");
            } except Exception as e {
                console.error("Error updating data:", e);
                alert("Error updating data: " + e.toString());
            }
            loading = false;
        }

        # Delete test data
        async def handleDelete(item_id: any) -> None {
            if not confirm("Are you sure you want to delete this item?") {
                return;
            }

            loading = true;
            try {
                item_id spawn delete_test_data();
                # Remove from local state
                testData = testData.filter(lambda item: any -> bool {
                    return item._jac_id != item_id;
                });
                alert("Data deleted successfully!");
            } except Exception as e {
                console.error("Error deleting data:", e);
                alert("Error deleting data: " + e.toString());
            }
            loading = false;
        }

        # Test string methods via walker
        async def handleStringTest() -> None {
            loading = true;
            try {
                response = root spawn test_string_methods(input_text=stringInput);
                result = response.reports[0];
                stringResult = result;
            } except Exception as e {
                console.error("Error testing strings:", e);
                alert("Error testing strings: " + e.toString());
            }
            loading = false;
        }

        # Test list operations via walker
        async def handleListTest() -> None {
            loading = true;
            try {
                # Parse number list
                numbers = numberList.split(",").map(lambda x: str -> int {
                    return parseInt(x.trim());
                }).filter(lambda x: any -> bool {
                    return not isNaN(x);
                });

                response = root spawn test_list_operations(numbers=numbers);
                result = response.reports[0];
                listResult = result;
            } except Exception as e {
                console.error("Error testing lists:", e);
                alert("Error testing lists: " + e.toString());
            }
            loading = false;
        }

        # Test complex data processing
        async def handleComplexTest() -> None {
            loading = true;
            try {
                # Generate sample data using JS helper
                sample_items = [
                    {"id": generateId(), "name": "apple", "value": 10},
                    {"id": generateId(), "name": "banana", "value": 20},
                    {"id": generateId(), "name": "cherry", "value": 30}
                ];

                response = root spawn process_complex_data(items=sample_items);
                result = response.reports[0];
                complexResult = result;
            } except Exception as e {
                console.error("Error processing complex data:", e);
                alert("Error processing complex data: " + e.toString());
            }
            loading = false;
        }

        # ========================================================================
        # DEMONSTRATION OF STRING METHODS (CLIENT-SIDE)
        # ========================================================================
        demo_text = "JAC Language Features";
        string_demos = {
            "Original": demo_text,
            "Uppercase": demo_text.toUpperCase(),
            "Lowercase": demo_text.toLowerCase(),
            "Length": demo_text.length.toString(),
            "Split by space": demo_text.split(" ").join(", ")
        };

        # Demo chart data for TypeScript component
        chart_data = [
            {"name": "Walker Tests", "value": 5},
            {"name": "String Methods", "value": 8},
            {"name": "List Operations", "value": 7},
            {"name": "Components", "value": 4}
        ];

        # Calculate total using JS helper
        total_tests = sumBy(chart_data, "value");


        # ========================================================================
        # RENDER
        # ========================================================================
        return <div style={{
            "maxWidth": "1200px",
            "margin": "0 auto",
            "padding": "20px",
            "fontFamily": "system-ui, -apple-system, sans-serif"
        }}>
            # Header
            <div style={{
                "display": "flex",
                "justifyContent": "space-between",
                "alignItems": "center",
                "marginBottom": "30px"
            }}>
                <h1 style={{"color": "#1f2937", "margin": "0"}}>
                    JAC Features Test Suite
                </h1>
                <Link to="/">
                    <TestButton text="← Back Home" onClick={lambda -> None {}} variant="secondary" />
                </Link>
            </div>

            # Loading indicator
            {loading and <div style={{
                "position": "fixed",
                "top": "20px",
                "right": "20px",
                "backgroundColor": "#3b82f6",
                "color": "white",
                "padding": "10px 20px",
                "borderRadius": "6px",
                "boxShadow": "0 4px 6px rgba(0,0,0,0.2)",
                "zIndex": "1000"
            }}>
                Processing...
            </div>}

            # Section 1: Walker CRUD Operations
            <TestCard title="1. Walker CRUD Operations (Spawn from CL)" color="#dbeafe">
                <div style={{"marginBottom": "15px"}}>
                    <p style={{"color": "#4b5563", "marginBottom": "10px"}}>
                        Test creating, reading, updating, and deleting data using walkers spawned from client code.
                    </p>

                    <div style={{"display": "flex", "gap": "10px", "marginBottom": "15px"}}>
                        <input
                            type="text"
                            value={testMessage}
                            onChange={lambda e: any -> None { testMessage = e.target.value; }}
                            placeholder="Enter test message..."
                            style={{
                                "flex": "1",
                                "padding": "10px",
                                "border": "1px solid #d1d5db",
                                "borderRadius": "6px",
                                "fontSize": "14px"
                            }}
                        />
                        <TestButton
                            text="Create"
                            onClick={lambda -> None { handleCreate(); }}
                            variant="primary"
                        />
                    </div>

                    <div style={{"marginTop": "20px"}}>
                        <strong style={{"color": "#374151"}}>Stored Data ({testData.length} items):</strong>
                        {testData.length == 0 and <p style={{"color": "#9ca3af", "fontStyle": "italic"}}>
                            No data yet. Create some!
                        </p>}
                        {testData.map(lambda item: any -> any {
                            return <div
                                key={item._jac_id}
                                style={{
                                    "backgroundColor": "#f9fafb",
                                    "padding": "12px",
                                    "borderRadius": "6px",
                                    "marginTop": "8px",
                                    "display": "flex",
                                    "justifyContent": "space-between",
                                    "alignItems": "center"
                                }}
                            >
                                <div>
                                    <div style={{"fontWeight": "600", "color": "#1f2937"}}>
                                        {item.message}
                                    </div>
                                    <div style={{"fontSize": "12px", "color": "#6b7280"}}>
                                        Count: {item.count} | Created: {item.created_at}
                                    </div>
                                </div>
                                <div style={{"display": "flex", "gap": "8px"}}>
                                    <TestButton
                                        text="Edit"
                                        onClick={lambda -> None { handleUpdate(item._jac_id); }}
                                        variant="secondary"
                                    />
                                    <TestButton
                                        text="Delete"
                                        onClick={lambda -> None { handleDelete(item._jac_id); }}
                                        variant="secondary"
                                    />
                                </div>
                            </div>;
                        })}
                    </div>
                </div>
            </TestCard>

            # # Section 2: String Methods
            <TestCard title="2. String Methods (Client & Walker)" color="#fce7f3">
                <div>
                    <p style={{"color": "#4b5563", "marginBottom": "10px"}}>
                        Client-side string manipulation and walker-based string processing.
                    </p>

                    # Client-side demo
                    <div style={{"marginBottom": "20px"}}>
                        <strong style={{"color": "#374151"}}>Client-side String Demo:</strong>
                        <div style={{
                            "backgroundColor": "#fef3c7",
                            "padding": "10px",
                            "borderRadius": "6px",
                            "marginTop": "8px"
                        }}>
                            {Object.keys(string_demos).map(lambda key: str -> any {
                                return <div key={key} style={{"marginBottom": "5px"}}>
                                    <span style={{"fontWeight": "600"}}>{key}:</span> {string_demos[key]}
                                </div>;
                            })}
                        </div>
                    </div>

                    # Walker-based test
                    <div>
                        <strong style={{"color": "#374151"}}>Walker String Processing:</strong>
                        <div style={{"display": "flex", "gap": "10px", "marginTop": "10px"}}>
                            <input
                                type="text"
                                value={stringInput}
                                onChange={lambda e: any -> None { stringInput = e.target.value; }}
                                style={{
                                    "flex": "1",
                                    "padding": "10px",
                                    "border": "1px solid #d1d5db",
                                    "borderRadius": "6px",
                                    "fontSize": "14px"
                                }}
                            />
                            <TestButton
                                text="Process with Walker"
                                onClick={lambda -> None { handleStringTest(); }}
                                variant="primary"
                            />
                        </div>
                        {stringResult and <ResultDisplay data={stringResult} label="Walker Result" />}
                    </div>
                </div>
            </TestCard>

            # # Section 3: List Operations
            <TestCard title="3. List/Array Operations" color="#ddd6fe">
                <div>
                    <p style={{"color": "#4b5563", "marginBottom": "10px"}}>
                        Process arrays/lists using walker operations.
                    </p>

                    <div style={{"display": "flex", "gap": "10px", "marginTop": "10px"}}>
                        <input
                            type="text"
                            value={numberList}
                            onChange={lambda e: any -> None { numberList = e.target.value; }}
                            placeholder="Enter numbers (comma-separated)"
                            style={{
                                "flex": "1",
                                "padding": "10px",
                                "border": "1px solid #d1d5db",
                                "borderRadius": "6px",
                                "fontSize": "14px"
                            }}
                        />
                        <TestButton
                            text="Process List"
                            onClick={lambda -> None { handleListTest(); }}
                            variant="primary"
                        />
                    </div>
                    {listResult and <ResultDisplay data={listResult} label="List Operations Result" />}
                </div>
            </TestCard>

            # # Section 4: TypeScript Component Integration
            # <TestCard title="4. TypeScript Component (PieChart.tsx)" color="#ccfbf1">
            #     <div>
            #         <p style={{"color": "#4b5563", "marginBottom": "10px"}}>
            #             Imported TypeScript React component with data from JAC.
            #         </p>
            #         # <PieChart data={chart_data} title="Feature Test Distribution" />
            #         <p style={{"marginTop": "10px", "color": "#6b7280", "fontSize": "14px"}}>
            #             Total tests: {total_tests} (calculated using JS helper: sumBy)
            #         </p>
            #     </div>
            # </TestCard>

            # # Section 5: Import Demonstrations
            <TestCard title="5. Import Demonstrations" color="#fed7aa">
                <div>
                    <p style={{"color": "#4b5563", "marginBottom": "15px"}}>
                        This page demonstrates various import types:
                    </p>

                    <ul style={{"color": "#374151", "lineHeight": "1.8"}}>
                        <li><strong>JAC-Client Utils:</strong> Router components (Link, useNavigate)</li>
                        <li><strong>React:</strong> Hooks (useState, useEffect)</li>
                        # <li><strong>TypeScript:</strong> PieChart component from .tsx file</li>
                        <li><strong>JavaScript:</strong> Helper functions from .js file (generateId, sumBy)</li>
                        <li><strong>JAC Files:</strong> formatCurrency from utils/formatters.jac</li>
                    </ul>

                    <div style={{
                        "backgroundColor": "#f0fdf4",
                        "padding": "15px",
                        "borderRadius": "6px",
                        "marginTop": "15px"
                    }}>
                        <strong style={{"color": "#065f46"}}>Examples:</strong>
                        <div style={{"marginTop": "8px", "fontSize": "14px", "color": "#047857"}}>
                            <div>Generated ID: {generateId()}</div>
                            <div>Formatted Currency: {formatCurrency(1234.56)}</div>
                            <div>Percentage Calc: {calculatePercentage(75, 100)}%</div>
                        </div>
                    </div>
                </div>
            </TestCard>

            # # Section 6: Complex Data Processing
            <TestCard title="6. Complex Data Processing" color="#e0e7ff">
                <div>
                    <p style={{"color": "#4b5563", "marginBottom": "10px"}}>
                        Process complex nested data structures with walkers.
                    </p>

                    <TestButton
                        text="Process Sample Data"
                        onClick={lambda -> None { handleComplexTest(); }}
                        variant="primary"
                    />

                    {complexResult and <ResultDisplay data={complexResult} label="Complex Processing Result" />}
                </div>
            </TestCard>

            # Footer
            <div style={{
                "marginTop": "30px",
                "padding": "20px",
                "backgroundColor": "#f9fafb",
                "borderRadius": "8px",
                "textAlign": "center",
                "color": "#6b7280"
            }}>
                <p style={{"margin": "0"}}>
                    ✅ All features tested: Props, Exports, CL Files, TypeScript, JavaScript, JAC Imports, String Methods, Walker Spawning
                </p>
            </div>
        </div>;
    }
