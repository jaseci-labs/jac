# Tutorial
# Build Your First Social Media App with Jaseci

You'll build **LittleX**, a Twitter-like application, in just 200 lines of code. This tutorial guides you through each step, from installation to deployment.

---

## What You'll Learn

By the end of this tutorial, you'll understand how to:

- **Store data** in connected graph structures
- **Navigate** through relationships between data
- **Add AI features** to your application
- **Deploy** a working social media platform

---

## What You'll Build: LittleX

**LittleX** lets users:

- Create accounts and profiles
- Post messages (tweets)
- Follow other users
- View a personalized feed

### Complete Code Preview

Here's what you'll build - just **200 lines of code** for a full social media platform:

=== "Frontend Preview"
    ![LittleX Frontend](src/front_end.png)

=== "LittleX.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/littleX/src/littleX.jac:17:125"
    ```

=== "LittleX.impl.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/littleX/src/littleX.impl.jac:9:121"
    ```

=== "LittleX.test.jac"
    ```jac linenums="1"
    --8<-- "docs/learn/examples/littleX/src/littleX.test.jac:1:88"
    ```

---

## Before You Start

You'll need:

- **15 minutes** to complete this tutorial
- **Python 3.12 or later** installed
- A text editor or IDE

---

## Step 1: Install Jaseci

Install the required libraries:

```bash
pip install jac_cloud
```

If the install is successful, you'll see:
```
Successfully installed jac_cloud
```

You're ready to start building!

---

## Step 2: Get the Code

Clone the repository:

```bash
git clone https://github.com/Jaseci-Labs/littleX.git
cd littleX
```

Install dependencies:

```bash
# Backend dependencies
pip install -r littleX_BE/requirements.txt

# Frontend dependencies
cd littleX_FE
npm install
cd ..
```

---

## Understanding Jaseci's Building Blocks

Jaseci uses **three main components** to build applications. Let's see how they work together:

### File Structure: Three Files, One Application

Jaseci organizes code into three files that work together automatically:

#### **littleX.jac** - What Your App Has
```jac
# Define what exists
node Profile {
    has username: str;
    can update with update_profile entry;
}
```

#### **littleX.impl.jac** - How Your App Works
```jac
# Define how things work
impl Profile.update {
    self.username = here.new_username;
    report self;
}
```

#### **littleX.test.jac** - Proving It Works
```jac
# Test functionality
test create_tweet {
    root spawn create_tweet(content = "Hello World");
    tweet = [root --> (?Profile) --> (?Tweet)][0];
    check tweet.content == "Hello World";
}
```

### Running Your Code

Jaseci automatically links these files:

```bash
# Run the application
jac run littleX.jac

# Run tests
jac test littleX.jac

# Start API server
jac serve littleX.jac
```

### 1. Nodes: Store Your Data

**Nodes** hold information. In LittleX:

- **Profile nodes** store user information
- **Tweet nodes** store message content
- **Comment nodes** store replies

**Simple Example:**
```jac
node User {
    has username: str;
}
```

This creates a user object with a username.

### 2. Edges: Connect Your Data

**Edges** create relationships between nodes. In LittleX:

- **Follow edges** connect users who follow each other
- **Post edges** connect users to their tweets
- **Like edges** connect users to tweets they liked

**Simple Example:**
```jac
edge Follow {}
```

This creates a "Follow" connection between users.

### 3. Walkers: Make Things Happen

**Walkers** move through your graph and perform actions. They make your app interactive.

**Simple Example:**
```jac
walker create_tweet(visit_profile) {
    has content: str;
    can tweet with Profile entry;
}
```

This walker creates new tweets when users post messages.

---

## Build LittleX Step by Step

Now let's build your social media app by combining these pieces:

### Step 3: Create User Profiles

When someone signs up, we create their profile:

```jac
walker visit_profile {
    can visit_profile with `root entry;
}

impl visit_profile.visit_profile {
    visit [-->(`?Profile)] else {
        new_profile = here ++> Profile();
        grant(new_profile[0], level=ConnectPerm);
        visit new_profile;
    }
}
```

**What this does:** Creates a new profile if one doesn't exist, or visits the existing profile.

### Step 4: Post Messages

Users can create and share posts:

```jac
walker create_tweet(visit_profile) {
    has content: str;
    can tweet with Profile entry;
}

impl create_tweet.tweet {
    embedding = sentence_transformer.encode(self.content).tolist();
    tweet_node = here +>:Post:+> Tweet(content=self.content, embedding=embedding);
    grant(tweet_node[0], level=ConnectPerm);
    report tweet_node;
}
```

**What this does:** Creates a new tweet with the user's message and connects it to their profile.

### Step 5: Follow Other Users

Build your network by following others:

```jac
walker follow_request {}

impl Profile.follow {
    current_profile = [root-->(`?Profile)];
    current_profile[0] +>:Follow():+> self;
    report self;
}
```

**What this does:** Creates a follow relationship between the current user and another user.

### Step 6: View Your Feed

See posts from people you follow:

```jac
walker load_feed(visit_profile) {
    has search_query: str = "";
    has results: list = [];
    can load with Profile entry;
}

impl load_feed.load {
    visit [-->(`?Tweet)];
    for user_node in [->:Follow:->(`?Profile)] {
        visit [user_node-->(`?Tweet)];
    }
    report self.results;
}
```

**What this does:** Collects tweets from the current user and everyone they follow.

---

## Step 7: Run Your App

Let's see your social media platform in action:

### Start the Backend

```bash
jac serve littleX_BE/littleX.jac
```

You should see:
```
INFO: Uvicorn running on http://127.0.0.1:8000
```

Your backend is running!

### Start the Frontend

Open a new terminal:

```bash
cd littleX_FE
npm run dev
```

You should see:
```
Local: http://localhost:5173/
```

Your frontend is ready!

### Try Your App

1. **Open your browser** to: [`http://localhost:5173`](http://localhost:5173)

2. **Test these features**

    - Create an account
    - Post a message
    - Follow someone
    - Check your feed

If everything works, you've successfully built a social media platform!

---

## Key Code Components

Let's examine the main parts of your LittleX app:

### Profile Node
```jac
node Profile {
    has username: str = "";

    can update with update_profile entry;
    can get with get_profile entry;
    can follow with follow_request entry;
    can un_follow with un_follow_request entry;
}
```

This stores user information and defines what users can do.

### Tweet Node
```jac
node Tweet {
    has content: str;
    has embedding: list;
    has created_at: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S");

    can update with update_tweet exit;
    can delete with remove_tweet exit;
    can like_tweet with like_tweet entry;
    can remove_like with remove_like entry;
    can comment with comment_tweet entry;

    def get_info() -> TweetInfo;
    can get with load_feed entry;
}
```

This stores tweet content and handles all tweet interactions.

### Follow Implementation
```jac
impl Profile.follow {
    current_profile = [root-->(`?Profile)];
    current_profile[0] +>:Follow():+> self;
    report self;
}
```

This creates the follow relationship between users.

---

## Try These Extensions

Ready to add more features? Try implementing:

1. **Like system** for posts
2. **User search** by username
3. **Comment replies** for deeper conversations
4. **Profile pages** showing user-specific content

---

## What You've Accomplished

You've built a complete social media application. You now understand:

- **Nodes** for storing data
- **Edges** for connecting information
- **Walkers** for creating functionality

Jaseci's graph-based approach works well for social networks where relationships between data are essential.

---

## Next Steps

Ready to build more? Explore these resources:

- [**Jaseci Documentation**](https://jac-lang.org/) - Complete guides and references
- [**Full LittleX Guide**](full_guide.md) - Advanced features and enterprise patterns

You're ready to build your own graph-based applications!

> **Happy coding with Jaseci!** 🚀
