# Chapter 21: Python to Jac Migration

In this chapter, we'll explore practical strategies for migrating Python applications to Jac. We'll progressively convert a simple library management system from Python to Jac, demonstrating migration patterns, integration strategies, and common pitfalls to avoid.

!!! info "What You'll Learn"
    - Strategic approaches to Python-to-Jac migration
    - Converting Python classes to Jac objects and nodes
    - Incremental adoption patterns for existing codebases
    - Python integration patterns within Jac applications
    - Common migration pitfalls and how to avoid them

---

## Migration Strategies

Migrating from Python to Jac doesn't require rewriting everything from scratch. Jac's Python compatibility enables gradual migration, allowing you to adopt Object-Spatial Programming incrementally while maintaining existing functionality.

!!! success "Migration Benefits"
    - **Gradual Transition**: Migrate components incrementally
    - **Python Compatibility**: Existing Python libraries work seamlessly
    - **Improved Performance**: Benefit from Jac's optimizations
    - **Modern Patterns**: Adopt Object-Spatial Programming gradually
    - **Risk Mitigation**: Test new features alongside existing code

### Migration Approaches

!!! tip "Recommended Migration Strategies"
    1. **Top-Down**: Start with high-level architecture, then migrate details
    2. **Bottom-Up**: Begin with utility functions and data structures
    3. **Feature-by-Feature**: Migrate complete features one at a time
    4. **Hybrid Integration**: Run Python and Jac code side-by-side

---

## Starting Point: Python Library System

Let's begin with a traditional Python library management system that we'll progressively migrate to Jac.

### Original Python Implementation

!!! example "Python Library System"
    === "Python Original"
        ```python
        # library.py - Traditional Python implementation
        from datetime import datetime
        from typing import List, Optional

        class Book:
            def __init__(self, title: str, author: str, isbn: str):
                self.title = title
                self.author = author
                self.isbn = isbn
                self.is_borrowed = False
                self.borrowed_by = None
                self.borrowed_date = None

            def borrow(self, member_id: str) -> bool:
                if not self.is_borrowed:
                    self.is_borrowed = True
                    self.borrowed_by = member_id
                    self.borrowed_date = datetime.now()
                    return True
                return False

            def return_book(self) -> bool:
                if self.is_borrowed:
                    self.is_borrowed = False
                    self.borrowed_by = None
                    self.borrowed_date = None
                    return True
                return False

        class Member:
            def __init__(self, name: str, member_id: str):
                self.name = name
                self.member_id = member_id
                self.borrowed_books: List[str] = []

            def add_borrowed_book(self, isbn: str):
                if isbn not in self.borrowed_books:
                    self.borrowed_books.append(isbn)

            def remove_borrowed_book(self, isbn: str):
                if isbn in self.borrowed_books:
                    self.borrowed_books.remove(isbn)

        class Library:
            def __init__(self, name: str):
                self.name = name
                self.books: List[Book] = []
                self.members: List[Member] = []

            def add_book(self, book: Book):
                self.books.append(book)

            def add_member(self, member: Member):
                self.members.append(member)

            def find_book(self, isbn: str) -> Optional[Book]:
                for book in self.books:
                    if book.isbn == isbn:
                        return book
                return None

            def borrow_book(self, isbn: str, member_id: str) -> bool:
                book = self.find_book(isbn)
                member = self.find_member(member_id)

                if book and member and book.borrow(member_id):
                    member.add_borrowed_book(isbn)
                    return True
                return False

            def find_member(self, member_id: str) -> Optional[Member]:
                for member in self.members:
                    if member.member_id == member_id:
                        return member
                return None
        ```

    === "Jac Modern Equivalent"
        ```jac
        # library.jac - Modern Jac implementation preview
        import from datetime { datetime }

        node Book {
            has title: str;
            has author: str;
            has isbn: str;
            has is_borrowed: bool = False;
            has borrowed_date: str = "";

            def borrow(member_id: str) -> bool {
                if not self.is_borrowed {
                    self.is_borrowed = True;
                    self.borrowed_date = datetime.now().isoformat();
                    return True;
                }
                return False;
            }

            def return_book() -> bool {
                if self.is_borrowed {
                    self.is_borrowed = False;
                    self.borrowed_date = "";
                    return True;
                }
                return False;
            }
        }

        node Member {
            has name: str;
            has member_id: str;
        }

        edge BorrowedBy {
            has borrowed_date: str;
        }

        node Library {
            has name: str;

            def add_book(book: Book) -> None {
                self ++> book;
            }

            def add_member(member: Member) -> None {
                self ++> member;
            }

            def borrow_book(isbn: str, member_id: str) -> bool {
                book = [self --> Book](?isbn == isbn);
                member = [self --> Member](?member_id == member_id);

                if book and member and book[0].borrow(member_id) {
                    member[0] +:BorrowedBy:borrowed_date=datetime.now().isoformat():+> book[0];
                    return True;
                }
                return False;
            }
        }
        ```

---

## Step 1: Converting Classes to Objects

The first migration step involves converting Python classes to Jac objects while maintaining similar functionality.

### Basic Class to Object Migration

!!! example "Class to Object Conversion"
    === "Python Class"
        ```python
        # book.py - Python class
        class Book:
            def __init__(self, title: str, author: str, isbn: str):
                self.title = title
                self.author = author
                self.isbn = isbn
                self.is_borrowed = False

            def get_info(self) -> str:
                status = "Available" if not self.is_borrowed else "Borrowed"
                return f"{self.title} by {self.author} - {status}"

            def borrow(self) -> bool:
                if not self.is_borrowed:
                    self.is_borrowed = True
                    return True
                return False
        ```

    === "Jac Object"
        ```jac
        # book.jac - Jac object
        obj Book {
            has title: str;
            has author: str;
            has isbn: str;
            has is_borrowed: bool = False;

            def get_info() -> str {
                status = "Available" if not self.is_borrowed else "Borrowed";
                return f"{self.title} by {self.author} - {status}";
            }

            def borrow() -> bool {
                if not self.is_borrowed {
                    self.is_borrowed = True;
                    return True;
                }
                return False;
            }
        }
        ```

!!! tip "Key Migration Changes"
    - `class` → `obj`
    - `__init__` → automatic constructor with `has`
    - `:` → `;` for statement termination
    - `{}` for code blocks instead of indentation

### Testing the Migration

!!! example "Migration Testing"
    === "Python Usage"
        ```python
        # test_book.py
        book = Book("The Great Gatsby", "F. Scott Fitzgerald", "123456789")
        print(book.get_info())  # The Great Gatsby by F. Scott Fitzgerald - Available

        success = book.borrow()
        print(f"Borrowed: {success}")  # Borrowed: True
        print(book.get_info())  # The Great Gatsby by F. Scott Fitzgerald - Borrowed
        ```

    === "Jac Usage"
        ```jac
        # test_book.jac
        with entry {
            book = Book(title="The Great Gatsby", author="F. Scott Fitzgerald", isbn="123456789");
            print(book.get_info());  # The Great Gatsby by F. Scott Fitzgerald - Available

            success = book.borrow();
            print(f"Borrowed: {success}");  # Borrowed: True
            print(book.get_info());  # The Great Gatsby by F. Scott Fitzgerald - Borrowed
        }
        ```

---

## Step 2: Introducing Spatial Relationships

The next step leverages Jac's Object-Spatial Programming by converting relationships into nodes and edges.

### From Collections to Graph Structures

!!! example "Spatial Relationship Migration"
    === "Python Relationships"
        ```python
        # library_python.py - List-based relationships
        class Library:
            def __init__(self, name: str):
                self.name = name
                self.books = []  # List of books
                self.members = []  # List of members
                self.borrowed_books = {}  # Dict mapping book_isbn -> member_id

            def add_book(self, book):
                self.books.append(book)

            def add_member(self, member):
                self.members.append(member)

            def find_available_books(self):
                return [book for book in self.books if not book.is_borrowed]

            def find_member_books(self, member_id: str):
                member_isbns = [isbn for isbn, mid in self.borrowed_books.items() if mid == member_id]
                return [book for book in self.books if book.isbn in member_isbns]
        ```

    === "Jac Spatial Relationships"
        ```jac
        # library_spatial.jac - Graph-based relationships
        node Book {
            has title: str;
            has author: str;
            has isbn: str;
        }

        node Member {
            has name: str;
            has member_id: str;
        }

        edge Contains;  # Library contains books/members
        edge BorrowedBy {
            has borrowed_date: str;
        }

        node Library {
            has name: str;

            def add_book(book: Book) -> None {
                self +:Contains:+> book;
            }

            def add_member(member: Member) -> None {
                self +:Contains:+> member;
            }

            def find_available_books() -> list[Book] {
                all_books = [self --Contains--> Book];
                borrowed_books = [self --Contains--> Book --BorrowedBy--> Member];
                # Return books not in borrowed list
                return [book for book in all_books if book not in borrowed_books];
            }

            def find_member_books(member_id: str) -> list[Book] {
                target_member = [self --Contains--> Member](?member_id == member_id);
                if target_member {
                    return [target_member[0] <--BorrowedBy-- Book];
                }
                return [];
            }
        }
        ```
---

## Incremental Adoption Patterns

Real-world migration often requires running Python and Jac code together. Let's explore hybrid approaches.

### Python-Jac Integration

!!! example "Hybrid Integration Approach"
    === "Python Wrapper"
        ```python
        # hybrid_library.py - Python wrapper for Jac code
        import subprocess
        import json

        class JacLibraryWrapper:
            def __init__(self, library_name: str):
                self.library_name = library_name
                # Initialize Jac library through subprocess or API

            def call_jac_walker(self, walker_name: str, params: dict):
                """Call Jac walker from Python"""
                # In practice, this would use jac-cloud API or subprocess
                cmd = f"jac run library.jac --walker {walker_name} --ctx '{json.dumps(params)}'"
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                return json.loads(result.stdout) if result.stdout else None

            def add_book_via_jac(self, title: str, author: str, isbn: str):
                """Add book using Jac walker"""
                params = {"title": title, "author": author, "isbn": isbn}
                return self.call_jac_walker("add_book", params)

            def get_available_books(self):
                """Get available books using Jac walker"""
                return self.call_jac_walker("get_available_books", {})

        # Traditional Python usage
        class PythonBook:
            def __init__(self, title: str, author: str):
                self.title = title
                self.author = author

        # Hybrid usage
        if __name__ == "__main__":
            # Use existing Python classes
            python_book = PythonBook("Old Book", "Old Author")

            # Use new Jac functionality
            jac_library = JacLibraryWrapper("My Library")
            jac_library.add_book_via_jac("New Book", "New Author", "123456")
        ```

    === "Jac Side"
        ```jac
        # library.jac - Jac implementation
        node Book {
            has title: str;
            has author: str;
            has isbn: str;
        }

        node Library {
            has name: str;
        }

        walker add_book {
            has title: str;
            has author: str;
            has isbn: str;

            can add_book_to_library with `root entry {
                # Find or create library
                libraries = [-->](`?Library);
                if not libraries {
                    library = Library(name="Default Library");
                    here ++> library;
                } else {
                    library = libraries[0];
                }

                # Create and add book
                new_book = Book(title=self.title, author=self.author, isbn=self.isbn);
                library ++> new_book;

                report {"message": f"Added book: {self.title}", "isbn": self.isbn};
            }
        }

        walker get_available_books {
            can fetch_available_books with `root entry {
                all_books = [-->](`?Book);
                books_data = [
                    {"title": book.title, "author": book.author, "isbn": book.isbn}
                    for book in all_books
                ];
                report {"books": books_data, "count": len(books_data)};
            }
        }
        ```

---

## Common Migration Pitfalls

Understanding common pitfalls helps ensure smooth migration from Python to Jac.

### Pitfall 1: Direct Syntax Translation

!!! warning "Avoid Direct Translation"
    Don't directly translate Python syntax without considering Jac's spatial capabilities.

!!! example "Poor vs Good Migration"
    === "Poor Migration (Direct Translation)"
        ```jac
        # poor_migration.jac - Direct syntax translation
        obj LibraryManager {
            has books: list[dict] = [];  # Still thinking in lists
            has members: list[dict] = [];

            def add_book(book_data: dict) -> None {
                self.books.append(book_data);  # Missing spatial benefits
            }

            def find_book(isbn: str) -> dict | None {
                for book in self.books {  # Manual iteration
                    if book["isbn"] == isbn {
                        return book;
                    }
                }
                return None;
            }
        }
        ```

    === "Good Migration (Spatial Thinking)"
        ```jac
        # good_migration.jac - Embracing spatial programming
        node Book {
            has title: str;
            has author: str;
            has isbn: str;
        }

        node Library {
            has name: str;

            def add_book(title: str, author: str, isbn: str) -> Book {
                new_book = Book(title=title, author=author, isbn=isbn);
                self ++> new_book;  # Spatial relationship
                return new_book;
            }

            def find_book(isbn: str) -> Book | None {
                # Spatial filtering - much cleaner
                found_books = [self --> Book](?isbn == isbn);
                return found_books[0] if found_books else None;
            }
        }
        ```
        </div>

### Pitfall 2: Ignoring Type Safety

!!! example "Type Safety Migration"
    === "Weak Typing (Python Style)"
        ```jac
        # weak_typing.jac - Avoiding Jac's type benefits
        walker process_data {
            has data: dict;  # Too generic

            can process with `root entry {
                # Uncertain about data structure
                if "title" in self.data {
                    title = self.data["title"];
                } else {
                    title = "Unknown";
                }
                report {"processed": title};
            }
        }
        ```

    === "Strong Typing (Jac Style)"
        ```jac
        # strong_typing.jac - Leveraging Jac's type system
        obj BookData {
            has title: str;
            has author: str;
            has isbn: str;
        }

        walker process_book_data {
            has book_data: BookData;  # Clear, type-safe structure

            can process with `root entry {
                # Type safety guarantees
                new_book = Book(
                    title=self.book_data.title,
                    author=self.book_data.author,
                    isbn=self.book_data.isbn
                );
                here ++> new_book;
                report {"processed": self.book_data.title};
            }
        }
        ```
        </div>

---

## Migration Checklist

!!! tip "Successful Migration Steps"
    1. **Start Small**: Begin with utility functions and simple classes
    2. **Embrace Types**: Use Jac's type system for better code quality
    3. **Think Spatially**: Convert relationships to nodes and edges
    4. **Test Incrementally**: Validate each migration step
    5. **Leverage Python**: Keep using Python libraries where beneficial
    6. **Document Changes**: Track migration decisions and patterns

### Final Migration Example

!!! example "Complete Library Migration"
    === "Before (Python)"
        ```python
        # Original complex Python code
        library = Library("City Library")

        book1 = Book("1984", "George Orwell", "111")
        book2 = Book("Brave New World", "Aldous Huxley", "222")
        member = Member("Alice", "M001")

        library.add_book(book1)
        library.add_book(book2)
        library.add_member(member)

        # Manual relationship management
        success = library.borrow_book("111", "M001")
        available = library.find_available_books()
        ```

    === "After (Jac)"
        ```jac
        # Modern Jac implementation
        with entry {
            library = Library(name="City Library");

            book1 = Book(title="1984", author="George Orwell", isbn="111");
            book2 = Book(title="Brave New World", author="Aldous Huxley", isbn="222");
            member = Member(name="Alice", member_id="M001");

            library.add_book(book1);
            library.add_book(book2);
            library.add_member(member);

            # Spatial relationship management
            success = library.borrow_book("111", "M001");
            available = library.find_available_books();

            print(f"Borrowed: {success}, Available: {len(available)}");
        }
        ```
        </div>

---

## Best Practices

!!! summary "Migration Best Practices"
    - **Start small**: Begin with isolated components rather than entire applications
    - **Maintain compatibility**: Keep existing Python code running during migration
    - **Test thoroughly**: Validate each migration step with comprehensive tests
    - **Document changes**: Track migration decisions and patterns for team consistency
    - **Train the team**: Ensure all developers understand Object-Spatial Programming concepts
    - **Plan rollback**: Have strategies for reverting changes if issues arise

## Key Takeaways

!!! summary "What We've Learned"
    **Migration Strategies:**

    - **Incremental approach**: Gradual migration reduces risk and allows learning
    - **Syntax translation**: Converting Python classes to Jac objects with automatic constructors
    - **Spatial transformation**: Moving from collections to graph-based relationships
    - **Hybrid integration**: Running Python and Jac code together during transition

    **Technical Benefits:**

    - **Automatic constructors**: Eliminate boilerplate code with `has` declarations
    - **Type safety**: Mandatory typing catches errors earlier in development
    - **Graph relationships**: Natural representation of connected data
    - **Performance gains**: Optimized execution for both local and distributed environments

    **Common Challenges:**

    - **Paradigm shift**: Moving from object-oriented to spatial thinking
    - **Team adoption**: Training developers on new concepts and patterns
    - **Integration complexity**: Managing hybrid Python-Jac applications
    - **Testing changes**: Ensuring equivalent behavior after migration

    **Success Factors:**

    - **Clear planning**: Structured approach to migration with defined milestones
    - **Comprehensive testing**: Validation at every step of the migration process
    - **Team alignment**: Consistent understanding of goals and benefits
    - **Iterative improvement**: Continuous refinement of migration patterns

!!! tip "Try It Yourself"
    Practice migration by:
    - Converting a simple Python class to a Jac object
    - Transforming list-based relationships into graph structures
    - Creating hybrid applications that use both Python libraries and Jac features
    - Building comprehensive test suites to validate migration correctness

    Remember: Successful migration is about embracing spatial thinking, not just syntax conversion!

---
