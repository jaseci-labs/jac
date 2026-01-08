# Async Walker

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## Overview

Async walkers in Jac Cloud allow you to execute walkers asynchronously in separate threads. This is particularly useful for long-running operations that shouldn't block the main execution flow, such as intensive computations or external API calls.

## Basic Usage

To create an async walker, simply add the `async` keyword before the walker declaration:

```jac
async walker sample {
    has value: int = 0;

    can enter with `root entry {
        print("test");
        self.value = 1;
    }
}
```

Key characteristics:

- Executes in a separate thread without blocking the main application
- Returns immediately with a reference ID while continuing execution in the background
- Similar to task scheduling but with a simpler syntax
- Results can be retrieved later using the walker ID

## How It Works

1. When an async walker is triggered, it's scheduled as a background task
2. The API call returns immediately with a walker ID reference
3. The walker executes asynchronously in its own thread
4. Results are stored in the database and can be retrieved later

## Response Format

When you call an async walker, you receive a response containing the walker's unique ID:

```json
{
  "status": 200,
  "walker_id": "w:sample:550e8400-e29b-41d4-a716-446655440000"
}
```

## Retrieving Results

You can retrieve the results of an async walker by using its ID:

```jac
walker view_sample_result {
    has walker_id: str;

    can enter with `root entry {
        # Get a reference to the walker instance
        wlk = &walker_id;

        # Access the walker's attributes
        print(wlk.value);  # Will be 1 after execution completes

        # Check execution status and metadata
        schedule_info = wlk.__jac__.schedule;

        # Print execution details
        print(f"Status: {schedule_info.status}");
        print(f"Executed at: {schedule_info.executed_date}");

        # Check for errors
        if schedule_info.error{
            print(f"Error: {schedule_info.error}");
        }
    }
}
```

## Available Status Information

The `__jac__.schedule` object contains all execution metadata:

| **Field**       | **Description**                                                |
| --------------- | -------------------------------------------------------------- |
| `status`        | Current execution status (pending, running, completed, failed) |
| `node_id`       | ID of the node where the walker was executed                   |
| `root_id`       | ID of the root node of the user who triggered the walker       |
| `execute_date`  | When the walker was scheduled to execute                       |
| `executed_date` | When the walker actually executed                              |
| `http_status`   | HTTP status code for the execution result                      |
| `reports`       | Any values reported during walker execution                    |
| `custom`        | Custom metadata associated with the walker                     |
| `error`         | Error message if execution failed                              |

### Even though those fields are available, we still recommend using a walker's attribute as your status checker for more customizable and direct status updates.

## Example: Long-Running Process

```jac
async walker process_large_dataset {
    has dataset_id: str;
    has results: list = [];

    can enter with `root entry {
        # Simulate long-running process
        dataset = get_dataset(self.dataset_id);

        for item in dataset{
            # Do intensive processing
            processed = complex_computation(item);
            self.results.append(processed);
        }

        # Final result is stored in the walker
        print("Processing complete!");
    }
}

# Retrieve results when needed
walker check_processing {
    has process_id: str;

    can enter with `root entry {
        process = &process_id;

        if process.__jac__.schedule.status == "COMPLETED"{
            print("Results:", process.results);
        }
        else{
            print("Still processing...");
        }
    }
}
```

## Common Use Cases

### 1. Processing Large Datasets

```jac
async walker analyze_data {
    has dataset_id: str;
    has summary: dict = {};

    can enter with `root entry {
        # Fetch data (could take minutes)
        data = fetch_dataset(self.dataset_id);

        # Process each item (CPU intensive)
        for item in data{
            process_item(item);
        }

        # Generate final summary
        self.summary = create_summary(data);
    }
}
```

### 2. Generating Reports

```jac
async walker generate_report {
    has user_id: str;
    has report_type: str;
    has report_url: str;

    can enter with `root entry {
        # Collect user data
        user_data = fetch_user_data(self.user_id);

        # Generate PDF (slow operation)
        report_file = create_pdf_report(user_data, self.report_type);

        # Upload to storage
        self.report_url = upload_file(report_file);

        # Optional: Notify user
        send_email(self.user_id, "Your report is ready!", self.report_url);
    }
}
```

### 3. External API Integration

```jac
async walker sync_with_external_system {
    has account_id: str;
    has sync_status: str = "pending";
    has sync_results: list = [];

    can enter with `root entry {
        # Connect to external API
        self.sync_status = "connecting";
        api_client = connect_to_api();

        # Fetch data (network-bound, can be slow)
        self.sync_status = "fetching";
        external_data = api_client.fetch_account_data(self.account_id);

        # Process and save data
        self.sync_status = "processing";
        for item in external_data{
            result = process_and_save(item);
            self.sync_results.append(result);
        }

        self.sync_status = "complete";
    }
}
```

## Advanced Techniques

### Combining with WebSockets for Real-time Updates

```jac
import from jac_cloud.plugin {WEBSOCKET_MANAGER as socket}

async walker process_with_updates {
    has client_id: str;
    has progress: int = 0;

    can enter with `root entry {
        # Send initial notification
        socket.notify_clients([self.client_id], {
            "type": "progress",
            "data": {"progress": 0}
        });

        # Process in chunks and send updates
        for i in range(10){
            process_chunk(i);
            self.progress = (i+1) * 10;

            # Send progress update via WebSocket
            socket.notify_clients([self.client_id], {
                "type": "progress",
                "data": {"progress": self.progress}
            });
        }

        # Send completion notification
        socket.notify_clients([self.client_id], {
            "type": "complete",
            "data": {"message": "Processing complete!"}
        });
    }
}
```

### Error Handling

```jac
async walker safe_process {
    has input_id: str;
    has success: bool = False;
    has error_message: str = "";
    has results: dict = {};

    can enter with `root entry {
        try {
            # Attempt processing
            data = fetch_data(self.input_id);
            if not data{
                self.error_message = "No data found";
                return;
            }

            self.results = process_data(data);
            self.success = True;
        } except e {
            # Capture error details
            self.error_message = str(e);
            log_error(self.input_id, str(e));
        }
    }
}
```

## Next Steps

- Learn about [Task Scheduling](scheduler.md) for recurring tasks
- Explore [WebSockets](websocket.md) for real-time communication
- Set up [Logging](logging.md) to monitor your async processes
