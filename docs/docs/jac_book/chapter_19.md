# Chapter 19: Performance Optimization

!!! tip "Quick Reference"
    For a condensed performance optimization guide, see the [Advanced Topics - Performance Optimization](../advanced/index.md#performance-optimization) section.

In this chapter, we'll explore techniques for optimizing Jac applications to achieve better performance in both local and distributed environments. We'll build and progressively optimize a friend-finding algorithm that demonstrates graph structure optimization, traversal efficiency, and memory management strategies.

!!! info "What You'll Learn"
    - Graph structure optimization techniques
    - Efficient traversal patterns and algorithms
    - Memory management strategies in Jac
    - Performance monitoring and profiling
    - Distributed performance considerations

---

## Graph Structure Optimization

The foundation of Jac performance lies in how you structure your graph data. Efficient graph design can dramatically improve traversal performance and reduce memory usage.

!!! success "Optimization Benefits"
    - **Faster Traversals**: Well-structured graphs enable efficient pathfinding
    - **Reduced Memory**: Optimized node relationships minimize storage overhead
    - **Better Scaling**: Efficient structures handle larger datasets gracefully
    - **Improved Caching**: Predictable access patterns enhance cache performance

### Traditional vs Optimized Graph Design

!!! example "Graph Design Comparison"
    === "Traditional Approach"
        ```python
        # inefficient_friends.py - Nested loops and redundant data
        class Person:
            def **init**(self, name, age):
                self.name = name
                self.age = age
                self.friends = []  # Direct list storage
                self.friend_data = {}  # Redundant friend information

            def add_friend(self, friend):
                self.friends.append(friend)
                friend.friends.append(self)  # Bidirectional
                # Store redundant data
                self.friend_data[friend.name] = {
                    'age': friend.age,
                    'mutual_friends': []
                }

            def find_mutual_friends(self, other_person):
                mutual = []
                # Inefficient nested loop
                for my_friend in self.friends:
                    for their_friend in other_person.friends:
                        if my_friend.name == their_friend.name:
                            mutual.append(my_friend)
                return mutual

            def friends_of_friends(self, max_depth=2):
                found = set()
                # Inefficient recursive traversal
                def traverse(person, depth):
                    if depth <= 0:
                        return
                    for friend in person.friends:
                        if friend.name != self.name:
                            found.add(friend.name)
                            traverse(friend, depth - 1)

                traverse(self, max_depth)
                return list(found)
        ```

    === "Jac Optimized Structure"
        ```jac
        # optimized_friends.jac - Efficient graph-native design
        node Person {
            has name: str;
            has age: int;
            has friend_count: int = 0;  # Cached for quick access

            def add_friend(friend: Person) -> bool {
                # Check if already connected to avoid duplicates
                existing = [self --> Friend --> Person](?name == friend.name);
                if existing {
                    return false;
                }

                # Create bidirectional connection efficiently
                friendship = Friend(since="2024-01-15");
                self ++> friendship ++> friend;

                # Update cached counters
                self.friend_count += 1;
                friend.friend_count += 1;
                return true;
            }
        }

        edge Friend {
            has since: str;
            has strength: int = 1;  # Relationship strength for weighted algorithms
        }

        walker find_mutual_friends {
            has person1_name: str;
            has person2_name: str;

            can find_efficiently with `root entry {
                # Direct graph traversal - no nested loops
                person1 = [-->(`?Person)](?name == self.person1_name);
                person2 = [-->(`?Person)](?name == self.person2_name);

                if not person1 or not person2 {
                    report {"error": "Person not found"};
                    return;
                }

                # Get friends using graph navigation
                person1_friends = [person1[0] --> Friend --> Person];
                person2_friends = [person2[0] --> Friend --> Person];

                # Efficient set intersection
                mutual_names = {f.name for f in person1_friends} & {f.name for f in person2_friends};

                report {
                    "mutual_friends": list(mutual_names),
                    "count": len(mutual_names)
                };
            }
        }
        ```
---

## Traversal Efficiency

Efficient graph traversal is crucial for performance in Object-Spatial Programming. Let's examine different approaches to finding friends-of-friends and optimize them progressively.

### Basic Friend-Finding Algorithm

!!! example "Simple Friend Discovery"
    === "Jac"
        ```jac
        # basic_friend_finder.jac
        walker find_friends_of_friends {
            has person_name: str;
            has max_depth: int = 2;
            has visited: set[str] = set();
            has results: set[str] = set();

            can traverse_network with `root entry {
                start_person = [-->(`?Person)](?name == self.person_name);

                if not start_person {
                    report {"error": "Person not found"};
                    return;
                }

                # Start traversal from the person
                self.traverse_from_person(start_person[0], self.max_depth);

                # Remove the starting person from results
                self.results.discard(self.person_name);

                report {
                    "person": self.person_name,
                    "friends_of_friends": list(self.results),
                    "total_found": len(self.results)
                };
            }

            def traverse_from_person(person: Person, remaining_depth: int) {
                if remaining_depth <= 0 or person.name in self.visited {
                    return;
                }

                self.visited.add(person.name);
                self.results.add(person.name);

                # Navigate to friends and continue traversal
                friends = [person --> Friend --> Person];
                for friend in friends {
                    self.traverse_from_person(friend, remaining_depth - 1);
                }
            }
        }
        ```

    === "Python Equivalent"
        ```python
        # basic_friend_finder.py - Less efficient traversal
        def find_friends_of_friends(person_name, people_data, max_depth=2):
            visited = set()
            results = set()

            def traverse(current_name, depth):
                if depth <= 0 or current_name in visited:
                    return

                visited.add(current_name)
                results.add(current_name)

                # Manual lookup in data structure
                if current_name in people_data:
                    friends = people_data[current_name].get('friends', [])
                    for friend_name in friends:
                        traverse(friend_name, depth - 1)

            traverse(person_name, max_depth)
            results.discard(person_name)  # Remove starting person

            return {
                "person": person_name,
                "friends_of_friends": list(results),
                "total_found": len(results)
            }
        ```

### Optimized Breadth-First Traversal

!!! example "Performance-Optimized Friend Finding"
    ```jac
    # optimized_friend_finder.jac
    import from collections { deque }

    walker find_friends_optimized {
        has person_name: str;
        has max_depth: int = 2;

        can breadth_first_search with `root entry {
            start_person = [-->(`?Person)](?name == self.person_name);

            if not start_person {
                report {"error": "Person not found"};
                return;
            }

            # Use BFS for more predictable performance
            queue = deque([(start_person[0], 0)]);  # (person, depth)
            visited = {self.person_name};
            results = set();

            while queue {
                current_person, depth = queue.popleft();

                if depth >= self.max_depth {
                    continue;
                }

                # Get friends efficiently
                friends = [current_person --> Friend --> Person];

                for friend in friends {
                    if friend.name not in visited {
                        visited.add(friend.name);
                        results.add(friend.name);
                        queue.append((friend, depth + 1));
                    }
                }
            }

            report {
                "person": self.person_name,
                "friends_of_friends": list(results),
                "total_found": len(results),
                "algorithm": "breadth_first"
            };
        }
    }

    # Cached version for repeated queries
    walker find_friends_cached {
        has person_name: str;
        has max_depth: int = 2;

        can cached_search with `root entry {
            start_person = [-->(`?Person)](?name == self.person_name);

            if not start_person {
                report {"error": "Person not found"};
                return;
            }

            person = start_person[0];

            # Check if we have cached results
            cache_nodes = [person --> CacheEntry](?depth == self.max_depth);

            if cache_nodes {
                cache = cache_nodes[0];
                report {
                    "person": self.person_name,
                    "friends_of_friends": cache.friend_names,
                    "total_found": len(cache.friend_names),
                    "cached": true
                };
                return;
            }

            # Compute and cache results
            queue = deque([(person, 0)]);
            visited = {self.person_name};
            results = set();

            while queue {
                current_person, depth = queue.popleft();

                if depth >= self.max_depth {
                    continue;
                }

                friends = [current_person --> Friend --> Person];
                for friend in friends {
                    if friend.name not in visited {
                        visited.add(friend.name);
                        results.add(friend.name);
                        queue.append((friend, depth + 1));
                    }
                }
            }

            # Cache the results
            cache = CacheEntry(
                depth=self.max_depth,
                friend_names=list(results),
                computed_at="2024-01-15"
            );
            person ++> cache;

            report {
                "person": self.person_name,
                "friends_of_friends": list(results),
                "total_found": len(results),
                "cached": false
            };
        }
    }

    node CacheEntry {
        has depth: int;
        has friend_names: list[str];
        has computed_at: str;
    }
    ```

---

## Memory Management

Efficient memory usage is critical for large-scale graph applications. Let's explore techniques to minimize memory footprint while maintaining performance.

### Memory-Efficient Data Structures

!!! example "Optimized Memory Usage"
    ```jac
    # memory_optimized.jac
    # Use lightweight nodes for large-scale networks
    node LightPerson {
        has name: str;
        has age: int;
        # Remove unnecessary cached data to save memory

        def get_friend_count() -> int {
            # Calculate on-demand instead of caching
            return len([self --> (`?Friend) --> (`?LightPerson)]);
        }

        def get_connections_summary() -> dict {
            friends = [self --> (`?Friend) --> (`?LightPerson)];

            return {
                "friend_count": len(friends),
                "avg_age": sum(f.age for f in friends) / len(friends) if friends else 0,
                "friend_names": [f.name for f in friends[:5]]  # Limit for memory
            };
        }
    }

    # Memory-conscious walker with cleanup
    walker find_friends_memory_efficient {
        has person_name: str;
        has max_depth: int = 2;
        has batch_size: int = 100;  # Process in batches

        can memory_conscious_search with `root entry {
            start_person = [-->](`?LightPerson)(?name == self.person_name);

            if not start_person {
                report {"error": "Person not found"};
                return;
            }

            results = [];
            processed = 0;
            queue = deque([(start_person[0], 0)]);
            visited = {self.person_name};

            while queue and processed < self.batch_size {
                current_person, depth = queue.popleft();
                processed += 1;

                if depth >= self.max_depth {
                    continue;
                }

                # Get only essential friend data
                friends = [current_person --> Friend --> LightPerson];

                for friend in friends[:10] {  # Limit friends per iteration
                    if friend.name not in visited {
                        visited.add(friend.name);
                        results.append({
                            "name": friend.name,
                            "age": friend.age,
                            "depth": depth + 1
                        });

                        if depth + 1 < self.max_depth {
                            queue.append((friend, depth + 1));
                        }
                    }
                }

                # Periodic cleanup of references
                if processed % 50 == 0 {
                    # Force cleanup of temporary variables
                    friends = None;
                }
            }

            report {
                "person": self.person_name,
                "friends_found": results,
                "total_processed": processed,
                "memory_optimized": true
            };
        }
    }
    ```

### Performance Monitoring

!!! example "Performance Tracking Walker"
    ```jac
    # performance_monitor.jac
    import from time { time }
    import from psutil { Process }

    walker benchmark_friend_finding {
        has person_name: str;
        has algorithm: str = "optimized";  # "basic", "optimized", "cached"

        can run_benchmark with `root entry {
            start_time = time();
            process = Process();
            start_memory = process.memory_info().rss / 1024 / 1024;  # MB

            # Run the specified algorithm
            if self.algorithm == "basic" {
                result = find_friends_of_friends(person_name=self.person_name) spawn here;
            } elif self.algorithm == "optimized" {
                result = find_friends_optimized(person_name=self.person_name) spawn here;
            } elif self.algorithm == "cached" {
                result = find_friends_cached(person_name=self.person_name) spawn here;
            } else {
                report {"error": "Unknown algorithm"};
                return;
            }

            end_time = time();
            end_memory = process.memory_info().rss / 1024 / 1024;  # MB

            # Performance metrics
            execution_time = end_time - start_time;
            memory_used = end_memory - start_memory;

            report {
                "algorithm": self.algorithm,
                "execution_time_ms": round(execution_time * 1000, 2),
                "memory_used_mb": round(memory_used, 2),
                "friends_found": len(result[0].get("friends_of_friends", [])),
                "performance_ratio": round(len(result[0].get("friends_of_friends", [])) / execution_time, 2)
            };
        }
    }

    # Batch benchmarking for statistical analysis
    walker run_performance_suite {
        has test_count: int = 10;
        has test_persons: list[str] = ["Alice", "Bob", "Charlie"];

        can comprehensive_benchmark with `root entry {
            algorithms = ["basic", "optimized", "cached"];
            results = [];

            for algorithm in algorithms {
                algorithm_results = [];

                for person in self.test_persons {
                    for i in range(self.test_count) {
                        benchmark = benchmark_friend_finding(
                            person_name=person,
                            algorithm=algorithm
                        );
                        result = benchmark spawn here;
                        algorithm_results.append(result[0]);
                    }
                }

                # Calculate averages
                avg_time = sum(r["execution_time_ms"] for r in algorithm_results) / len(algorithm_results);
                avg_memory = sum(r["memory_used_mb"] for r in algorithm_results) / len(algorithm_results);
                avg_friends = sum(r["friends_found"] for r in algorithm_results) / len(algorithm_results);

                results.append({
                    "algorithm": algorithm,
                    "avg_execution_time_ms": round(avg_time, 2),
                    "avg_memory_used_mb": round(avg_memory, 2),
                    "avg_friends_found": round(avg_friends, 2),
                    "total_tests": len(algorithm_results)
                });
            }

            report {
                "benchmark_suite": results,
                "test_configuration": {
                    "test_count": self.test_count,
                    "test_persons": self.test_persons
                }
            };
        }
    }
    ```

---

## Distributed Performance

When deploying to Jac Cloud, consider performance implications of distributed execution and data locality.

### Cloud-Optimized Friend Finding

!!! example "Distributed Performance Patterns"
    ```jac
    # distributed_friends.jac
    walker find_friends_distributed {
        has person_name: str;
        has max_depth: int = 2;
        has partition_size: int = 50;  # Optimize for cloud chunks

        can cloud_optimized_search with `root entry {
            start_person = [-->](`?LightPerson)(?name == self.person_name);

            if not start_person {
                report {"error": "Person not found"};
                return;
            }

            # Partition the search for distributed processing
            person = start_person[0];
            immediate_friends = [person --> Friend --> LightPerson];

            # Process in chunks optimized for cloud deployment
            friend_chunks = [
                immediate_friends[i:i + self.partition_size]
                for i in range(0, len(immediate_friends), self.partition_size)
            ];

            all_results = [];
            chunk_count = 0;

            for chunk in friend_chunks {
                chunk_results = [];
                chunk_count += 1;

                for friend in chunk {
                    # Second-degree friends
                    if self.max_depth > 1 {
                        second_degree = [friend --> Friend --> LightPerson];
                        for second_friend in second_degree {
                            if second_friend.name != self.person_name {
                                chunk_results.append({
                                    "name": second_friend.name,
                                    "age": second_friend.age,
                                    "via": friend.name,
                                    "depth": 2
                                });
                            }
                        }
                    }

                    chunk_results.append({
                        "name": friend.name,
                        "age": friend.age,
                        "via": "direct",
                        "depth": 1
                    });
                }

                all_results.extend(chunk_results);
            }

            # Remove duplicates efficiently
            unique_results = {};
            for result in all_results {
                unique_results[result["name"]] = result;
            }

            report {
                "person": self.person_name,
                "friends_network": list(unique_results.values()),
                "total_found": len(unique_results),
                "chunks_processed": chunk_count,
                "distributed": true
            };
        }
    }

    # Health check for performance monitoring
    walker performance_health_check {
        can check_system_health with `root entry {
            # Count total nodes and relationships
            all_persons = [-->](`?LightPerson);
            total_friendships = [-->](`?Friend);

            # Calculate network density
            max_possible_connections = len(all_persons) * (len(all_persons) - 1) / 2;
            density = len(total_friendships) / max_possible_connections if max_possible_connections > 0 else 0;

            # Sample performance with a quick test
            start_time = time();
            if all_persons {
                sample_person = all_persons[0];
                sample_friends = [sample_person --> Friend --> LightPerson];
            }
            sample_time = time() - start_time;

            report {
                "total_persons": len(all_persons),
                "total_friendships": len(total_friendships),
                "network_density": round(density, 4),
                "sample_query_time_ms": round(sample_time * 1000, 2),
                "health_status": "good" if sample_time < 0.1 else "degraded"
            };
        }
    }
    ```

---

## Performance Testing and Deployment

### Creating Test Data

!!! example "Performance Test Setup"
    ```jac
    # test_data_generator.jac
    import from random { randint, choice }

    walker generate_test_network {
        has person_count: int = 100;
        has avg_friends: int = 5;

        can create_test_network with `root entry {
            # Clear existing test data
            existing_persons = [-->](`?LightPerson);
            existing_friends = [-->](`?Friend);

            for person in existing_persons {
                del person;
            }
            for friendship in existing_friends {
                del friendship;
            }

            # Create people
            people = [];
            for i in range(self.person_count) {
                person = LightPerson(
                    name=f"Person{i}",
                    age=randint(18, 65)
                );
                here ++> person;
                people.append(person);
            }

            # Create friendships
            total_friendships = 0;
            for person in people {
                friends_to_add = randint(1, self.avg_friends * 2);

                for _ in range(friends_to_add) {
                    potential_friend = choice(people);
                    if potential_friend != person {
                        # Check if friendship already exists
                        existing = [person --> Friend --> LightPerson](?name == potential_friend.name);
                        if not existing {
                            friendship = Friend(since="2024-01-15");
                            person ++> friendship ++> potential_friend;
                            total_friendships += 1;
                        }
                    }
                }
            }

            report {
                "people_created": len(people),
                "friendships_created": total_friendships,
                "avg_friends_per_person": round(total_friendships * 2 / len(people), 2)
            };
        }
    }
    ```

### Testing Performance

```bash
# Deploy the optimized version
jac start distributed_friends.jac

# Generate test data
curl -X POST http://localhost:8000/walker/generate_test_network \
  -H "Content-Type: application/json" \
  -d '{"person_count": 1000, "avg_friends": 10}'

# Run performance benchmarks
curl -X POST http://localhost:8000/walker/run_performance_suite \
  -H "Content-Type: application/json" \
  -d '{"test_count": 5, "test_persons": ["Person1", "Person50", "Person100"]}'

# Check system health
curl -X POST http://localhost:8000/walker/performance_health_check \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Best Practices

!!! summary "Performance Optimization Guidelines"
    - **Measure before optimizing**: Always profile before making performance changes
    - **Optimize hot paths**: Focus on frequently executed code sections
    - **Use appropriate data structures**: Choose the right graph patterns for your use case
    - **Cache intelligently**: Cache expensive computations but avoid memory leaks
    - **Batch operations**: Process multiple items together when possible
    - **Monitor continuously**: Track performance metrics in production

## Key Takeaways

!!! summary "What We've Learned"
    **Graph Structure Optimization:**

    - **Efficient relationships**: Well-designed edges and nodes improve traversal speed
    - **Index strategy**: Cache frequently accessed data for faster retrieval
    - **Memory management**: Batch processing and cleanup reduce memory footprint
    - **Connection patterns**: Optimize graph topology for common access patterns

    **Algorithm Optimization:**

    - **Traversal strategies**: Choose BFS vs DFS based on your specific requirements
    - **Caching patterns**: Strategic caching reduces redundant computations
    - **Batch processing**: Handle large datasets efficiently with chunking
    - **Early termination**: Stop processing when results are sufficient

    **Performance Monitoring:**

    - **Built-in metrics**: Track execution time, memory usage, and throughput
    - **Benchmarking**: Compare different implementation strategies objectively
    - **Real-world testing**: Test with production-scale data and load patterns
    - **Continuous profiling**: Monitor performance trends over time

    **Distributed Performance:**

    - **Cloud optimization**: Design for distributed execution and data locality
    - **Scaling patterns**: Horizontal scaling through partitioning and parallelization
    - **Resource efficiency**: Optimize for cloud computing cost and performance
    - **Load balancing**: Distribute work evenly across available resources

!!! tip "Try It Yourself"
    Apply performance optimization by:
    - Profiling your graph applications to identify bottlenecks
    - Implementing different caching strategies and measuring their impact
    - Testing with larger datasets to understand scaling characteristics
    - Optimizing walker traversal patterns for your specific use cases

    Remember: Performance optimization is an iterative process - measure, optimize, and verify!

---

*Ready to learn about migration strategies? Continue to [Chapter 21: Python to Jac Migration](chapter_20.md)!*
