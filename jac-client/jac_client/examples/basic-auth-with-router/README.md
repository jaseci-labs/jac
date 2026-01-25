# Basic Authentication with React Router

A complete authentication example using Jac with React Router for client-side routing.

## Features

- **React Router Integration** - Hash-based routing using `react-router-dom` v6
- **User Authentication** - Login and signup functionality
- ️ **Protected Routes** - Dashboard page accessible only to authenticated users
- **Modern UI** - Clean, responsive design
- **Navigation Guards** - Automatic redirects for unauthenticated users
- **LocalStorage Session** - Persistent authentication state

## React Router Features Demonstrated

- `HashRouter` for hash-based routing (`#/login`, `#/dashboard`)
- `useNavigate()` hook for programmatic navigation
- `useLocation()` hook for accessing current location
- `<Navigate />` component for conditional redirects
- `<Link />` component for declarative navigation
- `<Routes />` and `<Route />` for route definitions

## Setup

Install dependencies:

```bash
bun install
```

## Running the App

Start the development server:

```bash
jac start app.jac
```

Then open your browser to `http://localhost:8000`

## Usage

1. **Sign Up**: Create a new account at `#/signup`
2. **Login**: Access your account at `#/login`
3. **Dashboard**: View protected content at `#/dashboard` (requires login)
4. **Logout**: Click the logout button in the navigation

## Project Structure

- `app.jac` - Main application with routing and authentication logic
- `package.json` - Dependencies including `react-router-dom` v6.30.1
- Session files - User data and tokens stored locally

## Authentication Flow

1. User signs up or logs in
2. Token stored in localStorage
3. Navigation redirects to dashboard
4. Protected routes check authentication status
5. Unauthenticated access redirects to login

Happy coding with Jac!
