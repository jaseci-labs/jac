# Chapter 14: Multi-User Architecture and Permissions

!!! note "About Jac Cloud vs Jac Scale"
    This chapter references **Jac Cloud**, which has been superseded by **jac-scale**. The core concepts remain the same, but for new projects, please use [jac-scale](../production/index.md) instead. See the [Advanced Topics](../advanced/index.md) for current multi-user architecture documentation.

In this chapter, we'll explore how to build secure, multi-user applications in Jac Cloud. We'll develop a shared notebook system that demonstrates user isolation, permission systems, and access control strategies through practical examples that evolve throughout the chapter.

!!! info "What You'll Learn"
    - Building secure multi-user applications
    - User isolation and data privacy patterns
    - Permission-based access control
    - Shared data management strategies
    - Security considerations for cloud applications

---

## User Isolation and Permission Systems

Multi-user applications require careful consideration of data access and user permissions. Jac provides built-in patterns for user management that integrate seamlessly with your application logic, allowing you to focus on business rules rather than authentication infrastructure.

!!! success "Multi-User Benefits"
    - **User Context**: Access to user information in walkers
    - **Data Isolation**: Users can only access their authorized data
    - **Flexible Permissions**: Fine-grained access control patterns
    - **Secure by Default**: Application-level security patterns
    - **Shared Data Support**: Controlled sharing between users

### Traditional vs Jac Multi-User Development

!!! example "Multi-User Comparison"
    === "Traditional Approach"
        ```python
        # app.py - Manual user management required
        from flask import Flask, request, jsonify
        from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
        from werkzeug.security import generate_password_hash, check_password_hash

        app = Flask(__name__)
        app.config['JWT_SECRET_KEY'] = 'your-secret-key'
        jwt = JWTManager(app)

        # Global storage (in production, use a database)
        users = {}
        notebooks = {}

        @app.route('/register', methods=['POST'])
        def register():
            data = request.get_json()
            username = data.get('username')
            password = data.get('password')

            if username in users:
                return jsonify({'error': 'User already exists'}), 400

            users[username] = {
                'password': generate_password_hash(password),
                'notebooks': []
            }

            return jsonify({'message': 'User created successfully'})

        @app.route('/login', methods=['POST'])
        def login():
            data = request.get_json()
            username = data.get('username')
            password = data.get('password')

            if username not in users or not check_password_hash(users[username]['password'], password):
                return jsonify({'error': 'Invalid credentials'}), 401

            access_token = create_access_token(identity=username)
            return jsonify({'access_token': access_token})

        @app.route('/create_note', methods=['POST'])
        @jwt_required()
        def create_note():
            current_user = get_jwt_identity()
            data = request.get_json()

            # Manual permission checking
            note_id = len(notebooks)
            notebooks[note_id] = {
                'id': note_id,
                'title': data.get('title'),
                'content': data.get('content'),
                'owner': current_user,
                'shared_with': []
            }

            users[current_user]['notebooks'].append(note_id)
            return jsonify({'message': 'Note created', 'id': note_id})

        if __name__ == '__main__':
            app.run()
        ```

    === "Jac Multi-User"
        ```jac
        # shared_notebook.jac - User patterns built-in
        node Note {
            has title: str;
            has content: str;
            has owner: str;
            has shared_with: list[str] = [];
            has created_at: str = "2024-01-15";
        }

        walker create_note {
            has title: str;
            has content: str;
            has owner: str;

            can create_user_note with `root entry {
                # Create note with specified owner
                new_note = Note(
                    title=self.title,
                    content=self.content,
                    owner=self.owner
                );
                here ++> new_note;

                report {
                    "message": "Note created successfully",
                    "id": new_note.id,
                    "owner": new_note.owner
                };
            }
        }

        walker get_my_notes {
            has user_id: str;

            can fetch_user_notes with `root entry {
                # Filter by specified user
                my_notes = [-->(`?Note)](?owner == self.user_id);

                notes_data = [
                    {"id": n.id, "title": n.title, "created_at": n.created_at}
                    for n in my_notes
                ];

                report {"notes": notes_data, "total": len(notes_data)};
            }
        }
        ```

---

## Basic User Authentication

For multi-user applications, you need to implement user identification patterns. Let's start with a simple notebook system that supports multiple users.

### Setting Up User-Aware Notebook

!!! example "User-Isolated Notebook System"
    === "Jac"
        ```jac
        # user_notebook.jac
        import uuid;

        node Note {
            has title: str;
            has content: str;
            has owner: str;
            has is_private: bool = True;
            has id: str = "note_" + str(uuid.uuid4());
        }

        walker create_note {
            has title: str;
            has content: str;
            has owner: str;
            has is_private: bool = True;

            obj __specs__ {
                static has auth: bool = False;
            }

            can add_note with `root entry {
                new_note = Note(
                    title=self.title,
                    content=self.content,
                    owner=self.owner,
                    is_private=self.is_private
                );
                here ++> new_note;

                report {
                    "status": "created",
                    "note_id": new_note.id,
                    "private": new_note.is_private
                };
            }
        }

        walker list_my_notes {
            has user_id: str;

            obj __specs__ {
                static has auth: bool = False;
            }

            can get_user_notes with `root entry {
                # Only get notes owned by specified user
                user_notes = [-->(`?Note)](?owner == self.user_id);

                report {
                    "user": self.user_id,
                    "notes": [
                        {
                            "id": n.id,
                            "title": n.title,
                            "private": n.is_private
                        }
                        for n in user_notes
                    ],
                    "count": len(user_notes)
                };
            }
        }
        ```

    === "Python Equivalent"
        ```python
        # user_notebook.py - Requires manual auth setup
        from flask import Flask, request, jsonify
        from flask_jwt_extended import JWTManager, jwt_required, get_jwt_identity

        app = Flask(__name__)
        app.config['JWT_SECRET_KEY'] = 'secret-key'
        jwt = JWTManager(app)

        notes = []

        @app.route('/create_note', methods=['POST'])
        @jwt_required()
        def create_note():
            current_user = get_jwt_identity()
            data = request.get_json()

            note = {
                'id': len(notes),
                'title': data.get('title'),
                'content': data.get('content'),
                'owner': current_user,
                'is_private': data.get('is_private', True)
            }
            notes.append(note)

            return jsonify({
                'status': 'created',
                'note_id': note['id'],
                'private': note['is_private']
            })

        @app.route('/list_my_notes', methods=['GET'])
        @jwt_required()
        def list_my_notes():
            current_user = get_jwt_identity()
            user_notes = [n for n in notes if n['owner'] == current_user]

            return jsonify({
                'user': current_user,
                'notes': [
                    {'id': n['id'], 'title': n['title'], 'private': n['is_private']}
                    for n in user_notes
                ],
                'count': len(user_notes)
            })
        ```

### Deploying and Testing

Deploy your user-aware application:

```bash
jac start user_notebook.jac
```

### Testing User Authentication

```bash
# Create a note for Alice
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Alice Private Note",
    "content": "Secret content",
    "owner": "alice@example.com"
  }'

# Create a note for Bob
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Bob Note",
    "content": "Bob content",
    "owner": "bob@example.com"
  }'

# Get Alice's notes only
curl -X POST http://localhost:8000/walker/list_my_notes \
  -H "Content-Type: application/json" \
  -d '{"user_id": "alice@example.com"}'
```

---

## Shared Data Patterns

Multi-user applications often need controlled sharing of data between users. Let's enhance our notebook to support sharing notes with specific users.

### Note Sharing Implementation

!!! example "Shared Notebook with Permissions"
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

---

## Security Considerations

When building multi-user systems, security must be a primary concern. Application-level security patterns are essential for protecting user data.

### Secure Data Access Patterns

!!! example "Security-First Note Access"
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

---

## Access Control Strategies

Different applications require different access control models. Let's implement a role-based access control system for our notebook.

### Role-Based Access Control

!!! example "RBAC Notebook System"
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

---

## Best Practices

!!! summary "Multi-User Development Guidelines"
    - **Always validate access**: Check user permissions before any data operation
    - **Use consistent user identification**: Establish clear patterns for user IDs
    - **Implement graceful sharing**: Make sharing intuitive and secure
    - **Audit sensitive operations**: Log important user actions for security
    - **Design for privacy**: Default to private data with explicit sharing
    - **Test permission scenarios**: Verify access control works as expected

## Key Takeaways

!!! summary "What We've Learned"
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
