
# React Hook Form + Zod + Zustand Example
cl import from react { useState }
cl import from "react-hook-form" { useForm }
cl import from "@hookform/resolvers/zod" { zodResolver }
cl import from .schema {
    registrationSchema,
    loginSchema,
    # profileSchema,
    contactSchema
}
cl import from .formStore { useFormStore }

cl {
    # Registration Form Component
    def RegistrationForm() -> any {
        let registerUser = useFormStore(lambda state: any -> any { return state.registerUser; });
        let [submitted, setSubmitted] = useState(False);

        let form = useForm({
            "resolver": zodResolver(registrationSchema()),
            "defaultValues": {
                "username": "",
                "email": "",
                "password": "",
                "confirmPassword": "",
                "age": 0,
                "agreedToTerms": False
            }
        });

        let register = form.register;
        let handleSubmit = form.handleSubmit;
        let formState = form.formState;
        let errors = formState.errors;
        let reset = form.reset;

        let onSubmit = lambda data: any -> None {
            console.log("Registration Data:", data);
            registerUser(data);
            setSubmitted(True);
            reset();
        };
        console.log("Form State:", formState);
        console.log("Form Errors:", errors);
        return <div style={{"border": "2px solid #3b82f6", "borderRadius": "12px", "padding": "24px", "backgroundColor": "white"}}>
            <h2 style={{"margin": "0 0 20px", "color": "#1e40af"}}>📝 Registration Form</h2>

            {submitted && (
                <div style={{"padding": "12px", "backgroundColor": "#d1fae5", "border": "1px solid #10b981", "borderRadius": "8px", "marginBottom": "20px", "color": "#065f46"}}>
                    ✅ Registration successful! Check the State Debug panel below.
                </div>
            )}

            <form onSubmit={handleSubmit(onSubmit)}>
                # Username
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Username *
                    </label>
                    <input
                        # JavaScript
                        # {...register("username")}

                        # Python equivalent
                        {...register("username")}
                        placeholder="Enter username"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.username && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.username.message}
                        </p>
                    )}
                </div>

                # Email
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Email *
                    </label>
                    <input
                        {...register("email")}
                        type="email"
                        placeholder="your@email.com"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.email && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.email.message}
                        </p>
                    )}
                </div>

                # Password
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Password *
                    </label>
                    <input
                        {...register("password")}
                        type="password"
                        placeholder="Min 8 chars, 1 uppercase, 1 number"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.password && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.password.message}
                        </p>
                    )}
                </div>

                # Confirm Password
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Confirm Password *
                    </label>
                    <input
                        {...register("confirmPassword")}
                        type="password"
                        placeholder="Re-enter password"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.confirmPassword && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.confirmPassword.message}
                        </p>
                    )}
                </div>

                # Age
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Age *
                    </label>
                    <input
                        {...register("age", {"valueAsNumber": True})}
                        type="number"
                        placeholder="Your age"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.age && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.age.message}
                        </p>
                    )}
                </div>

                # Agree to Terms
                <div style={{"marginBottom": "20px"}}>
                    <label style={{"display": "flex", "alignItems": "center", "gap": "8px", "cursor": "pointer"}}>
                        <input
                            {...register("agreedToTerms")}
                            type="checkbox"
                        />
                        <span style={{"fontSize": "14px", "color": "#374151"}}>
                            I agree to the terms and conditions *
                        </span>
                    </label>
                    {errors.agreedToTerms && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.agreedToTerms.message}
                        </p>
                    )}
                </div>

                <button
                    type="submit"
                    style={{"width": "100%", "padding": "12px", "backgroundColor": "#3b82f6", "color": "white", "border": "none", "borderRadius": "6px", "fontSize": "16px", "fontWeight": "600", "cursor": "pointer"}}
                >
                    Register
                </button>
            </form>
        </div>;
    }

    # Login Form Component
    def LoginForm() -> any {
        let loginUser = useFormStore(lambda state: any -> any { return state.loginUser; });
        let isLoggedIn = useFormStore(lambda state: any -> any { return state.isLoggedIn; });
        let currentUser = useFormStore(lambda state: any -> any { return state.currentUser; });
        let logoutUser = useFormStore(lambda state: any -> any { return state.logoutUser; });

        let form = useForm({
            "resolver": zodResolver(loginSchema()),
            "defaultValues": {
                "email": "",
                "password": "",
                "rememberMe": False
            }
        });

        let register = form.register;
        let handleSubmit = form.handleSubmit;
        let errors = form.formState.errors;

        let onSubmit = lambda data: any -> None {
            console.log("Login Data:", data);
            loginUser(data);
        };


        if isLoggedIn {
            return <div style={{"border": "2px solid #10b981", "borderRadius": "12px", "padding": "24px", "backgroundColor": "#d1fae5"}}>
                <h2 style={{"margin": "0 0 20px", "color": "#065f46"}}>✅ Logged In</h2>
                <p style={{"margin": "0 0 16px", "color": "#065f46"}}>
                    Welcome, {currentUser.username or currentUser.email}!
                </p>
                <button
                    onClick={lambda e: any -> None { logoutUser(); }}
                    style={{"padding": "10px 20px", "backgroundColor": "#dc2626", "color": "white", "border": "none", "borderRadius": "6px", "cursor": "pointer"}}
                >
                    Logout
                </button>
            </div>;
        }

        return <div style={{"border": "2px solid #8b5cf6", "borderRadius": "12px", "padding": "24px", "backgroundColor": "white"}}>
            <h2 style={{"margin": "0 0 20px", "color": "#6d28d9"}}>🔐 Login Form</h2>

            <form onSubmit={handleSubmit(onSubmit)}>
                # Email
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Email *
                    </label>
                    <input
                        {...register("email")}
                        type="email"
                        placeholder="your@email.com"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.email && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.email.message}
                        </p>
                    )}
                </div>

                # Password
                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Password *
                    </label>
                    <input
                        {...register("password")}
                        type="password"
                        placeholder="Enter your password"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.password && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.password.message}
                        </p>
                    )}
                </div>

                # Remember Me
                <div style={{"marginBottom": "20px"}}>
                    <label style={{"display": "flex", "alignItems": "center", "gap": "8px", "cursor": "pointer"}}>
                        <input
                            {...register("rememberMe")}
                            type="checkbox"
                        />
                        <span style={{"fontSize": "14px", "color": "#374151"}}>
                            Remember me
                        </span>
                    </label>
                </div>

                <button
                    type="submit"
                    style={{"width": "100%", "padding": "12px", "backgroundColor": "#8b5cf6", "color": "white", "border": "none", "borderRadius": "6px", "fontSize": "16px", "fontWeight": "600", "cursor": "pointer"}}
                >
                    Login
                </button>
            </form>

            <p style={{"marginTop": "16px", "fontSize": "12px", "color": "#6b7280", "textAlign": "center"}}>
                💡 Tip: Register first, then login with the same email
            </p>
        </div>;
    }

    # Contact Form Component
    def ContactForm() -> any {
        let submitContactMessage = useFormStore(lambda state: any -> any { return state.submitContactMessage; });
        let [submitted, setSubmitted] = useState(False);

        let form = useForm({
            "resolver": zodResolver(contactSchema()),
            "defaultValues": {
                "name": "",
                "email": "",
                "subject": "",
                "message": "",
                "category": ""
            }
        });

        let register = form.register;
        let handleSubmit = form.handleSubmit;
        let errors = form.formState.errors;
        let reset = form.reset;

        let onSubmit = lambda data: any -> None {
            console.log("Contact Data:", data);
            submitContactMessage(data);
            setSubmitted(True);
            reset();
        };

        console.log("Form Errors:", errors);
        console.log("Form State:", form.formState);

        return <div style={{"border": "2px solid #f59e0b", "borderRadius": "12px", "padding": "24px", "backgroundColor": "white"}}>
            <h2 style={{"margin": "0 0 20px", "color": "#d97706"}}>📧 Contact Form</h2>

            {submitted && (
                <div style={{"padding": "12px", "backgroundColor": "#fef3c7", "border": "1px solid #f59e0b", "borderRadius": "8px", "marginBottom": "20px", "color": "#92400e"}}>
                    ✅ Message sent successfully!
                </div>
            )}

            <form onSubmit={handleSubmit(onSubmit)}>

                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Name *
                    </label>
                    <input
                        {...register("name")}
                        placeholder="Your name"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.name && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.name.message}
                        </p>
                    )}
                </div>


                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Email *
                    </label>
                    <input
                        {...register("email")}
                        type="email"
                        placeholder="your@email.com"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.email && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.email.message}
                        </p>
                    )}
                </div>


                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Category *
                    </label>
                    <select
                        {...register("category")}
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    >
                        <option value="">Select category</option>
                        <option value="general">General</option>
                        <option value="support">Support</option>
                        <option value="feedback">Feedback</option>
                        <option value="bug">Bug Report</option>
                    </select>
                    {errors.category && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.category.message}
                        </p>
                    )}
                </div>


                <div style={{"marginBottom": "16px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Subject *
                    </label>
                    <input
                        {...register("subject")}
                        placeholder="Brief subject"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px"}}
                    />
                    {errors.subject && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.subject.message}
                        </p>
                    )}
                </div>


                <div style={{"marginBottom": "20px"}}>
                    <label style={{"display": "block", "marginBottom": "6px", "fontWeight": "600", "color": "#374151"}}>
                        Message *
                    </label>
                    <textarea
                        {...register("message")}
                        rows={4}
                        placeholder="Your message (10-500 characters)"
                        style={{"width": "100%", "padding": "10px", "border": "1px solid #d1d5db", "borderRadius": "6px", "fontSize": "14px", "fontFamily": "inherit"}}
                    />
                    {errors.message && (
                        <p style={{"margin": "4px 0 0", "color": "#dc2626", "fontSize": "12px"}}>
                            {errors.message.message}
                        </p>
                    )}
                </div>

                <button
                    type="submit"
                    style={{"width": "100%", "padding": "12px", "backgroundColor": "#f59e0b", "color": "white", "border": "none", "borderRadius": "6px", "fontSize": "16px", "fontWeight": "600", "cursor": "pointer"}}
                >
                    Send Message
                </button>
            </form>
        </div>;
    }

    # State Debugger Component
    def StateDebugger() -> any {
        let fullState = useFormStore();
        let clearAllData = useFormStore(lambda state: any -> any { return state.clearAllData; });

        return <div style={{"marginTop": "30px", "border": "2px solid #1f2937", "borderRadius": "12px", "padding": "20px", "backgroundColor": "#111827"}}>
            <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "marginBottom": "16px"}}>
                <h3 style={{"margin": "0", "color": "#f3f4f6"}}>
                    🔍 Zustand Store State
                </h3>
                <button
                    onClick={lambda e: any -> None { clearAllData(); }}
                    style={{"padding": "8px 16px", "backgroundColor": "#dc2626", "color": "white", "border": "none", "borderRadius": "6px", "fontSize": "12px", "cursor": "pointer"}}
                >
                    Clear All Data
                </button>
            </div>

            <details open={True}>
                <summary style={{"cursor": "pointer", "color": "#9ca3af", "marginBottom": "12px"}}>
                    View Full State
                </summary>
                <pre style={{"margin": "0", "padding": "16px", "backgroundColor": "#1f2937", "borderRadius": "8px", "color": "#d1d5db", "fontSize": "12px", "overflowX": "auto", "maxHeight": "400px"}}>
                    {JSON.stringify(fullState, None, 2)}
                </pre>
            </details>
        </div>;
    }

    # Main App
    def app() -> any {
        return <main style={{"minHeight": "100vh", "backgroundColor": "#f9fafb", "padding": "40px", "fontFamily": "system-ui, -apple-system, sans-serif"}}>
            <div style={{"maxWidth": "1200px", "margin": "0 auto"}}>
                <header style={{"marginBottom": "40px", "textAlign": "center"}}>
                    <h1 style={{"margin": "0 0 12px", "fontSize": "42px", "color": "#111827"}}>
                        📋 React Hook Form + Zod + Zustand
                    </h1>
                    <p style={{"margin": "0", "color": "#6b7280", "fontSize": "18px"}}>
                        Complete form handling example in OneLang/Jac
                    </p>
                </header>

                <div style={{"display": "grid", "gridTemplateColumns": "repeat(auto-fit, minmax(400px, 1fr))", "gap": "24px", "marginBottom": "30px"}}>
                    <RegistrationForm />
                    <LoginForm />
                </div>

                <div style={{"maxWidth": "600px", "margin": "0 auto 30px"}}>
                    <ContactForm />
                </div>

                <StateDebugger />

                <footer style={{"marginTop": "40px", "padding": "20px", "backgroundColor": "#eff6ff", "border": "1px solid #3b82f6", "borderRadius": "12px", "color": "#1e40af"}}>
                    <h4 style={{"margin": "0 0 12px", "fontSize": "16px"}}>✨ Features Demonstrated:</h4>
                    <ul style={{"margin": "0", "paddingLeft": "20px", "fontSize": "14px", "lineHeight": "1.8"}}>
                        <li><strong>React Hook Form</strong> - Form state management and validation</li>
                        <li><strong>Zod Schemas</strong> - Type-safe validation with detailed error messages</li>
                        <li><strong>Zustand Store</strong> - Global state management  form submissions</li>
                        <li><strong>OneLang Patterns</strong> - Spread operator, lambda functions, conditional rendering</li>
                        <li><strong>Form Types</strong> - Registration, login, contact with various input types</li>
                    </ul>
                </footer>
            </div>
        </main>;
    }
}
