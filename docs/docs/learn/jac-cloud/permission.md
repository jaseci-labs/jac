# Permission Management: Secure Multi-User Access

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## Why Permissions Matter

Jac Cloud's permission system lets you control who can access different parts of your application. This is crucial for:

- Building multi-user applications
- Protecting sensitive data
- Enabling collaboration features
- Creating public/private content
- Implementing access control

## Key Concepts for Beginners

### Understanding Data Representations

In Jac Cloud, your data exists in two forms:

- Anchor
  - EdgeAnchor
  - NodeAnchor
  - ObjectAnchor
  - WalkerAnchor
- Archetype
  - EdgeArchetype
  - NodeArchetype
  - ObjectArchetype
  - WalkerArchetype

#### **Anchors** are database-side class representations that contain:

| Name      | Description                                                       |
| --------- | ----------------------------------------------------------------- |
| id        | The database identifier.                                          |
| name      | The name of the associated archetype.                             |
| root      | The owning root anchor.                                           |
| access    | Permissions defining which nodes or roots can access this anchor. |
| archetype | The JSON representation of the actual archetype.                  |

#### **Archetypes** are the runtime class representations, directly reflecting fields declared in Jac source code. Dev can access their respective anchors via the `__jac__` attribute

### Permission Levels Explained

Jac Cloud has four permission levels that control what users can do:

| Level       | Description                          | Example Use Case           |
| ----------- | ------------------------------------ | -------------------------- |
| `NoPerm` | Cannot see or interact with the item | Private user data          |
| `ReadPerm`      | Can view but not modify the item     | Public profile information |
| `ConnectPerm`   | Can link nodes to this node          | Friend requests, comments  |
| `WritePerm`     | Full access to modify the item       | User's own content         |

## How Permissions Work (Simple Example)

Imagine a social media app with three users:

```
Root1 → User1 → Post1
Root2 → User2 → Post2
Root3 → User3 → Post3
```

By default, User2 cannot see Post1 (created by User1). To allow this:

1. User1 must explicitly grant permission to User2
2. This creates a connection in the permissions system
3. Now User2 can access Post1 according to the permission level granted

## Managing Permissions in Code

### Grant Access Using Helper Functions

```jac
# Allow User2 to read a post
walker grant_access {
    has target_root_id: str;  # ID of User2's root
    has access_level: str;    # ReadPerm, ConnectPerm, or WritePerm

    can grant_access with post entry {
        # Grant access to the current post
        _.allow_root(here, NodeAnchor.ref(self.target_root_id), self.access_level);
        report "Access granted!";
    }
}
```

The code snippet `_.allow_root(here, NodeAnchor.ref(self.target_root_id), self.access_level)` facilitates granting a specified level of access to a target root node from the current node.

Here's a breakdown of the components:

- `here`

  - Represents the current node, which in this context is the post node.

- `NodeAnchor.ref(self.target_root_id)`

  - This converts the target_root_id (a string identifier) into a NodeAnchor representation. This NodeAnchor then points to the specific target root node that will be granted access.

- `self.access_level`
  - This parameter specifies the level of access that the target root node will have to the current node's data (i.e., the post node's data).

In essence, this line of code enables the post node to grant the designated target root node permission to access its data, with the access permissions defined by self.access_level.

### Revoke Access Using Helper Functions

```jac
# Remove User2's access to a post
walker revoke_access {
    has target_root_id: str;  # ID of User2's root

    can revoke_access with post entry {
        # Revoke access to the current post
        _.disallow_root(here, NodeAnchor.ref(self.target_root_id));
        report "Access revoked!";
    }
}
```

The code snippet `_.disallow_root(here, NodeAnchor.ref(self.target_root_id))` performs the inverse operation of `_.allow_root`; it removes existing access permissions that a target root node had to the current node's data.

Here's how it works:

- `here`
  - This refers to the current node, which, as before, is the post node. This is the node from which the permission is being revoked.
- `NodeAnchor.ref(self.target_root_id)`
  - This converts the target_root_id (a string identifier) into a NodeAnchor representation. This NodeAnchor pinpoints the specific target root node whose access privileges are being revoked.

In essence, this line of code instructs the post node to remove the previously granted access for the designated target root node to its data.

### Make Content Public

```jac
# Make a post readable by everyone
walker make_public {
    can make_public with post entry {
        # Grant READ access to all users
        grant(here, ReadPerm);
        report "Post is now public!";
    }
}
```

The code snippet `grant(here, ReadPerm)` provides a mechanism to grant read access to all other root nodes concerning the data within the current node.

Here's a breakdown of the elements:

- `here`
  - This represents the current node, which in this case is the post node. This is the node whose data will be accessible.
- `ReadPerm`
  - This literal string specifies the type of permission being granted. In this instance, it grants read access, allowing other root nodes to view the data on the post node. They can choose one from permission levels.

### Make Content Private

```jac
# Make a post private (owner-only)
walker make_private {
    can make_private with post entry {
        # Remove all access
        revoke(here);
        report "Post is now private!";
    }
}
```

The code snippet `revoke(here)` is used to remove all previously granted access permissions from all other root nodes to the current node's data. It's the inverse operation of `grant`.

Here's a breakdown:

- `here`
  - This represents the current node (in this context, the post node) from which all access will be revoked.

Essentially, this line of code completely withdraws any permissions that were previously granted to other root nodes, making the post node's data inaccessible to them.

## Common Permission Patterns

### Public Read, Private Write

Perfect for social media posts or articles:

```jac
# Create a public post
walker create_public_post {
    has content: str;

    can enter with `root entry {
        # Create the post
        post = Post({content: self.content});
        here ++> post;

        # Make it readable by everyone, but only writable by owner
        grant(post, ReadPerm);

        report "Public post created!";
    }
}
```

### Group Access

Ideal for team collaboration:

```jac
# Grant access to a team
walker grant_team_access {
    has team_members: list[str];  # List of root IDs
    has access_level: str;        # ReadPerm, ConnectPerm, or WritePerm

    can grant_access with document entry {
        # Grant access to each team member
        for member_id in self.team_members {
            _.allow_root(here, NodeAnchor.ref(member_id), self.access_level);
        }

        report "Team access granted!";
    }
}
```

### Connection-based Permissions

For friend systems or social networks:

```jac
# Only friends can see posts
walker check_access {
    has viewer_id: str;

    can check with post entry {
        owner = [post<--][0];

        # Check if viewer is friends with owner
        is_friend = False;
        for friend in [owner -->] {
            if friend.id == self.viewer_id {
                is_friend = True;
                break;
            }
        }

        if is_friend {
            # Grant access if they're friends
            _.allow_root(here, NodeAnchor.ref(self.viewer_id), "READ");
            report "Access granted to friend!";
        } else {
            report "Access denied - not a friend!";
        }
    }
}
```

## Best Practices for Beginners

1. **Start restrictive**: Begin with tight permissions and open up as needed
2. **Use helper functions**: Prefer `_.allow_root()` over direct manipulation
3. **Check permissions**: Use `_.check_read_access()` to verify permissions
4. **Document your scheme**: Keep track of which nodes have which permissions
5. **Batch similar permissions**: Update permissions for multiple nodes at once

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time features
- Explore [Webhook Integration](webhook.md) for third-party service integration
- Set up [Logging & Monitoring](logging.md) to track access patterns

# Custom Access Validation

> This will only get triggered if the target node is not owned by current root

```jac
node A {
    # suggested to be `with access {}`
    def __jac_access__ {

        ###############################################
        #              YOUR PROCESS HERE              #
        ###############################################

        # Allowed string return NoPerm, ReadPerm, ConnectPerm, or WritePerm
        return NoPerm;

        # Allowed enum return AccessLevel.NO_ACCESS, AccessLevel.READ, AccessLevel.ConnectPerm, AccessLevel.WRITE
        # return AccessLevel.NO_ACCESS;

        # Not recommended as it may change in the future
        # Allowed int return -1 (NoPerm), 0 (ReadPerm), 1 (ConnectPerm), 2 (WritePerm)
        # return -1;

    }
}
```

> if you wish to prioritize current access validation and process it afterwards, you may follow this code

```jac
node A {
    # suggested to be `with access {}`
    def __jac_access__ {

        level = _Jac.check_access_level(here, True); # True means skip custom access validation trigger to avoid infinite loop

        ###############################################
        #              YOUR PROCESS HERE              #
        ###############################################

        # Allowed string return NoPerm, ReadPerm, ConnectPerm, or WritePerm
        return "NO_ACCESS";

        # Allowed enum return AccessLevel.NO_ACCESS, AccessLevel.READ, AccessLevel.ConnectPerm, AccessLevel.WRITE
        # return AccessLevel.NO_ACCESS;

        # Not recommended as it may change in the future
        # Allowed int return -1 (NoPerm), 0 (ReadPerm), 1 (ConnectPerm), 2 (WritePerm)
        # return -1;

    }
}
```
