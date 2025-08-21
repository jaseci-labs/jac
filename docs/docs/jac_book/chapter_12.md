# Chapter 12: Walkers as API Endpoints

In this chapter, we'll explore how Jac automatically transforms walkers into RESTful API endpoints with our **Jac Cloud** Plugin. Jac Cloud, is a revolutionary cloud platform that transforms your Jac programs into scalable web services without code changes. This means you can focus on building your application logic while Jac handles the HTTP details for you.


We'll build a simple shared notebook system that demonstrates automatic API generation, request handling, and parameter validation through a practical example.

!!! info "What You'll Learn"
    - Understanding Jac Cloud's scale-agnostic architecture
    - Converting walkers into API endpoints automatically
    - Deploying applications with zero configuration
    - Managing persistence and state in the cloud

---

## What is Jac Cloud?

Jac Cloud is a cloud-native execution environment designed specifically for Jac programs. It enables developers to write code once and run it anywhere - from local development to production-scale deployments - without any modifications.

!!! success "Key Benefits"
    - **Zero Code Changes**: Same code runs locally and in the cloud
    - **Automatic APIs**: Walkers become REST endpoints automatically
    - **Built-in Persistence**: Data storage handled transparently
    - **Instant Scaling**: Scale by increasing service replicas
    - **Developer Focus**: No infrastructure management needed


## Quick Setup and Deployment
Let's start with a minimal weather API example and gradually enhance it throughout this chapter.

First, ensure you have the Jac Cloud plugin installed:

```bash
pip install jac-cloud
```

Next, crate a simple Jac program that contains a single walker that produces weather information based on a city name. This program creates a REST API endpoint that accepts a city name and returns the weather information. The walker has a property `city` which is automatically mapped to an expected request parameter in the request body.


!!! example "Basic Weather API"
    === "Jac Cloud"
        ```jac
        # weather.jac - No manual API setup needed
        walker get_weather {
            has city: str;

            obj __specs__ {
                static has auth: bool = False;
            }

            can get_weather_data with `root entry {
                # Your weather logic here
                weather_info = f"Weather in {self.city}: Sunny, 25°C";
                report {"city": self.city, "weather": weather_info};
            }
        }
        ```

    === "Traditional Approach"
        ```python
        # app.py - Manual API setup required
        from flask import Flask, jsonify

        app = Flask(__name__)

        @app.route('/weather/<city>', methods=['GET'])
        def get_weather(city):
            weather_info = f"Weather in {city}: Sunny, 25°C"
            return jsonify({"city": city, "weather": weather_info})

        if __name__ == '__main__':
            app.run(debug=True)
        ```


### Deploying to Cloud
To deploy your Jac program as a cloud service, use the `jac serve` command:

```bash
jac serve weather_service.jac
```

!!! success "Instant Deployment"
    ```
    INFO:     Started server process [26286]
    INFO:     Waiting for application startup.
    INFO:     Application startup complete.
    INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
    ```

Your walker is now automatically available as a REST API endpoint!

To test the API, you can use `curl` or any HTTP client:

```bash
curl -X POST http://localhost:8000/walker/get_weather \
  -H "Content-Type: application/json" \
  -d '{"city": "New York"}'
```

In this example the endpoint is defined as `/walker/get_weather`, however, the endpoint also expects a JSON request body with a `city` field.

The response will be a JSON object containing the weather information.

!!! success "API Response"
    ```json
    {
        "returns": [
            {
                "city": "New York",
                "weather": "Weather in New York: Sunny, 25°C"
            }
        ]
    }
    ```


!!! note "Authentication"
    - Jac Cloud provides built-in support for authentication and authorization.
    - You can define authentication requirements using the `auth` property in the `__specs__` object.
    - By default, all walkers are private, but you can make them public by setting `auth: False`.
    - To learn more about authentication, see the [Jac Cloud Section of the Documentation](../learn/jac-cloud/introduction.md).

---

## Going Beyond: Building a Shared Notebook API
Now that we have a basic understanding of Jac Cloud and how it automatically generates APIs from walkers, let's build a more complex application: a shared notebook system.

First lets develop a walker that allows users to create and retrieve notes in a notebook. This will demonstrate how Jac handles request/response mapping, parameter validation, and persistence automatically.

!!! example "API Development Comparison"
    === "Jac Automatic APIs"
        ```jac
        import uuid;

        # notebook.jac - No manual API setup needed
        node Note {
            has title: str;
            has content: str;
            has author: str;
            has created_at: str = "2024-01-15";
            has id: str = "note_" + str(uuid.uuid4());
        }



        walker create_note {
            has title: str;
            has content: str;
            has author: str;

            obj __specs__ {
                static has auth: bool = False;
            }

            can create_new_note with `root entry {
                new_note = Note(
                    title=self.title,
                    content=self.content,
                    author=self.author
                );

                here ++> new_note;
                report {"message": "Note created", "id": new_note.id};
            }
        }

        walker get_notes {
            obj __specs__ {
                static has auth: bool = False;
            }

            can fetch_all_notes with `root entry {
                all_notes = [-->(`?Note)];
                notes_data = [
                    {"id": n.id, "title": n.title, "author": n.author}
                    for n in all_notes
                ];
                report {"notes": notes_data, "total": len(notes_data)};
            }
        }
        ```
    === "Traditional Approach"
        ```python
        # app.py - Manual API setup required
        from flask import Flask, request, jsonify
        from typing import Dict, List

        app = Flask(__name__)

        # Global storage (in production, use a database)
        notebooks = {}

        @app.route('/create_note', methods=['POST'])
        def create_note():
            try:
                data = request.get_json()
                title = data.get('title')
                content = data.get('content')
                author = data.get('author')

                # Manual validation
                if not title or not content or not author:
                    return jsonify({"error": "Missing required fields"}), 400

                note_id = len(notebooks) + 1
                notebooks[note_id] = {
                    "id": note_id,
                    "title": title,
                    "content": content,
                    "author": author
                }

                return jsonify({"message": "Note created", "id": note_id})
            except Exception as e:
                return jsonify({"error": str(e)}), 500

        @app.route('/get_notes', methods=['GET'])
        def get_notes():
            return jsonify(list(notebooks.values()))

        if __name__ == '__main__':
            app.run(debug=True)
        ```


Deploy your notebook API:

```bash
jac serve simple_notebook.jac
```

We can now test the API using `curl` or any HTTP client via the POST method. The `create_note` walker will accept a JSON request body with `title`, `content`, and `author` fields, and return a response indicating the note was created.

```bash
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Note",
    "content": "This is a test note",
    "author": "Alice"
  }'
```

!!! success "API Response"
    ```json
    {
        "returns": [
            {
                "status": "created",
                "note": {
                    "title": "My First Note",
                    "author": "Alice"
                }
            }
        ]
    }
    ```

To retrieve all notes, we can use the `get_notes` walker:

```bash
curl -X POST http://localhost:8000/walker/get_notes \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Convert to GET request
To convert the `get_notes` walker to a GET request, we can simply change the walker `___specs__` to indicate that it can be accessed via a GET request. This is done by setting the `methods` attribute in the `__specs__` object.

```jac
walker get_notes {
    obj __specs__ {
        static has auth: bool = False;
        static has methods: list = ["get"];
    }

    can fetch_all_notes with `root entry {
        all_notes = [-->(`?Note)];
        notes_data = [
            {"id": n.id, "title": n.title, "author": n.author}
            for n in all_notes
        ];
        report {"notes": notes_data, "total": len(notes_data)};
    }
}
```

The `get_notes` walker can now be accessed via a GET request at the endpoint `/walker/get_notes`.

```bash
curl -X GET http://localhost:8000/walker/get_notes \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Parameter Validation

Jac automatically validates request parameters based on walker attribute types. This eliminates manual validation code and ensures type safety.

### Enhanced Notebook with Validation

!!! example "Notebook with Type Validation"

    ```jac
    # validated_notebook.jac
    node Note {
        has title: str;
        has content: str;
        has author: str;
        has priority: int = 1;  # 1-5 priority level
        has tags: list[str] = [];
    }

    walker create_note {
        has title: str;
        has content: str;
        has author: str;
        has priority: int = 1;
        has tags: list[str] = [];

        obj __specs__ {
            static has auth: bool = False;
        }

        can validate_and_create with `root entry {
            # Jac automatically validates types before this runs

            # Additional business logic validation
            if len(self.title) < 3 {
                report {"error": "Title must be at least 3 characters"};
                return;
            }

            if self.priority < 1 or self.priority > 5 {
                report {"error": "Priority must be between 1 and 5"};
                return;
            }

            # Create note with validated data
            new_note = Note(
                title=self.title,
                content=self.content,
                author=self.author,
                priority=self.priority,
                tags=self.tags
            );
            here ++> new_note;

            report {
                "message": "Note created successfully",
                "note_title": new_note.title,
                "priority": new_note.priority
            };
        }
    }
    ```

### Testing Validation

```bash
# Valid request
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Important Meeting",
    "content": "Discuss project timeline",
    "author": "Bob",
    "priority": 3,
    "tags": ["work", "meeting"]
  }'

# Invalid request - priority out of range
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test",
    "content": "Test content",
    "author": "Bob",
    "priority": 10
  }'
```

!!! tip "Automatic Type Validation"
    Jac validates types before your walker code runs. Invalid types return HTTP 400 automatically.

---

## REST Patterns with Walkers

Walkers naturally map to REST operations, creating intuitive API patterns for common CRUD operations.

### Complete Notebook API

!!! example "Full CRUD Notebook System"

    ```jac
    import from uuid { uuid4 }

    # complete_notebook.jac
    node Note {
        has title: str;
        has content: str;
        has author: str;
        has priority: int = 1;
        has created_at: str = "2024-01-15";
        has id: str;
    }

    # CREATE - Add new note
    walker create_note {
        has title: str;
        has content: str;
        has author: str;
        has priority: int = 1;

        can add_note with `root entry {
            new_note = Note(
                title=self.title, content=self.content,
                author=self.author, priority=self.priority,
                id="note_" + str(uuid4())
            );
            here ++> new_note;
            report {"message": "Note created", "id": new_note.id};
        }
    }

    # READ - Get all notes
    walker list_notes {
        can get_all_notes with `root entry {
            all_notes = [-->(`?Note)];
            report {
                "notes": [
                    {
                        "id": n.id,
                        "title": n.title,
                        "author": n.author,
                        "priority": n.priority
                    }
                    for n in all_notes
                ],
                "total": len(all_notes)
            };
        }
    }

    # READ - Get specific note
    walker get_note {
        has note_id: str;

        can fetch_note with `root entry {
            target_note = [-->(`?Note)](?id == self.note_id);

            if target_note {
                note = target_note[0];
                report {
                    "note": {
                        "id": note.id,
                        "title": note.title,
                        "content": note.content,
                        "author": note.author,
                        "priority": note.priority
                    }
                };
            } else {
                report {"error": "Note not found"};
            }
        }
    }

    # UPDATE - Modify note
    walker update_note {
        has note_id: str;
        has title: str = "";
        has content: str = "";
        has priority: int = 0;

        can modify_note with `root entry {
            target_note = [-->(`?Note)](?id == self.note_id);

            if target_note {
                note = target_note[0];

                # Update only provided fields
                if self.title {
                    note.title = self.title;
                }
                if self.content {
                    note.content = self.content;
                }
                if self.priority > 0 {
                    note.priority = self.priority;
                }

                report {"message": "Note updated", "id": note.id};
            } else {
                report {"error": "Note not found"};
            }
        }
    }

    # DELETE - Remove note
    walker delete_note {
        has note_id: str;

        can remove_note with `root entry {
            target_note = [-->(`?Note)](?id == self.note_id);

            if target_note {
                note = target_note[0];
                # Delete the node and its connections
                del note;
                report {"message": "Note deleted", "id": self.note_id};
            } else {
                report {"error": "Note not found"};
            }
        }
    }
    ```

### API Usage Examples

```bash
# Create a note
curl -X POST http://localhost:8000/walker/create_note \
  -H "Content-Type: application/json" \
  -d '{"title": "Shopping List", "content": "Milk, Bread, Eggs", "author": "Alice"}'

# List all notes
curl -X POST http://localhost:8000/walker/list_notes \
  -H "Content-Type: application/json" \
  -d '{}'

# Get specific note (replace with actual ID)
curl -X POST http://localhost:8000/walker/get_note \
  -H "Content-Type: application/json" \
  -d '{"note_id": "note_123"}'

# Update a note
curl -X POST http://localhost:8000/walker/update_note \
  -H "Content-Type: application/json" \
  -d '{"note_id": "note_123", "priority": 5}'

# Delete a note
curl -X POST http://localhost:8000/walker/delete_note \
  -H "Content-Type: application/json" \
  -d '{"note_id": "note_123"}'
```

---

## Shared Notebook with Permissions

Let's add basic permission checking to demonstrate multi-user patterns:

!!! example "Notebook with User Permissions"
    ```jac
    import from uuid { uuid4 }

    # shared_notebook.jac
    node Note {
        has title: str;
        has content: str;
        has author: str;
        has shared_with: list[str] = [];
        has is_public: bool = false;
        has id: str;
    }

    walker create_shared_note {
        has title: str;
        has content: str;
        has author: str;
        has shared_with: list[str] = [];
        has is_public: bool = false;

        can create_note with `root entry {
            new_note = Note(
                title=self.title,
                content=self.content,
                author=self.author,
                shared_with=self.shared_with,
                is_public=self.is_public,
                id="note_" + str(uuid4())
            );
            here ++> new_note;

            report {
                "message": "Shared note created",
                "id": new_note.id,
                "shared_with": len(self.shared_with),
                "is_public": self.is_public
            };
        }
    }

    walker get_user_notes {
        has user: str;

        can fetch_accessible_notes with `root entry {
            all_notes = [-->(`?Note)];
            accessible_notes = [];

            for note in all_notes {
                # User can access if they're the author, note is public,
                # or they're in the shared_with list
                if (note.author == self.user or
                    note.is_public or
                    self.user in note.shared_with) {
                    accessible_notes.append({
                        "id": note.id,
                        "title": note.title,
                        "author": note.author,
                        "is_mine": note.author == self.user
                    });
                }
            }

            report {
                "user": self.user,
                "notes": accessible_notes,
                "count": len(accessible_notes)
            };
        }
    }

    walker share_note {
        has note_id: str;
        has user: str;
        has share_with: str;

        can add_share_permission with `root entry {
            target_note = [-->(`?Note)](?id == self.note_id);

            if target_note {
                note = target_note[0];

                # Only author can share
                if note.author == self.user {
                    if self.share_with not in note.shared_with {
                        note.shared_with.append(self.share_with);
                    }

                    report {
                        "message": f"Note shared with {self.share_with}",
                        "shared_with": note.shared_with
                    };
                } else {
                    report {"error": "Only author can share notes"};
                }
            } else {
                report {"error": "Note not found"};
            }
        }
    }
    ```

### Testing Shared Notebook

```bash
# Create a shared note
curl -X POST http://localhost:8000/walker/create_shared_note \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Team Meeting Notes",
    "content": "Discussed project milestones",
    "author": "Alice",
    "shared_with": ["Bob", "Charlie"],
    "is_public": false
  }'

# Get notes for a user
curl -X POST http://localhost:8000/walker/get_user_notes \
  -H "Content-Type: application/json" \
  -d '{"user": "Bob"}'

# Share note with another user
curl -X POST http://localhost:8000/walker/share_note \
  -H "Content-Type: application/json" \
  -d '{
    "note_id": "note_123",
    "user": "Alice",
    "share_with": "David"
  }'
```

---

## Best Practices

!!! summary "API Development Guidelines"
    - **Use descriptive walker names**: Names become part of your API surface
    - **Validate input early**: Check parameters before processing
    - **Provide clear error messages**: Help API consumers understand failures
    - **Keep walkers focused**: Each walker should have a single responsibility
    - **Use consistent response formats**: Standardize success and error responses
    - **Document with types**: Type annotations serve as API documentation

## Key Takeaways

!!! summary "What We've Learned"
    **Automatic API Generation:**

    - **Zero configuration**: Walkers become REST endpoints without setup
    - **Type-safe parameters**: Request validation handled automatically
    - **Natural REST patterns**: CRUD operations map intuitively to walker semantics
    - **Instant deployment**: Deploy APIs with a single command

    **Request/Response Handling:**

    - **JSON mapping**: Request bodies automatically map to walker attributes
    - **Response formatting**: Walker reports become structured JSON responses
    - **Parameter validation**: Type system validates requests before execution
    - **Error handling**: Built-in patterns for graceful error responses

    **Shared Data Applications:**

    - **Persistent nodes**: Data survives between API requests
    - **Graph operations**: Complex data relationships handled naturally
    - **User permissions**: Implement access control with business logic
    - **Multi-user patterns**: Support shared and private data seamlessly

    **Development Benefits:**

    - **Focus on logic**: No HTTP handling, routing, or serialization code
    - **Type safety**: Compile-time validation for API contracts
    - **Rapid iteration**: Changes take effect immediately
    - **Scale-ready**: Same code works from development to production

!!! tip "Try It Yourself"
    Build sophisticated APIs by adding:
    - Authentication and user sessions
    - File upload and processing capabilities
    - Real-time notifications and webhooks
    - Integration with external services

    Remember: Every walker you create automatically becomes an API endpoint when deployed!

---

*Ready to learn about persistent data? Continue to [Chapter 13: Persistence and the Root Node](chapter_13.md)!*
