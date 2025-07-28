# Chapter 13: Multi-User Architecture and Permissions
---
In this chapter, we'll explore how to build secure, multi-user applications in Jac Cloud. We'll develop a shared notebook system that demonstrates user isolation, permission systems, and access control strategies through practical examples that evolve throughout the chapter.

!!! info "What You'll Learn"
    - Building secure multi-user applications
    - User isolation and data privacy patterns
    - Permission-based access control
    - Shared data management strategies
    - Security considerations for cloud applications



## User Isolation and Permission Systems
---
Multi-user applications require careful consideration of data access and user permissions. Jac provides built-in patterns for user management that integrate seamlessly with your application logic, allowing you to focus on business rules rather than authentication infrastructure.


- **User Context**: Access to user information in walkers
- **Data Isolation**: Users can only access their authorized data
- **Flexible Permissions**: Fine-grained access control patterns
- **Secure by Default**: Application-level security patterns
- **Shared Data Support**: Controlled sharing between users


### Building a Simple Multi-User Application
---

Modern applications often need to handle multiple users, each with their own data and permissions. Even something as simple as a personal notes application changes significantly when multiple users are involved. Instead of a single user owning all notes, we need to track who created what, and ensure that users only see and manage their own content.

In this chapter, we’ll explore how to build a basic multi-user application in Jac. We will:

- Model users and their notes as separate entities.
- Create relationships between users and the notes they own.
- Write walkers to handle adding and listing notes for specific users.
- Lay the foundation for advanced topics like permissions, sharing, and roles.




### Desigining the Data Model
We need three key pieces for our notebook system:

1. **User Node** – stores user-specific information like an email address and unique ID.
2. **Note Node** – stores note details including a title and content.
3. **CreatedBy Edge** – links each note to the user who created it, while storing when it was created.

In Jac, we can represent this as follows:

```jac
import from uuid { uuid4 }
import from datetime { datetime }

node User {
    has email: str;
    has id: str = str(uuid4());
}

node Note {
    has title: str;
    has content: str = "";
    has id: str = str(uuid4());
}

edge CreatedBy {
    has created_at: str by postinit;

    def postinit() {
        self.created_at = datetime.now().isoformat();
    }
}
```
<br />

### Initializing Users

When the system starts, we want at least some sample users to work with. In production, you would typically have a user registration system, where the users would be stored in a database. For our example, we can create a few users directly in the Jac code.

```jac
# Base walker to initialize demo users and helper functions
walker NoteWalker {
    def postinit() {
        users = [root ->:has_user:->(`?User)];
        if not users {
            self.create_users();
        }
    }

    obj __specs__ {
        static has auth: bool = False;
    }

    # Create demo users if none exist
    def create_users() -> None {
        user1 = User(email="user1@example.com");
        user2 = User(email="user2@example.com");
        root +>:has_user:+> user1;
        root +>:has_user:+> user2;
    }

    # Helper function to get user by email
    def get_user(email: str) -> User {
        user = [root ->:has_user:->(`?User)](?email == email);
        if not user {
            raise Exception();
        }
        return user[0];
    }
}
```
<br />

When the `NoteWalker` is initialized, we first check if there are any users connected to our graph. If not, we create two demo users and add them to the root node. This ensures that our application has users to work with right from the start.

### Working With Notes
Next, we’ll create two walkers:

- `add_note`: Adds a note for a specific user.
- `list_notes`: Lists all notes created by a specific user.

This small feature set is enough to demonstrate:

- Multi-user ownership of data.
- Traversing graph edges to find user-specific content.
- Returning structured responses for a REST API.

#### Creating Notes
The `add_note` walker allows users to create notes by specifying their email, title, and content. It first retrieves the user based on the provided email, and if the user exists, it creates a new note and links it to the user using the `CreatedBy` edge. If the user is not found, it reports an error.

```jac
walker add_note(NoteWalker){
    has email: str;
    has title: str;
    has content: str = "";

    can create with `root entry {
        try {
            user = self.get_user(self.email);
        }
        except Exception as e {
            report {
                "error": f"User with email {self.email} not found."
            };
            disengage;
        }

        note = Note(title=self.title, content=self.content);
        user <+:CreatedBy:<+ note;

        report {
            "message": "Note created successfully."
        };
    }
}
```

#### Listing Notes
The `list_notes` walker retrieves all notes created by a specific user. It uses the `CreatedBy` edge to find notes linked to the user. If no notes are found, it reports a message indicating that. If notes are found, it returns the list of notes along with the user's email.

```jac
walker list_notes(NoteWalker) {
    has email: str;

    can list with `root entry {
        try {
            user = self.get_user(self.email);
        }
        except Exception as e {
            report {
                "error": f"User with email {self.email} not found."
            };
            disengage;
        }

        notes = [user <-:CreatedBy:<-(`?Note)];

        if not notes {
            report {
                "message": f"No notes found for {self.email}."
            };
        }else{
            report {
                "notes": notes,
                "user_email": user.email
            };
        }
    }
}
```



### Putting It All Together
Now we can create a simple user-aware application that allows users to create and list their notes.
```jac
# user_notebook.jac
import from uuid { uuid4 }
import from datetime { datetime }


node User {
    has email: str;
    has id: str = str(uuid4());
}

node Note {
    has title: str;
    has content: str = "";
    has id: str = str(uuid4());
}

# Edge representing the creation relationship between users and notes
edge CreatedBy {
    has created_at: str by postinit;

    def postinit() {
        self.created_at = datetime.now().isoformat();
    }
}

# Root's edge to connect users
edge has_user {}

# Parent NoteWalker to manage note operations
walker NoteWalker {
    def postinit() {
        users = [root ->:has_user:->(`?User)];
        if not users {
            self.create_users();
        }
    }

    obj __specs__ {
        static has auth: bool = False;
    }

    # Create demo users if none exist
    def create_users() -> None {
        user1 = User(email="user1@example.com");
        user2 = User(email="user2@example.com");
        root +>:has_user:+> user1;
        root +>:has_user:+> user2;
    }

    # Helper function to get user by email
    def get_user(email: str) -> User {
        user = [root ->:has_user:->(`?User)](?email == email);
        if not user {
            raise Exception();
        }
        return user[0];
    }
}

walker add_note(NoteWalker){
    has email: str;
    has title: str;
    has content: str = "";

    can create with `root entry {
        try {
            user = self.get_user(self.email);
        }
        except Exception as e {
            report {
                "error": f"User with email {self.email} not found."
            };
            disengage;
        }

        note = Note(title=self.title, content=self.content);
        user <+:CreatedBy:<+ note;

        report {
            "message": "Note created successfully."
        };
    }
}

walker list_notes(NoteWalker) {
    has email: str;

    can list with `root entry {
        try {
            user = self.get_user(self.email);
        }
        except Exception as e {
            report {
                "error": f"User with email {self.email} not found."
            };
            disengage;
        }

        notes = [user <-:CreatedBy:<-(`?Note)];

        if not notes {
            report {
                "message": f"No notes found for {self.email}."
            };
        }else{
            report {
                "notes": notes,
                "user_email": user.email
            };
        }
    }
}

```

### Deploying and Testing

Deploy your user-aware application:

```bash
jac serve user_notebook.jac
```

### Testing User Authentication

```bash
# Create a note for user1
curl -X POST http://localhost:8000/walker/add_note \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user1@example.com",
    "title": "User1 Note",
    "content": "This is a note for user1."
  }'

# List notes for user1
curl -X POST http://localhost:8000/walker/list_notes \
    -H "Content-Type: application/json" \
    -d '{"email": "user1@example.com"}'
```

## Shared Data Patterns
---
Multi-user applications often need controlled sharing of data between users. Let's enhance our notebook to support sharing notes with specific users.

### Note Sharing Implementation


```jac
# shared_permissions.jac
import uuid;

node Note {
    has title: str;
    has content: str;
    has owner: str;
    has shared_with: list[str] = [];
    has is_public: bool = False;
    has permissions: dict = {"read": True, "write": False};
    has id: str = "note_" + str(uuid.uuid4());
}

walker create_note {
    has title: str;
    has content: str;
    has owner: str;
    has is_public: bool = False;

    obj __specs__ {
        static has auth: bool = False;
    }

    can add_note with `root entry {
        new_note = Note(
            title=self.title,
            content=self.content,
            owner=self.owner,
            is_public=self.is_public
        );
        here ++> new_note;

        report {
            "status": "created",
            "note_id": new_note.id,
            "public": new_note.is_public
        };
    }
}

walker share_note {
    has note_id: str;
    has current_user: str;
    has target_user: str;
    has permission_level: str = "read";  # "read" or "write"

    obj __specs__ {
        static has auth: bool = False;
    }

    can add_sharing_permission with `root entry {
        target_note = [-->(`?Note)](?id == self.note_id);

        if not target_note {
            report {"error": "Note not found"};
            return;
        }

        note = target_note[0];

        # Only owner can share notes
        if note.owner != self.current_user {
            report {"error": "Only note owner can share"};
            return;
        }

        # Add user to shared list if not already there
        if self.target_user not in note.shared_with {
            note.shared_with.append(self.target_user);
        }

        report {
            "message": f"Note shared with {self.target_user}",
            "permission": self.permission_level,
            "shared_count": len(note.shared_with)
        };
    }
}

walker get_accessible_notes {
    has user_id: str;

    obj __specs__ {
        static has auth: bool = False;
    }

    can fetch_all_accessible with `root entry {
        all_notes = [-->(`?Note)];
        accessible_notes = [];

        for note in all_notes {
            # User can access if:
            # 1. They own it
            # 2. It's shared with them
            # 3. It's public
            if (note.owner == self.user_id or
                self.user_id in note.shared_with or
                note.is_public) {

                accessible_notes.append({
                    "id": note.id,
                    "title": note.title,
                    "owner": note.owner,
                    "is_mine": note.owner == self.user_id,
                    "access_type": "owner" if note.owner == self.user_id
                                else ("shared" if self.user_id in note.shared_with
                                    else "public")
                });
            }
        }

        report {
            "user": self.user_id,
            "accessible_notes": accessible_notes,
            "total": len(accessible_notes)
        };
    }
}
```

### Testing Note Sharing

```bash
# Alice creates a note
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Team Project",
    "content": "Project details",
    "owner": "alice@example.com"
  }'

# Alice shares note with Bob
curl -X POST http://localhost:8000/walker/share_note \
  -H "Content-Type: application/json" \
  -d '{
    "note_id": "note_123",
    "current_user": "alice@example.com",
    "target_user": "bob@example.com"
  }'

# Bob views accessible notes
curl -X POST http://localhost:8000/walker/get_accessible_notes \
  -H "Content-Type: application/json" \
  -d '{"user_id": "bob@example.com"}'
```


## Security Considerations
---
When building multi-user systems, security must be a primary concern. Application-level security patterns are essential for protecting user data.

### Secure Data Access Patterns


```jac
# rbac_notebook.jac
enum Role {
    VIEWER = "viewer",
    EDITOR = "editor",
    ADMIN = "admin"
}

node UserProfile {
    has email: str;
    has role: Role = Role.VIEWER;
    has created_at: str = "2024-01-15";
}

node Note {
    has title: str;
    has content: str;
    has owner: str;
    has required_role: Role = Role.VIEWER;
    has is_sensitive: bool = False;
}

walker check_user_role {
    has user_id: str;

    obj __specs__ {
        static has auth: bool = False;
    }

    can get_current_user_role with `root entry {
        user_profile = [-->(`?UserProfile)](?email == self.user_id);

        if user_profile {
            current_role = user_profile[0].role;
        } else {
            # Create default profile for new user
            new_profile = UserProfile(email=self.user_id);
            here ++> new_profile;
            current_role = Role.VIEWER;
        }

        report {"user": self.user_id, "role": current_role.value};
    }
}

walker create_role_based_note {
    has title: str;
    has content: str;
    has owner: str;
    has required_role: str = "viewer";
    has is_sensitive: bool = False;

    obj __specs__ {
        static has auth: bool = False;
    }

    can create_with_role_check with `root entry {
        # Get user's role
        user_profile = [-->(`?UserProfile)](?email == self.owner);

        if not user_profile {
            report {"error": "User profile not found"};
            return;
        }

        user_role = user_profile[0].role;

        # Check if user can create sensitive notes
        if self.is_sensitive and user_role == Role.VIEWER {
            report {"error": "Insufficient permissions for sensitive content"};
            return;
        }

        new_note = Note(
            title=self.title,
            content=self.content,
            owner=self.owner,
            required_role=Role(self.required_role),
            is_sensitive=self.is_sensitive
        );
        here ++> new_note;

        report {
            "message": "Note created with role requirements",
            "id": new_note.id,
            "required_role": self.required_role
        };
    }
}

walker get_role_filtered_notes {
    has user_id: str;

    obj __specs__ {
        static has auth: bool = False;
    }

    can fetch_accessible_by_role with `root entry {
        # Get user's role
        user_profile = [-->(`?UserProfile)](?email == self.user_id);

        if not user_profile {
            report {"notes": [], "message": "No user profile found"};
            return;
        }

        user_role = user_profile[0].role;
        all_notes = [-->(`?Note)];
        accessible_notes = [];

        for note in all_notes {
            # Check if user meets role requirement
            can_access = (
                note.owner == self.user_id or  # Always access own notes
                (user_role == Role.ADMIN) or  # Admins see everything
                (user_role == Role.EDITOR and note.required_role != Role.ADMIN) or
                (user_role == Role.VIEWER and note.required_role == Role.VIEWER)
            );

            if can_access {
                accessible_notes.append({
                    "id": note.id,
                    "title": note.title,
                    "owner": note.owner,
                    "required_role": note.required_role.value,
                    "is_sensitive": note.is_sensitive
                });
            }
        }

        report {
            "user_role": user_role.value,
            "notes": accessible_notes,
            "total": len(accessible_notes)
        };
    }
}
```

!!! warning "Security Best Practices"
    - **Always Verify Access**: Check user permissions before any data operation
    - **Validate Input**: Sanitize all user input to prevent injection attacks
    - **Principle of Least Privilege**: Grant minimum necessary permissions
    - **Audit Access**: Log sensitive operations for security monitoring
    - **Secure Defaults**: Make restrictive permissions the default


## Access Control Strategies
---
Different applications require different access control models. Let's implement a role-based access control system for our notebook.

### Role-Based Access Control

```jac
# rbac_notebook.jac
enum Role {
    VIEWER = "viewer",
    EDITOR = "editor",
    ADMIN = "admin"
}

node UserProfile {
    has email: str;
    has role: Role = Role.VIEWER;
    has created_at: str = "2024-01-15";
}

node Note {
    has title: str;
    has content: str;
    has owner: str;
    has required_role: Role = Role.VIEWER;
    has is_sensitive: bool = False;
}

walker check_user_role {
    has user_id: str;

    can get_current_user_role with `root entry {
        user_profile = [-->(`?UserProfile)](?email == self.user_id);

        if user_profile {
            current_role = user_profile[0].role;
        } else {
            # Create default profile for new user
            new_profile = UserProfile(email=self.user_id);
            here ++> new_profile;
            current_role = Role.VIEWER;
        }

        report {"user": self.user_id, "role": current_role.value};
    }
}

walker create_role_based_note {
    has title: str;
    has content: str;
    has owner: str;
    has required_role: str = "viewer";
    has is_sensitive: bool = False;

    can create_with_role_check with `root entry {
        # Get user's role
        user_profile = [-->(`?UserProfile)](?email == self.owner);

        if not user_profile {
            report {"error": "User profile not found"};
            return;
        }

        user_role = user_profile[0].role;

        # Check if user can create sensitive notes
        if self.is_sensitive and user_role == Role.VIEWER {
            report {"error": "Insufficient permissions for sensitive content"};
            return;
        }

        new_note = Note(
            title=self.title,
            content=self.content,
            owner=self.owner,
            required_role=Role(self.required_role),
            is_sensitive=self.is_sensitive
        );
        here ++> new_note;

        report {
            "message": "Note created with role requirements",
            "id": new_note.id,
            "required_role": self.required_role
        };
    }
}

walker get_role_filtered_notes {
    has user_id: str;

    can fetch_accessible_by_role with `root entry {
        # Get user's role
        user_profile = [-->(`?UserProfile)](?email == self.user_id);

        if not user_profile {
            report {"notes": [], "message": "No user profile found"};
            return;
        }

        user_role = user_profile[0].role;
        all_notes = [-->(`?Note)];
        accessible_notes = [];

        for note in all_notes {
            # Check if user meets role requirement
            can_access = (
                note.owner == self.user_id or  # Always access own notes
                (user_role == Role.ADMIN) or  # Admins see everything
                (user_role == Role.EDITOR and note.required_role != Role.ADMIN) or
                (user_role == Role.VIEWER and note.required_role == Role.VIEWER)
            );

            if can_access {
                accessible_notes.append({
                    "id": note.id,
                    "title": note.title,
                    "owner": note.owner,
                    "required_role": note.required_role.value,
                    "is_sensitive": note.is_sensitive
                });
            }
        }

        report {
            "user_role": user_role.value,
            "notes": accessible_notes,
            "total": len(accessible_notes)
        };
    }
}
```

### Testing Role-Based Access

```bash
# Check user role
curl -X POST http://localhost:8000/walker/check_user_role \
  -H "Content-Type: application/json" \
  -d '{"user_id": "alice@example.com"}'

# Create a note requiring editor role
curl -X POST http://localhost:8000/walker/create_role_based_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Editor Note",
    "content": "Only editors can see this",
    "owner": "alice@example.com",
    "required_role": "editor",
    "is_sensitive": true
  }'

# Get notes filtered by role
curl -X POST http://localhost:8000/walker/get_role_filtered_notes \
  -H "Content-Type: application/json" \
  -d '{"user_id": "alice@example.com"}'
```


## Best Practices
---
- **Always validate access**: Check user permissions before any data operation
- **Use consistent user identification**: Establish clear patterns for user IDs
- **Implement graceful sharing**: Make sharing intuitive and secure
- **Audit sensitive operations**: Log important user actions for security
- **Design for privacy**: Default to private data with explicit sharing
- **Test permission scenarios**: Verify access control works as expected

## Key Takeaways
---
**Multi-User Patterns:**

- **User identification**: Implement user context in walker parameters
- **Data isolation**: Filter data based on ownership and permissions
- **Permission systems**: Multiple access control strategies for different needs
- **Shared data management**: Controlled sharing between users with fine-grained permissions

**Security Considerations:**

- **Access validation**: Always verify user permissions before data operations
- **Default privacy**: Make restrictive permissions the default setting
- **Input validation**: Sanitize all user input to prevent security issues
- **Audit trails**: Log sensitive operations for security monitoring

**Application Architecture:**

- **Role-based access**: Implement hierarchical permission systems
- **Flexible sharing**: Support various sharing patterns for different use cases
- **User profiles**: Manage user information and preferences
- **Data ownership**: Clear patterns for who can access and modify data

**Development Benefits:**

- **Built-in isolation**: Graph filtering provides natural data separation
- **Flexible permissions**: Implement custom access control with business logic
- **Scalable patterns**: Multi-user code scales automatically with Jac Cloud
- **Type safety**: User permissions validated through the type system

!!! tip "Try It Yourself"
    Build multi-user systems by adding:
    - Team-based collaboration features
    - Real-time notifications for shared data changes
    - Advanced permission hierarchies with groups and roles
    - Activity feeds showing user actions

    Remember: Always validate user permissions before any data operation!

---

*Ready to learn about advanced cloud features? Continue to [Chapter 16: Advanced Jac Cloud Features](chapter_15.md)!*
