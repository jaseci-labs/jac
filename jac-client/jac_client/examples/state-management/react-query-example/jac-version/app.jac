# # Expected Redux example implemented in pure Jac using React Query
# # But, it will not work until fix the new keyword issue in the Jac compiler

# cl import from react { useState }
# cl import from "@tanstack/react-query" { QueryClient, QueryClientProvider, useQuery, useMutation, useQueryClient }

# cl {
#     # ===== SETUP: QueryClient Configuration =====
#     # Now we can use QueryClient constructor directly in Jac!
#     let queryClient = QueryClient({
#         "defaultOptions": {
#             "queries": {
#                 "staleTime": 1000 * 5,  # 5 seconds
#                 "cacheTime": 1000 * 60 * 5  # 5 minutes
#             }
#         }
#     });

#     # ===== MOCK DATABASE =====
#     # In-memory database (persists across renders in same session)
#     let usersDatabase = [
#         {"id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "Developer"},
#         {"id": 2, "name": "Bob Smith", "email": "bob@example.com", "role": "Designer"},
#         {"id": 3, "name": "Carol White", "email": "carol@example.com", "role": "Manager"},
#         {"id": 4, "name": "David Brown", "email": "david@example.com", "role": "Developer"}
#     ];

#     # ===== MOCK API FUNCTIONS =====
#     # Now we can use Promise constructor directly in Jac!

#     async def fetchUsers() -> any {
#         # Simulate API delay
#         await Promise(lambda resolve: any -> None {
#             setTimeout(resolve, 1000);
#         });

#         # Return copy of database
#         return usersDatabase.slice();
#     }

#     async def fetchUserById(userId: int) -> any {
#         await Promise(lambda resolve: any -> None {
#             setTimeout(resolve, 800);
#         });

#         user = usersDatabase.find(lambda u: any -> any { return u.id == userId; });

#         if not user {
#                return None;
#         }

#         return Object.assign({}, user);
#     }

#     async def createUser(newUser: dict) -> any {
#         await Promise(lambda resolve: any -> None {
#             setTimeout(resolve, 1000);
#         });

#         # Create user with unique ID
#         user = Object.assign({}, newUser, {"id": Date.now()});

#         # Add to database
#         usersDatabase.push(user);

#         console.log("✅ User created and added to database:", user);
#         console.log("📊 Total users now:", usersDatabase.length);

#         return user;
#     }

#     async def deleteUser(userId: int) -> any {
#         await Promise(lambda resolve: any -> None {
#             setTimeout(resolve, 800);
#         });

#         index = usersDatabase.findIndex(lambda u: any -> any { return u.id == userId; });

#         if index == -1 {
#             return None;
#         }

#         # Remove from database
#         deletedUser = usersDatabase.splice(index, 1)[0];

#         console.log("🗑️ User deleted from database:", deletedUser);
#         console.log("📊 Total users now:", usersDatabase.length);

#         return {"success": True, "deletedId": userId};
#     }

#     # ===== COMPONENT: Users List with useQuery =====
#     def UsersList() -> any {
#         queryResult = useQuery({
#             "queryKey": ["users"],
#             "queryFn": fetchUsers
#         });

#         data = queryResult.data;
#         isLoading = queryResult.isLoading;
#         error = queryResult.error;
#         refetch = queryResult.refetch;

#         if isLoading {
#             return <div style={{"padding": "20px", "textAlign": "center", "color": "#64748b"}}>
#                 ⏳ Loading users...
#             </div>;
#         }

#         if error {
#             return <div style={{"padding": "20px", "color": "#ef4444"}}>
#                 ❌ Error: {error.message}
#             </div>;
#         }

#         return <div style={{"padding": "20px"}}>
#             <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "15px"}}>
#                 <h3 style={{"margin": "0", "color": "#0f172a"}}>Users List (useQuery)</h3>
#                 <button
#                     onClick={lambda -> None { refetch(); }}
#                     style={{"padding": "8px 16px", "backgroundColor": "#3b82f6", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}>
#                     🔄 Refetch
#                 </button>
#             </div>

#             <div style={{"display": "grid", "gap": "10px"}}>
#                 {data and data.map(lambda user: any -> any {
#                     return <div key={user.id} style={{"padding": "12px", "backgroundColor": "#f8fafc", "borderRadius": "8px", "border": "1px solid #e2e8f0"}}>
#                         <div style={{"fontWeight": "600", "color": "#0f172a"}}>{user.name}</div>
#                         <div style={{"fontSize": "14px", "color": "#64748b"}}>{user.email}</div>
#                         <div style={{"fontSize": "12px", "color": "#94a3b8", "marginTop": "4px"}}>Role: {user.role}</div>
#                     </div>;
#                 })}
#             </div>
#         </div>;
#     }

#     # ===== COMPONENT: User Detail with Dependent Query =====
#     def UserDetail() -> any {
#         let [selectedUserId, setSelectedUserId] = useState(1);

#         # Fetch all users for the dropdown
#         usersQueryResult = useQuery({
#             "queryKey": ["users"],
#             "queryFn": fetchUsers
#         });

#         usersData = usersQueryResult.data;

#         # Fetch selected user detail
#         def userQueryFn() -> any {
#             return fetchUserById(selectedUserId);
#         }

#         queryResult = useQuery({
#             "queryKey": ["user", selectedUserId],
#             "queryFn": userQueryFn,
#             "enabled": selectedUserId != None
#         });

#         data = queryResult.data;
#         isFetching = queryResult.isFetching;

#         return <div style={{"padding": "20px", "backgroundColor": "white", "borderRadius": "12px", "border": "1px solid #e2e8f0"}}>
#             <h3 style={{"margin": "0 0 15px", "color": "#0f172a"}}>User Detail (Dependent Query)</h3>

#             <div style={{"marginBottom": "15px"}}>
#                 <label style={{"display": "block", "marginBottom": "6px", "color": "#64748b", "fontSize": "14px"}}>
#                     Select User:
#                 </label>
#                 <select
#                     value={selectedUserId}
#                     onChange={lambda e: any -> None { setSelectedUserId(Number(e.target.value)); }}
#                     style={{"padding": "8px", "borderRadius": "6px", "border": "1px solid #cbd5e1", "width": "100%"}}>
#                     {usersData and usersData.map(lambda user: any -> any {
#                         return <option key={user.id} value={user.id}>
#                             {user.name} ({user.role})
#                         </option>;
#                     })}
#                 </select>
#                 <div style={{"fontSize": "11px", "color": "#94a3b8", "marginTop": "4px"}}>
#                     💡 This dropdown updates automatically when new users are created!
#                 </div>
#             </div>

#             {isFetching and
#                 <div style={{"padding": "15px", "textAlign": "center", "color": "#64748b"}}>
#                     ⏳ Fetching user details...
#                 </div>
#             or (data and
#                 <div style={{"padding": "15px", "backgroundColor": "#f1f5f9", "borderRadius": "8px"}}>
#                     <div style={{"fontSize": "18px", "fontWeight": "600", "color": "#0f172a", "marginBottom": "8px"}}>{data.name}</div>
#                     <div style={{"color": "#64748b", "marginBottom": "4px"}}>📧 {data.email}</div>
#                     <div style={{"color": "#64748b"}}>💼 {data.role}</div>
#                 </div>
#             )}
#         </div>;
#     }

#     # ===== COMPONENT: Create User with useMutation =====
#     def CreateUserForm() -> any {
#         let [name, setName] = useState("");
#         let [email, setEmail] = useState("");
#         let [role, setRole] = useState("Developer");

#         client = useQueryClient();

#         mutation = useMutation({
#             "mutationFn": createUser,
#             "onSuccess": lambda data: any -> None {
#                 # Invalidate users query to refetch
#                 client.invalidateQueries({"queryKey": ["users"]});
#                 # Clear form
#                 setName("");
#                 setEmail("");
#                 setRole("Developer");
#             }
#         });

#         isLoading = mutation.isPending;
#         isSuccess = mutation.isSuccess;
#         error = mutation.error;

#         def handleSubmit(e: any) -> None {
#             e.preventDefault();
#             if name and email {
#                 mutation.mutate({"name": name, "email": email, "role": role});
#             }
#         }

#         return <div style={{"padding": "20px", "backgroundColor": "white", "borderRadius": "12px", "border": "1px solid #e2e8f0"}}>
#             <h3 style={{"margin": "0 0 15px", "color": "#0f172a"}}>Create User (useMutation)</h3>

#             <form onSubmit={handleSubmit}>
#                 <div style={{"marginBottom": "12px"}}>
#                     <label style={{"display": "block", "marginBottom": "6px", "color": "#64748b", "fontSize": "14px"}}>Name:</label>
#                     <input
#                         type="text"
#                         value={name}
#                         onChange={lambda e: any -> None { setName(e.target.value); }}
#                         style={{"width": "100%", "padding": "8px", "borderRadius": "6px", "border": "1px solid #cbd5e1", "boxSizing": "border-box"}}
#                         placeholder="Enter name"
#                     />
#                 </div>

#                 <div style={{"marginBottom": "12px"}}>
#                     <label style={{"display": "block", "marginBottom": "6px", "color": "#64748b", "fontSize": "14px"}}>Email:</label>
#                     <input
#                         type="email"
#                         value={email}
#                         onChange={lambda e: any -> None { setEmail(e.target.value); }}
#                         style={{"width": "100%", "padding": "8px", "borderRadius": "6px", "border": "1px solid #cbd5e1", "boxSizing": "border-box"}}
#                         placeholder="Enter email"
#                     />
#                 </div>

#                 <div style={{"marginBottom": "12px"}}>
#                     <label style={{"display": "block", "marginBottom": "6px", "color": "#64748b", "fontSize": "14px"}}>Role:</label>
#                     <select
#                         value={role}
#                         onChange={lambda e: any -> None { setRole(e.target.value); }}
#                         style={{"width": "100%", "padding": "8px", "borderRadius": "6px", "border": "1px solid #cbd5e1"}}>
#                         <option value="Developer">Developer</option>
#                         <option value="Designer">Designer</option>
#                         <option value="Manager">Manager</option>
#                     </select>
#                 </div>

#                 <button
#                     type="submit"
#                     disabled={isLoading or not name or not email}
#                     style={{"width": "100%", "padding": "10px", "backgroundColor": isLoading and "#cbd5e1" or "#22c55e", "color": "white", "border": "none", "borderRadius": "6px", "cursor": isLoading and "not-allowed" or "pointer", "fontWeight": "600"}}>
#                     {isLoading and "Creating..." or "Create User"}
#                 </button>
#             </form>

#             {isSuccess and
#                 <div style={{"marginTop": "12px", "padding": "10px", "backgroundColor": "#d4edda", "color": "#155724", "borderRadius": "6px", "fontSize": "14px"}}>
#                     ✅ User created successfully!
#                 </div>
#             }

#             {error and
#                 <div style={{"marginTop": "12px", "padding": "10px", "backgroundColor": "#f8d7da", "color": "#721c24", "borderRadius": "6px", "fontSize": "14px"}}>
#                     ❌ Error: {error.message}
#                 </div>
#             }
#         </div>;
#     }

#     # ===== COMPONENT: Query Cache Info =====
#     def QueryInfo() -> any {
#         return <div style={{"padding": "15px", "backgroundColor": "#0f172a", "borderRadius": "12px", "marginTop": "20px"}}>
#             <h4 style={{"margin": "0 0 10px", "color": "#e2e8f0", "fontSize": "14px"}}>✨ Pure Jac Implementation</h4>
#             <div style={{"fontSize": "12px", "color": "#94a3b8"}}>
#                 <div>• No .js helper files needed!</div>
#                 <div>• QueryClient, Promise, Error - all constructed in Jac</div>
#                 <div>• Compiler automatically handles constructors</div>
#                 <div>• Full React Query power in pure Jac syntax 🚀</div>
#             </div>
#         </div>;
#     }

#     # ===== MAIN APP COMPONENT =====
#     def app() -> any {

#         return <QueryClientProvider client={queryClient}>
#             <main style={{"minHeight": "100vh", "backgroundColor": "#f8fafc", "padding": "40px", "fontFamily": "system-ui, sans-serif"}}>
#                 <div style={{"maxWidth": "1000px", "margin": "0 auto"}}>
#                     <header style={{"marginBottom": "30px"}}>
#                         <p style={{"margin": "0 0 6px", "textTransform": "uppercase", "color": "#94a3b8", "letterSpacing": "0.2em", "fontSize": "12px"}}>
#                             React Query in Pure Jac
#                         </p>
#                         <h1 style={{"margin": "0", "fontSize": "36px", "color": "#0f172a"}}>
#                             Data Fetching Made Easy
#                         </h1>
#                         <p style={{"marginTop": "8px", "color": "#64748b"}}>
#                             useQuery, useMutation, caching, and automatic refetching - all in pure Jac!
#                         </p>
#                     </header>

#                     <div style={{"display": "grid", "gridTemplateColumns": "1fr 1fr", "gap": "20px", "marginBottom": "20px"}}>
#                         <UsersList />
#                         <div style={{"display": "grid", "gap": "20px"}}>
#                             <UserDetail />
#                             <CreateUserForm />
#                         </div>
#                     </div>

#                     <QueryInfo />
#                 </div>
#             </main>
#         </QueryClientProvider>;
#     }

# }
