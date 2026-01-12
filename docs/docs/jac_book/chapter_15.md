# Chapter 15: Advanced Jac Cloud Features

!!! note "About Jac Cloud vs Jac Scale"
    This chapter references **Jac Cloud**, which has been superseded by **jac-scale**. The core concepts remain the same, but for new projects, please use [jac-scale](../production/index.md) instead. See the [Configuration Guide](../configuration/index.md) for jac.toml configuration options.

In this chapter, we'll explore advanced Jac Cloud capabilities that enable configuration management, monitoring, and external integrations. We'll build a comprehensive chat room system that demonstrates environment configuration, logging, and webhook integration through practical examples.

!!! info "What You'll Learn"
    - Environment variables and application configuration
    - Logging and monitoring capabilities
    - Webhook integration for external services
    - Advanced deployment patterns
    - Performance optimization strategies

---

## Environment Variables and Configuration

Production applications require flexible configuration management. Jac Cloud provides built-in support for environment variables and configuration patterns that work seamlessly across local and cloud deployments.

!!! success "Configuration Benefits"
    - **Environment Isolation**: Different settings for dev, staging, and production
    - **Security**: Sensitive data kept in environment variables
    - **Flexibility**: Runtime configuration without code changes
    - **Cloud Integration**: Automatic configuration injection in cloud environments

### Traditional vs Jac Configuration

!!! example "Configuration Comparison"
    === "Traditional Approach"
        ```python
        # config.py - Manual configuration management
        import os
        from typing import Optional

        class Config:
            def __init__(self):
                self.database_url = os.getenv('DATABASE_URL', 'sqlite:///app.db')
                self.redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
                self.secret_key = os.getenv('SECRET_KEY', 'dev-secret')
                self.debug = os.getenv('DEBUG', 'False').lower() == 'true'

                # Validate required settings
                if not self.secret_key or self.secret_key == 'dev-secret':
                    if not self.debug:
                        raise ValueError("SECRET_KEY must be set in production")

        # app.py
        from flask import Flask
        from config import Config

        config = Config()
        app = Flask(__name__)
        app.config.from_object(config)

        @app.route('/chat')
        def chat():
            return f"Chat room (Debug: {config.debug})"
        ```

    === "Jac Configuration"
        ```jac
        # chat_room.jac - Built-in configuration support
        import from os { getenv }

        glob chat_config = {
            "max_users": int(getenv("MAX_CHAT_USERS", "100")),
            "message_limit": int(getenv("MESSAGE_LIMIT", "1000")),
            "room_timeout": int(getenv("ROOM_TIMEOUT", "3600")),
            "debug_mode": getenv("DEBUG", "false").lower() == "true"
        };

        node ChatRoom {
            has name: str;
            has users: list[str] = [];
            has messages: list[dict] = [];
            has created_at: str;

            can add_user(username: str) -> bool {
                if len(self.users) >= chat_config["max_users"] {
                    return False;
                }
                if username not in self.users {
                    self.users.append(username);
                }
                return True;
            }
        }

        walker create_chat_room {
            has room_name: str;

            can setup_room with `root entry {
                new_room = ChatRoom(
                    name=self.room_name,
                    created_at="2024-01-15"
                );
                here ++> new_room;

                report {
                    "room_id": new_room.id,
                    "name": new_room.name,
                    "max_users": chat_config["max_users"]
                };
            }
        }
        ```

### Basic Chat Room Setup

Let's start with a simple chat room that uses environment configuration:

!!! example "Configurable Chat Room"
    === "Jac"
        ```jac
        # simple_chat.jac
        import from os { getenv }
        import from datetime { datetime }

        glob config = {
            "max_rooms": int(getenv("MAX_ROOMS", "10")),
            "max_users_per_room": int(getenv("MAX_USERS_PER_ROOM", "50")),
            "message_history": int(getenv("MESSAGE_HISTORY", "100"))
        };

        node ChatRoom {
            has name: str;
            has users: list[str] = [];
            has message_count: int = 0;
        }

        walker join_room {
            has room_name: str;
            has username: str;

            can join_chat with `root entry {
                # Find or create room
                room = [-->(`?ChatRoom)](?name == self.room_name);

                if not room {
                    # Check room limit
                    total_rooms = len([-->(`?ChatRoom)]);
                    if total_rooms >= config["max_rooms"] {
                        report {"error": "Maximum rooms reached"};
                        return;
                    }

                    room = ChatRoom(name=self.room_name);
                    here ++> room;
                } else {
                    room = room[0];
                }

                # Check user limit
                if len(room.users) >= config["max_users_per_room"] {
                    report {"error": "Room is full"};
                    return;
                }

                # Add user if not already in room
                if self.username not in room.users {
                    room.users.append(self.username);
                }

                report {
                    "room": room.name,
                    "users": room.users,
                    "user_count": len(room.users)
                };
            }
        }
        ```

    === "Python Equivalent"
        ```python
        # simple_chat.py - Requires manual setup
        import os
        from flask import Flask, request, jsonify

        app = Flask(__name__)

        # Configuration
        MAX_ROOMS = int(os.getenv("MAX_ROOMS", "10"))
        MAX_USERS_PER_ROOM = int(os.getenv("MAX_USERS_PER_ROOM", "50"))
        MESSAGE_HISTORY = int(os.getenv("MESSAGE_HISTORY", "100"))

        # In-memory storage
        chat_rooms = {}

        @app.route('/join_room', methods=['POST'])
        def join_room():
            data = request.get_json()
            room_name = data.get('room_name')
            username = data.get('username')

            # Check room limit
            if len(chat_rooms) >= MAX_ROOMS and room_name not in chat_rooms:
                return jsonify({"error": "Maximum rooms reached"}), 400

            # Create room if doesn't exist
            if room_name not in chat_rooms:
                chat_rooms[room_name] = {
                    "name": room_name,
                    "users": [],
                    "message_count": 0
                }

            room = chat_rooms[room_name]

            # Check user limit
            if len(room["users"]) >= MAX_USERS_PER_ROOM:
                return jsonify({"error": "Room is full"}), 400

            # Add user
            if username not in room["users"]:
                room["users"].append(username)

            return jsonify({
                "room": room["name"],
                "users": room["users"],
                "user_count": len(room["users"])
            })

        if __name__ == '__main__':
            app.run()
        ```

### Environment Setup

Create a `.env` file for local development:

```bash
# .env file
MAX_ROOMS=20
MAX_USERS_PER_ROOM=100
MESSAGE_HISTORY=500
DEBUG=true
```

Deploy with environment variables:

```bash
# Local with environment variables
MAX_ROOMS=20 jac start simple_chat.jac

# Or using .env file (if supported by your environment)
jac start simple_chat.jac
```

---

## Message Management and Storage

Instead of WebSockets, let's focus on RESTful message management that works with jac-scale's current capabilities:

### Message Storage Implementation

!!! example "RESTful Chat Implementation"
    ```jac
        # message_chat.jac
        import from datetime { datetime }
        import from os { getenv}
        import from uuid { uuid4 }

        node ChatMessage {
            has content: str;
            has sender: str;
            has timestamp: str;
            has room_name: str;
            has id: str = "msg_" + str(uuid4());
        }

        node ChatRoom {
            has name: str;
            has users: list[str] = [];
            has message_count: int = 0;

            def add_message(sender: str, content: str) -> ChatMessage {
                new_message = ChatMessage(
                    content=content,
                    sender=sender,
                    timestamp=datetime.now().isoformat(),
                    room_name=self.name
                );
                self ++> new_message;
                self.message_count += 1;
                return new_message;
            }

            def get_recent_messages(limit: int = 20) -> list[dict] {
                messages = [self --> (`?ChatMessage)];
                recent = messages[-limit:] if len(messages) > limit else messages;
                return [
                    {
                        "content": msg.content,
                        "sender": msg.sender,
                        "timestamp": msg.timestamp
                    }
                    for msg in recent
                ];

            }
        }

        walker join_room {
            has room_name: str;
            has username: str;

            obj __specs__ {
                static has auth: bool = False;
            }

            can join_chat with `root entry {
                # Find or create room
                room = [-->(`?ChatRoom)](?name == self.room_name);

                if not room {
                    # Check room limit
                    total_rooms = len([-->(`?ChatRoom)]);
                    if total_rooms >= int(getenv("MAX_ROOMS", "100")) {
                        report {"error": "Maximum rooms reached"};
                        return;
                    }

                    room = ChatRoom(name=self.room_name);
                    here ++> room;
                } else {
                    room = room[0];
                }

                # Check user limit
                if len(room.users) >= int(getenv("MAX_USERS_PER_ROOM", "100")) {
                    report {"error": "Room is full"};
                    return;
                }

                # Add user if not already in room
                if self.username not in room.users {
                    room.users.append(self.username);
                }

                report {
                    "room": room.name,
                    "users": room.users,
                    "user_count": len(room.users)
                };
                # return room;
            }
        }


        walker send_message {
            has room_name: str;
            has username: str;
            has message: str;

            obj __specs__ {
                static has auth: bool = False;
            }

            can process_message with `root entry {
                # Find the room
                room = [-->(`?ChatRoom)](?name == self.room_name);

                if not room {
                    report {"error": "Room not found"};
                    return;
                }

                room = room[0];

                # Check if user is in room
                if self.username not in room.users {
                    report {"error": "User not in room"};
                    return;
                }

                # Add message
                new_message = room.add_message(self.username, self.message);

                report {
                    "status": "message_sent",
                    "message_id": new_message.id,
                    "timestamp": new_message.timestamp
                };
            }
        }

        walker get_chat_history {
            has room_name: str;
            has limit: int = 20;

            obj __specs__ {
                static has auth: bool = False;
            }

            can fetch_history with `root entry {
                room = [-->(`?ChatRoom)](?name == self.room_name);

                if room {
                    messages = room[0].get_recent_messages(self.limit);
                    report {"room": self.room_name, "messages": messages};
                } else {
                    report {"error": "Room not found"};
                }
            }
        }
    ```

### Testing Message API

Deploy the message-enabled chat:

```bash
jac start message_chat.jac
```

Test with curl (all walker endpoints are POST):

```bash
# Join a room first
curl -X POST http://localhost:8000/walker/join_room \
  -H "Content-Type: application/json" \
  -d '{"room_name": "general", "username": "alice"}'

# Send a message
curl -X POST http://localhost:8000/walker/send_message \
  -H "Content-Type: application/json" \
  -d '{"room_name": "general", "username": "alice", "message": "Hello everyone!"}'

# Get chat history
curl -X POST http://localhost:8000/walker/get_chat_history \
  -H "Content-Type: application/json" \
  -d '{"room_name": "general", "limit": 10}'
```

---

## Webhook Integration

Webhooks enable your Jac applications to receive real-time notifications from external services. This is essential for integrating with third-party APIs and building event-driven architectures.

### Webhook Receiver Implementation

!!! example "Chat Notification Webhooks"
    ```jac
    # webhook_chat.jac
    import from datetime { datetime }

    node WebhookLog {
        has source: str;
        has event_type: str;
        has data: dict;
        has received_at: str;
    }

    # Webhook receiver walker
    walker receive_webhook {
        has source: str = "unknown";
        has event_type: str;
        has data: dict;

        can process_webhook with `root entry {
            # Log the webhook
            webhook_log = WebhookLog(
                source=self.source,
                event_type=self.event_type,
                data=self.data,
                received_at=datetime.now().isoformat()
            );
            here ++> webhook_log;

            # Process different webhook types
            if self.source == "github" and self.event_type == "push" {
                self.handle_github_push();
            } elif self.source == "slack" and self.event_type == "message" {
                self.handle_slack_message();
            } else {
                print(f"Unknown webhook: {self.source}/{self.event_type}");
            }

            report {"status": "webhook_processed", "log_id": webhook_log.id};
        }

        can handle_github_push() {
            # Extract commit information
            commits = self.data.get("commits", []);
            repo_name = self.data.get("repository", {}).get("name", "unknown");

            # Send notification to chat
            for commit in commits {
                message = f" New commit in {repo_name}: {commit.get('message', 'No message')}";
                self.send_to_chat("dev-updates", "GitBot", message);
            }
        }

        can handle_slack_message() {
            # Forward Slack messages to our chat
            user = self.data.get("user_name", "SlackUser");
            text = self.data.get("text", "");
            channel = self.data.get("channel_name", "general");

            message = f"[Slack] {text}";
            self.send_to_chat(channel, user, message);
        }

        can send_to_chat(room_name: str, sender: str, message: str) {
            # Find or create room
            room = [-->(`?ChatRoom)](?name == room_name);
            if not room {
                room = ChatRoom(name=room_name);
                here ++> room;
            } else {
                room = room[0];
            }

            # Add message
            room.add_message(sender, message);
        }
    }

    walker get_webhook_logs {
        has source: str = "";
        has limit: int = 50;

        can fetch_logs with `root entry {
            all_logs = [-->(`?WebhookLog)];

            # Filter by source if specified
            if self.source {
                filtered_logs = [log for log in all_logs if log.source == self.source];
            } else {
                filtered_logs = all_logs;
            }

            # Get recent logs
            recent_logs = filtered_logs[-self.limit:];

            report {
                "logs": [
                    {
                        "source": log.source,
                        "event_type": log.event_type,
                        "received_at": log.received_at
                    }
                    for log in recent_logs
                ],
                "total": len(filtered_logs)
            };
        }
    }
    ```

### Testing Webhooks

Test webhook locally:

```bash
curl -X POST http://localhost:8000/walker/receive_webhook \
  -H "Content-Type: application/json" \
  -d '{
    "source": "github",
    "event_type": "push",
    "data": {
      "repository": {"name": "my-repo"},
      "commits": [{"message": "Fix critical bug"}]
    }
  }'
```

---

## Logging and Monitoring

Production applications require comprehensive logging and monitoring. Jac Cloud provides built-in observability features that integrate with your application logic.

### Application Logging

!!! example "Structured Logging System"
    ```jac
    # logging_chat.jac
    import from datetime { datetime }
    import from logging { getLogger }

    glob logger = getLogger("chat_app");

    node LogEntry {
        has level: str;
        has message: str;
        has timestamp: str;
        has context: dict = {};
    }

    walker log_activity {
        has level: str = "info";
        has message: str;
        has context: dict = {};

        can record_log with `root entry {
            # Create log entry
            log_entry = LogEntry(
                level=self.level,
                message=self.message,
                timestamp=datetime.now().isoformat(),
                context=self.context
            );
            here ++> log_entry;

            # Also log to system logger
            if self.level == "error" {
                logger.error(f"{self.message} | Context: {self.context}");
            } elif self.level == "warning" {
                logger.warning(f"{self.message} | Context: {self.context}");
            } else {
                logger.info(f"{self.message} | Context: {self.context}");
            }

            report {"log_id": log_entry.id, "logged_at": log_entry.timestamp};
        }
    }

    # Enhanced chat with logging
    walker send_logged_message {
        has room_name: str;
        has username: str;
        has message: str;

        can send_with_logging with `root entry {
            # Log the attempt
            log_activity(
                level="info",
                message="Message send attempt",
                context={
                    "room": self.room_name,
                    "user": self.username,
                    "message_length": len(self.message)
                }
            ) spawn here;

            # Find room
            room = [-->(`?ChatRoom)](?name == self.room_name);

            if not room {
                log_activity(
                    level="warning",
                    message="Message failed - room not found",
                    context={"room": self.room_name, "user": self.username}
                ) spawn here;

                report {"error": "Room not found"};
                return;
            }

            room = room[0];

            # Check if user can send
            if self.username not in room.users {
                log_activity(
                    level="warning",
                    message="Message failed - user not in room",
                    context={"room": self.room_name, "user": self.username}
                ) spawn here;

                report {"error": "User not in room"};
                return;
            }

            # Send message
            new_message = room.add_message(self.username, self.message);

            # Log success
            log_activity(
                level="info",
                message="Message sent successfully",
                context={
                    "room": self.room_name,
                    "user": self.username,
                    "message_id": new_message.id
                }
            ) spawn here;

            report {"status": "sent", "message_id": new_message.id};
        }
    }

    walker get_logs {
        has level: str = "";
        has limit: int = 100;

        can fetch_logs with `root entry {
            all_logs = [-->(`?LogEntry)];

            # Filter by level if specified
            if self.level {
                filtered_logs = [log for log in all_logs if log.level == self.level];
            } else {
                filtered_logs = all_logs;
            }

            # Get recent logs
            recent_logs = filtered_logs[-self.limit:];

            report {
                "logs": [
                    {
                        "level": log.level,
                        "message": log.message,
                        "timestamp": log.timestamp,
                        "context": log.context
                    }
                    for log in recent_logs
                ],
                "total": len(filtered_logs)
            };
        }
    }
    ```

---

## Background Tasks and Cleanup

Automated tasks are essential for maintenance, cleanup, and periodic operations.

### Scheduled Chat Maintenance

!!! example "Chat Room Cleanup Tasks"
    ```jac
    # scheduled_chat.jac
    import from datetime { datetime, timedelta }

    # Cleanup walker for maintenance tasks
    walker cleanup_inactive_rooms {
        has max_age_hours: int = 24;

        can perform_cleanup with `root entry {
            current_time = datetime.now();
            cleanup_count = 0;

            # Find all rooms
            all_rooms = [-->(`?ChatRoom)];

            for room in all_rooms {
                # Check if room has been inactive
                if len(room.users) == 0 {
                    # Get latest message
                    messages = [room --> ChatMessage];

                    if not messages {
                        # No messages, delete empty room
                        del room;
                        cleanup_count += 1;
                    } else {
                        # Check last message age
                        latest_message = messages[-1];
                        message_time = datetime.fromisoformat(latest_message.timestamp);

                        if (current_time - message_time).total_seconds() > (self.max_age_hours * 3600) {
                            # Room is too old, cleanup
                            for msg in messages {
                                del msg;
                            }
                            del room;
                            cleanup_count += 1;
                        }
                    }
                }
            }

            # Log cleanup results
            log_activity(
                level="info",
                message="Cleanup task completed",
                context={
                    "rooms_cleaned": cleanup_count,
                    "total_rooms": len([-->(`?ChatRoom)])
                }
            ) spawn here;

            report {
                "status": "cleanup_completed",
                "rooms_cleaned": cleanup_count,
                "timestamp": current_time.isoformat()
            };
        }
    }

    # Daily statistics walker
    walker generate_daily_stats {
        can collect_stats with `root entry {
            # Count active rooms and users
            all_rooms = [-->(`?ChatRoom)];
            total_rooms = len(all_rooms);
            total_users = sum(len(room.users) for room in all_rooms);

            # Count messages sent today
            today = datetime.now().date();
            all_messages = [-->(`?ChatMessage)];

            today_messages = 0;
            for msg in all_messages {
                msg_date = datetime.fromisoformat(msg.timestamp).date();
                if msg_date == today {
                    today_messages += 1;
                }
            }

            # Create stats report
            stats = {
                "date": today.isoformat(),
                "active_rooms": total_rooms,
                "active_users": total_users,
                "messages_today": today_messages,
                "generated_at": datetime.now().isoformat()
            };

            # Log daily stats
            log_activity(
                level="info",
                message="Daily statistics generated",
                context=stats
            ) spawn here;

            report stats;
        }
    }
    ```

### Manual Task Execution

```bash
# Run cleanup manually
curl -X POST http://localhost:8000/walker/cleanup_inactive_rooms \
  -H "Content-Type: application/json" \
  -d '{"max_age_hours": 48}'

# Generate daily stats
curl -X POST http://localhost:8000/walker/generate_daily_stats \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Best Practices

!!! summary "Cloud Development Guidelines"
    - **Use environment variables**: Keep configuration flexible and secure
    - **Structure your logs**: Use consistent logging patterns for debugging
    - **Validate webhooks**: Always verify webhook sources and data
    - **Monitor performance**: Track application metrics and health
    - **Handle failures gracefully**: Implement retry logic and fallback patterns
    - **Secure sensitive data**: Never commit secrets or API keys to code

## Key Takeaways

!!! summary "What We've Learned"
    **Configuration Management:**

    - **Environment variables**: Flexible application configuration without code changes
    - **Security patterns**: Keep sensitive data in environment variables, not code
    - **Multi-environment support**: Different settings for development, staging, production
    - **Runtime configuration**: Adjust application behavior without redeployment

    **Integration Capabilities:**

    - **Webhook support**: Receive real-time notifications from external services
    - **RESTful architecture**: All walkers become scalable API endpoints
    - **External service integration**: Connect with third-party APIs and services
    - **Event-driven patterns**: Build reactive applications that respond to external events

    **Monitoring and Observability:**

    - **Structured logging**: Built-in logging patterns for debugging and monitoring
    - **Performance tracking**: Monitor application health and performance metrics
    - **Error handling**: Graceful error recovery and reporting
    - **Audit trails**: Track important application events and user actions

    **Production Features:**

    - **Background tasks**: Automated maintenance and cleanup operations
    - **Data management**: Efficient patterns for data lifecycle management
    - **Scalability**: Built-in support for horizontal scaling
    - **Reliability**: Robust patterns for production deployment

!!! tip "Try It Yourself"
    Enhance your cloud applications by adding:
    - Real-time chat with webhook integrations
    - Automated data backup and cleanup tasks
    - External service integrations (email, SMS, payments)
    - Comprehensive monitoring and alerting systems

    Remember: All these advanced features work seamlessly with Jac's scale-agnostic architecture!

---

*Ready to master Jac's type system? Continue to [Chapter 17: Type System Deep Dive](chapter_16.md)!*
