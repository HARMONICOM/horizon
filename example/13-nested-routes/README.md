# Nested Routes Example

This example demonstrates how to organize routes in separate files and nest them using route groups.

## File Structure

```
13-nested-routes/
├── main.zig              # Main server file
└── routes/
    ├── api.zig          # API routes (/api/*)
    ├── admin.zig        # Admin routes (/admin/*)
    └── blog.zig         # Blog routes (/blog/*)
```

## How It Works

### 1. Define Routes in Separate Files

Each route file exports a `registerRoutes` function that accepts a `RouteGroup`:

```zig
// routes/api.zig
pub fn registerRoutes(api_group: *horizon.RouteGroup) !void {
    try api_group.get("/users", usersListHandler);
    try api_group.post("/users", usersCreateHandler);
    try api_group.get("/posts", postsListHandler);
    try api_group.post("/posts", postsCreateHandler);
}
```

### 2. Import and Register in Main File

In `main.zig`, import the route modules and register them:

```zig
const api_routes = @import("routes/api.zig");
const admin_routes = @import("routes/admin.zig");
const blog_routes = @import("routes/blog.zig");

pub fn main() !void {
    // ... server initialization ...

    // API routes
    var api_group = try server.router.group("/api");
    try api_routes.registerRoutes(&api_group);

    // Admin routes
    var admin_group = try server.router.group("/admin");
    try admin_routes.registerRoutes(&admin_group);

    // Blog routes
    var blog_group = try server.router.group("/blog");
    try blog_routes.registerRoutes(&blog_group);

    try server.listen();
}
```

## Running the Example

```bash
# Build and run
make zig run example/13-nested-routes/main.zig

# Or build executable
make zig build
./zig-out/bin/13-nested-routes
```

## Available Routes

- `GET /` - Home page
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `GET /api/posts` - List posts
- `POST /api/posts` - Create post
- `GET /admin/dashboard` - Admin dashboard
- `GET /admin/users` - Manage users
- `GET /admin/settings` - Admin settings
- `GET /admin/reports` - Admin reports
- `GET /blog/` - Blog article list
- `GET /blog/:id` - Show blog article by ID
- `POST /blog/` - Create new blog article

## Benefits of This Approach

1. **Better Organization**: Routes are organized by feature/module
2. **Maintainability**: Easy to find and update specific routes
3. **Reusability**: Route modules can be reused across projects
4. **Scalability**: Easy to add new route modules as your app grows
5. **Team Collaboration**: Multiple developers can work on different route files

