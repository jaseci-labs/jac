// Mock API functions - Promise creation must be in JS due to OneLang 'new' keyword limitation

// In-memory database (persists across fetches in the same session)
let usersDatabase = [
  {
    id: 1,
    name: "Alice Johnson",
    email: "alice@example.com",
    role: "Developer",
  },
  { id: 2, name: "Bob Smith", email: "bob@example.com", role: "Designer" },
  { id: 3, name: "Carol White", email: "carol@example.com", role: "Manager" },
  {
    id: 4,
    name: "David Brown",
    email: "david@example.com",
    role: "Developer",
  },
];

export async function fetchUsers() {
  // Simulate API delay
  await new Promise((resolve) => {
    setTimeout(resolve, 1000);
  });

  // Return copy of current database
  return [...usersDatabase];
}

export async function fetchUserById(userId) {
  await new Promise((resolve) => {
    setTimeout(resolve, 800);
  });

  const user = usersDatabase.find((u) => u.id === userId);

  if (!user) {
    throw new Error("User not found");
  }

  return { ...user };
}

export async function createUser(newUser) {
  await new Promise((resolve) => {
    setTimeout(resolve, 1000);
  });

  // Create user with unique ID
  const user = { ...newUser, id: Date.now() };

  // Add to database
  usersDatabase.push(user);

  console.log("✅ User created and added to database:", user);
  console.log("📊 Total users now:", usersDatabase.length);

  return user;
}

export async function deleteUser(userId) {
  await new Promise((resolve) => {
    setTimeout(resolve, 800);
  });

  const index = usersDatabase.findIndex((u) => u.id === userId);

  if (index === -1) {
    throw new Error("User not found");
  }

  // Remove from database
  const deletedUser = usersDatabase.splice(index, 1)[0];

  console.log("🗑️ User deleted from database:", deletedUser);
  console.log("📊 Total users now:", usersDatabase.length);

  return { success: true, deletedId: userId };
}
