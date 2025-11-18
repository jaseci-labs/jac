# Complete LittleX - A Twitter-like Social Media Application

A full-stack social media application built with Jac language, featuring real-time feeds, user interactions, and intelligent tweet search using TF-IDF similarity.

## Overview

LittleX is a Twitter-clone application that demonstrates the power of Jac's graph-based data structures and seamless frontend-backend integration. The application uses a graph database model where users, tweets, and interactions are represented as nodes and edges.

## Application Architecture

### Core Files

- **`app.jac`** - Main application file containing:
  - Data models (Profile, Tweet, Comment nodes)
  - Walkers for business logic
  - React components for the UI
- **`app.impl.jac`** - Implementation file containing:

  - Walker ability implementations
  - Node behavior implementations
  - Graph traversal logic

- **`service.jac`** - Service layer providing:

  - API calls to backend walkers
  - Authentication helpers
  - Data transformation utilities

- **`customhooks.jac`** - React custom hooks:

  - `useAuth()` - Authentication state management
  - `useFeed()` - Feed page state and logic
  - `useProfile()` - Profile page state and logic

- **`components.jac`** - Reusable UI components

## How It Works

### 1. Application Entry Point

The application starts when you run:

```bash
jac serve app.jac
```

This command:

- Compiles the Jac code
- Starts the backend graph database server
- Serves the React frontend application
- Establishes the connection between frontend and backend

### 2. Graph Data Model

The application uses a graph-based data structure:

**Nodes:**

- `Profile` - User profiles with username
- `Tweet` - Individual tweets with content, embeddings, and timestamps
- `Comment` - Comments on tweets

**Edges:**

- `Follow` - Represents follower relationships between profiles
- `Like` - Represents likes from profiles to tweets
- `Post` - Connects profiles to their tweets/comments

### 3. Application Flow

#### Authentication Flow

1. User lands on `/auth` page (AuthPage component)
2. User can login or signup using `useAuth()` hook
3. `service.jac` calls `jacLogin()` or `jacSignup()`
4. On success, user is redirected to `/feed`
5. Backend creates/retrieves Profile node via `visit_profile` walker

#### Feed Flow

1. `FeedPage` component mounts and calls `useFeed()` hook
2. Hook loads initial data:

   - Fetches user profile via `get_profile` walker
   - Loads feed via `load_feed` walker
   - Retrieves all users via `load_user_profiles` walker

3. **Loading Feed (`load_feed` walker)**:

   - Visits all tweets from current user's profile
   - Traverses Follow edges to get followed users
   - Visits all tweets from followed users
   - Calculates TF-IDF similarity for search queries
   - Returns sorted tweets by relevance

4. **Creating Tweets**:

   - User types content in TweetComposer
   - Calls `handleCreateTweet()` → `createTweet()` in service
   - Backend `create_tweet` walker:
     - Creates Tweet node with TF-IDF embedding
     - Connects to Profile via Post edge
     - Grants permissions
     - Returns tweet info

5. **Interactions**:

   - **Like**: Creates Like edge between Tweet and Profile
   - **Comment**: Creates Comment node, connects to Tweet
   - **Follow**: Creates Follow edge between Profiles
   - **Edit/Delete**: Updates or removes nodes

6. **Search Feature**:
   - User enters search query in SearchBar component
   - Calls `handleSearch()` which triggers `loadFeed(searchQuery)`
   - Backend calculates TF-IDF similarity scores for each tweet
   - Results sorted by cosine similarity (most relevant first)
   - UI shows ranked results with search indicator
   - "Clear" button resets to full feed
   - See [SEARCH_FEATURE.md](./SEARCH_FEATURE.md) for detailed documentation

#### Search Functionality

- Uses TF-IDF (Term Frequency-Inverse Document Frequency) vectorization
- Calculates cosine similarity between search query and tweet content
- Ranks tweets by similarity score
- Provides semantic search capabilities

### 4. Walker Pattern

Walkers are Jac's way of traversing and operating on the graph:

**Example: `create_tweet` walker**

```
User Action → Service Call → Walker Spawn → Graph Operation → Report Result
```

1. Frontend calls `createTweet(content)` in service.jac
2. Service spawns `create_tweet` walker on Profile node
3. Walker ability `tweet` executes:
   - Generates TF-IDF embedding
   - Creates Tweet node
   - Connects via Post edge
   - Grants permissions
4. Returns TweetInfo to frontend
5. Frontend updates UI state

### 5. State Management

**React Hooks Pattern:**

- Custom hooks (`useAuth`, `useFeed`, `useProfile`) manage component state
- Separate business logic from UI rendering
- Handle async operations and data fetching
- Provide clean API for components

**Backend Graph State:**

- All data persists in graph structure
- Relationships are first-class citizens (edges)
- Efficient traversal for feed generation
- Built-in permission system

### 6. Component Hierarchy

```
App (Router)
├── AuthPage
│   ├── FormInput
│   └── AuthButton
├── FeedPage
│   ├── Header
│   ├── SearchBar (NEW!)
│   ├── TweetComposer
│   └── TweetCard[]
│       ├── CommentInput
│       └── CommentList
│           └── CommentItem[]
└── ProfilePage
    ├── Header
    ├── ProfileHeader
    └── UsersList
        └── UserCard[]
```

## Running the Application

### Prerequisites

```bash
# Install Node.js dependencies
npm install

# Ensure Jac CLI is installed
pip install jaclang
```

### Development

```bash
# Start the application
jac serve app.jac

# The app will be available at http://localhost:8000/page/app
```

### Usage

1. Navigate to `http://localhost:8000/page/app`
2. Sign up with a username and password
3. Create tweets, follow users, and interact with content
4. Use search to find relevant tweets

## Development Workflow

1. **Modify Data Model**: Update nodes/edges in `app.jac`
2. **Implement Logic**: Add walker abilities in `app.impl.jac`
3. **Update Services**: Expose new functionality in `service.jac`
4. **Create UI**: Build components in `components.jac`
5. **Wire Together**: Use hooks in `customhooks.jac`

Happy coding with Jac! 🚀
