# WebSocket: Real-Time Communication

## Overview

WebSockets enable real-time, bidirectional communication between clients and your Jac application. This is particularly useful for:

- Chat applications
- Real-time dashboards
- Collaborative tools
- Live notifications
- Any application requiring instant updates

## Walker Declaration for WebSockets

You can declare a walker to handle WebSocket connections by setting the `methods` property to include `"websocket"` in the `__specs__` configuration:

```jac
walker your_event_name {
    has val: int;

    can enter with `root entry {
        report "Do something!";
    }

    class __specs__ {
        has methods: list = ["websocket"];
    }
}
```

**Note**: WebSocket walkers can still work with other HTTP methods; however, they currently don't support file uploads.

## WebSocket Connection Details

### Connection URL and Parameters

- **Protocol**: `ws`
- **URL**: `/websocket`
- **Optional Header**: `Authorization: Bearer {{USER-TOKEN}}`
- **Optional Query Parameter**: `?channel_id=anystring`

### Connection Process

When a client connects to the WebSocket endpoint, it will immediately receive a connection information event:

```python
{
	"type": "connection",
	"data": {
        # your websocket client id
		"client_id": "1730887348:f46d85203c704c099e9f44e948322a20",

        # user's root_id
		"root_id": "n::672b35cec309e5ef8469c372",

        # non authenticated
		# "root_id": "n::000000000000000000000001",

        # user's channel id, random if not specified
		"channel_id": "1730887348:796ad2e9fa3e484ebe01f071c381b7e8"
	}
}
```

### Connection Types

There are two types of connections:

1. **Authenticated Connection** - Uses a valid Authorization token
2. **Non-Authenticated Connection** - Public access

### Channel Subscription

You can specify a `channel_id` via query parameter to receive notifications from a specific channel. This is particularly useful for group chat or notification applications.

## Client Event Types

Clients can send different types of events to the server through the WebSocket connection:

### 1. Walker Event

Triggers a walker just like a REST API call:

```python
{
    # event type
	"type": "walker",

    # walker's name
	"walker": "your_event_name",

    # if you want to receive a notification for response
	"response": true,

    # walker's request context
	"context": {
        "val": 1
    }
}
```

### 2. User Event

Sends a notification to specific users:

```python
{
    # event type
	"type": "user",

    # target user/s via root_id
    "root_ids": ["n::672b35cec309e5ef8469c372"],

    # data you want to send
	"data": {
        "val": 1
    }
}
```

### 3. Channel Event

Sends a notification to all clients subscribed to specific channels:

```python
{
    # event type
	"type": "channel",

    # target channel_id/s
    "channel_ids": ["anystring"],

    # data you want to send
	"data": {
        "val": 1
    }
}
```

### 4. Client Event

Sends a notification to specific clients:

```python
{
    # event type
	"type": "client",

    # target client_ids
    "client_ids": ["1730887348:f46d85203c704c099e9f44e948322a20"],

    # data you want to send
	"data": {
        "val": 1
    }
}
```

### 5. Change User Event

Switches between authenticated and public user:

```python
{
    # event type
	"type": "change_user",

    # optional - defaults to public user
	"token": "bearer {{user's token}}"
}
```

## Server-Side Notification Methods

### Prerequisites

To send notifications from your walker, import the WebSocket manager:

```python
import from jac_cloud.plugin {WEBSOCKET_MANAGER as socket}
```

### Available Notification Methods

#### 1. Self Notification

Sends a notification to the current WebSocket client (only valid on WebSocket walker events):

```python
socket.notify_self({"any_field": "for_progress", "progress": "0%", "status": "started"});
```

#### 2. User Notification

Sends a notification to all clients of specific users:

```python
socket.notify_users([root], {"any_field": "for_progress", "progress": "0%", "status": "started"});
```

#### 3. Channel Notification

Sends a notification to all clients subscribed to specific channels:

```python
socket.notify_channels([channel_id], {"any_field": "for_progress", "progress": "0%", "status": "started"});
```

#### 4. Client Notification

Sends a notification to specific client connections:

```python
socket.notify_clients([client_id], {"any_field": "for_progress", "progress": "0%", "status": "started"});
```

## End-to-End Integration Example

### Server-Side (Jac)

```jac
"""Websocket scenarios."""
import from jac_cloud.plugin {WEBSOCKET_MANAGER as socket}

###########################################################
#                   WEBSOCKET ENDPOINTS                   #
###########################################################

walker send_chat_to_user {
    has root_id: str;

    can enter1 with `root entry {
        _root = &(self.root_id);

        socket.notify_users([_root], {"type": "chat", "data": {"message": "string"}});
    }

    class __specs__ {
        has methods: list = ["websocket", "post"];
    }
}


walker send_chat_to_group {
    has channel_id: str;

    can enter1 with `root entry {
        socket.notify_channels([self.channel_id], {"type": "chat", "data": {"message": "string"}});
    }

    class __specs__ {
        has methods: list = ["websocket", "post"];
    }
}

walker send_chat_to_client {
    has client_id: str;

    can enter1 with `root entry {
        socket.notify_clients([self.client_id], {"type": "chat", "data": {"message": "string"}});
    }

    class __specs__ {
        has methods: list = ["websocket", "post"];
    }
}
```

### Client-Side (JavaScript)

#### WebSocket Connection

**Important Note**: The JavaScript WebSockets API doesn't natively support headers for authentication. You'll need to use the `change_user` event or a third-party WebSocket library that supports headers.

```js
//####################################################//
//           NOT AUTHENTICATED - JS LIBRARY           //
//####################################################//
const client = new WebSocket("ws://localhost:8000/websocket");

//####################################################//
//             AUTHENTICATED - JS LIBRARY             //
//####################################################//

const client = new WebSocket("ws://localhost:8000/websocket");
client.onopen = (event) => {
  client.send(JSON.stringify({
    "type": "change_user",
    "token": "Bearer {{user's token}}" // optional - default to public user
  }));
};

//####################################################//
//           AUTHENTICATED - NPM WS LIBRARY           //
//####################################################//
import WebSocket from 'ws';

const client = new WebSocket('ws://localhost:8000/websocket', {
  headers: {
    "Authorization": "Bearer {{user's token}}"
  }
});
```

#### Consuming Events

```js
client.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  switch (msg.type) {
    case "connection":
      // to check connection info
    case "chat":
      console.log(msg.data)
    case "your_event1":
      console.log(msg.data)
    case "your_event2":
      console.log(msg.data)
    case "your_event3":
      console.log(msg.data)
  }
};
```

#### Publishing Events

```js
// TRIGGER WALKER EVENT
client.send(JSON.stringify({
	"type": "walker",
	"walker": "your_walker_name",
	"response": true,
	"context": {}
}));

// TRIGGER CLIENT EVENT (ex: direct chat)
client.send(JSON.stringify({
	"type": "client",
	"client_ids": ["target client_id from connection event"],
	"data": {
		"type": "chat",
    "data": {
      "any_field": "any_value"
    }
	}
}));

// TRIGGER CHANNEL EVENT (ex: group chat or chat blast)
client.send(JSON.stringify({
	"type": "channel",
	"channel_ids": ["target channel_id from connection event"],
	"data": {
		"type": "chat",
    "data": {
      "any_field": "any_value"
    }
	}
}));

// TRIGGER USER EVENT (ex: chat but all target user's client)
client.send(JSON.stringify({
	"type": "user",
	"root_ids": ["target root_id from connection event"],
	"data": {
		"type": "chat",
    "data": {
      "any_field": "any_value"
    }
	}
}));

// TRIGGER CONNECTION EVENT - to get connection info)
client.send(JSON.stringify({
	"type": "connection"
}));
```

## Best Practices

1. **Use Channels for Group Communication**: Instead of sending messages to multiple clients individually, use channels.
2. **Handle Reconnection Logic**: Implement reconnection logic in your client to handle network disruptions.
3. **Validate All Messages**: Always validate incoming messages to prevent security issues.
4. **Set Ping/Pong Timeouts**: Configure appropriate ping/pong intervals to detect disconnected clients.
5. **Use Authorization**: For private communications, always use authenticated connections.

## Common Use Cases

- **Chat Applications**: Real-time messaging between users
- **Notifications**: Instant alerts and notifications
- **Live Updates**: Real-time updates to dashboards or data displays
- **Collaborative Tools**: Multiple users working on the same document or project
- **Gaming**: Real-time multiplayer games

## Troubleshooting

- **Connection Issues**: Verify the WebSocket URL and ensure your server is running
- **Authentication Problems**: Check that your token is valid and properly formatted
- **Message Delivery Failures**: Confirm that client IDs, user IDs, or channel IDs are correct
- **Performance Issues**: Consider using channels instead of individual client notifications for better performance

---
### Additional Resources
For a complete working example, you may download this [API Request Collection](https://github.com/amadolid/jaseci/blob/websocket-backup-final/jac-cloud/jac_cloud/tests/jac-cloud-websocket.insomnia)