"""Test API fixture for jac-scale serve tests."""

# ============================================================================
# Test Functions
# ============================================================================
def add_numbers(
    a: int, b: int
) -> int {
    return a + b;
}

def greet(name: str = "World") -> str {
    return "Hello, " + name + "!";
}

def multiply(x: int, y: int) -> int {
    return x * y;
}

# ============================================================================
# Test Data Models
# ============================================================================
node Task {
    has title: str;
    has priority: int = 1;
    has completed: bool = False;
}

node TaskList {
    has name: str = "My Tasks";
}

# ============================================================================
# Test Walkers
# ============================================================================
walker CreateTask {
    has title: str;
    has priority: int = 1;

    can create with `root entry {
        new_task = here ++> Task(title=self.title, priority=self.priority);
        report new_task ;
    }
}

walker ListTasks {
    can list with `root entry {
        tasks = [-->];
        report tasks ;
    }
}

walker CompleteTask {
    has title: str;

    can complete with `root entry {
        for task in [-->] {
            if task.title == self.title {
                visit task;
            }
        }
    }

    can mark_done with Task entry {
        here.completed = True;
        report here ;
    }
}

walker GetTask {
    can get with Task entry {
        report here ;
    }
}

walker : priv PrivateCreateTask {
    has title: str;
    has priority: int = 1;

    can create with `root entry {
        new_task = here ++> Task(title=self.title, priority=self.priority);
        report {"message": "Private task created", "task": new_task} ;
    }
}

walker : pub PublicInfo {
    can get_info with `root entry {
        report {"message": "This is a public endpoint", "auth_required": False} ;
    }
}

# Streaming Walker Test
walker : pub WalkerStream {
    has count: int = 3;

    can stream_reports with `root entry {
        def stream -> str {
            import time;
            for i in range(self.count) {
                time.sleep(0.5);
                yield f"Report {i}";
            }
        }
        report stream();
    }
}

import from typing { Generator }
# Streaming function test
def : pub FunctionStream(count: int = 3) -> Generator {
    import time;
    def stream -> Generator {
        for i in range(count) {
            time.sleep(0.5);
            yield f"Func {i}";
        }
    }
    report stream();
}

# Async Walker Test
import asyncio;

"""Async walker that creates a task with simulated async delay."""
async walker AsyncCreateTask {
    has title: str;
    has delay_ms: int = 100;

    async can create with `root entry {
        report {"status": "started", "title": self.title};
        # Simulate async operation (e.g., external API call, DB operation)
        delay_seconds = float(self.delay_ms) / 1000.0;
        await asyncio.sleep(delay_seconds);
        report {"status": "after_async_wait"};
        new_task = here ++> Task(title=self.title, priority=1);
        report {"status": "completed", "task": new_task};
    }
}

# ============================================================================
# File Upload Walkers
# ============================================================================
import from fastapi { UploadFile }

"""Walker that handles single file upload."""
walker UploadSingleFile {
    has myfile: UploadFile;
    has description: str = "";

    can process with `root entry {
        report {
            "filename": self.myfile.filename,
            "content_type": self.myfile.content_type,
            "size": self.myfile.size,
            "description": self.description
        };
    }
}

"""Walker with file upload that requires authentication (private by default)."""
walker SecureFileUpload {
    has document: UploadFile;
    has notes: str = "";

    can process with `root entry {
        report {
            "filename": self.document.filename,
            "content_type": self.document.content_type,
            "size": self.document.size,
            "notes": self.notes,
            "authenticated": True
        };
    }
}

"""Public walker with file upload (no auth required)."""
walker : pub PublicFileUpload {
    has attachment: UploadFile;

    can process with `root entry {
        report {
            "filename": self.attachment.filename,
            "content_type": self.attachment.content_type,
            "size": self.attachment.size,
            "public": True
        };
    }
}
