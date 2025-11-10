# Horizon Sample Applications

This directory contains sample applications using the Horizon framework.

**Note:** All server usage examples (01-04) display the registered route list on startup. This feature is enabled by setting `srv.show_routes_on_startup = true`.

## Sample List

### 01. Hello World (`01-hello-world/`)

The most basic sample showing how to generate HTML, text, and JSON responses.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/01-hello-world
```

**Endpoints:**
- `GET /` - HTML homepage
- `GET /text` - Plain text response
- `GET /api/json` - JSON response

### 02. RESTful API (`02-restful-api/`)

Example implementation of a RESTful API. Implements a user management API.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/02-restful-api
```

**Endpoints:**
- `GET /api/health` - Health check
- `GET /api/users` - Get user list
- `POST /api/users` - Create new user
- `GET /api/users/:id` - Get user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

**Usage Examples:**
```bash
# Get user list
curl http://localhost:5000/api/users

# Create user
curl -X POST http://localhost:5000/api/users

# Get user
curl http://localhost:5000/api/users/1
```

### 03. Middleware (`03-middleware/`)

Example usage of the middleware system. Implements logging, authentication, and CORS middleware.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/03-middleware
```

**Endpoints:**
- `GET /` - Homepage
- `GET /api/public` - Public endpoint (no authentication required)
- `GET /api/protected` - Protected endpoint (authentication required)

**Usage Examples:**
```bash
# Public endpoint (no authentication required)
curl http://localhost:5000/api/public

# Protected endpoint (authentication required)
curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
```

**Implemented Middlewares:**
- **Logging Middleware**: Log all requests
- **CORS Middleware**: Set CORS headers
- **Authentication Middleware**: Validate Authorization header

### 04. Session (`04-session/`)

Example of session management usage. Implements login, logout, and session information retrieval using memory backend.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/04-session
```

**Endpoints:**
- `GET /` - Homepage (with interactive demo)
- `POST /api/login` - Create session (login)
- `POST /api/logout` - Delete session (logout)
- `GET /api/session` - Get session information
- `GET /api/protected` - Protected endpoint (login required)

**Usage Examples:**
```bash
# Login (create session)
curl -X POST http://localhost:5000/api/login -c cookies.txt

# Get session information
curl http://localhost:5000/api/session -b cookies.txt

# Access protected endpoint
curl http://localhost:5000/api/protected -b cookies.txt

# Logout (delete session)
curl -X POST http://localhost:5000/api/logout -b cookies.txt
```

**Browser Usage:**
Access the homepage (`http://localhost:5000/`) for an interactive demo.

### 04-session-redis. Session with Redis (`04-session-redis/`)

Example of session management using Redis backend. Sessions are persisted to Redis and retained after server restart.

**Prerequisites:**
- Redis server must be running at `127.0.0.1:6379`

**Redis Setup (using Docker):**
```bash
# Start Redis container
docker run -d --name redis -p 6379:6379 redis:latest

# Verify Redis connection
docker exec -it redis redis-cli ping
# Should return PONG
```

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/04-session-redis
```

**Endpoints:**
- `GET /` - Homepage (with interactive demo)
- `POST /api/login` - Create session (saved to Redis)
- `POST /api/logout` - Delete session (deleted from Redis)
- `GET /api/session` - Get session information (retrieved from Redis)
- `GET /api/protected` - Protected endpoint (login required)

**Redis Backend Features:**
- Sessions are persisted to Redis
- Sessions are retained after server restart
- Session sharing possible in distributed environments
- Automatic TTL (expiration) management

**Checking Sessions in Redis:**
```bash
# Display list of session keys
docker exec -it redis redis-cli KEYS "horizon:session:*"

# Check specific session
docker exec -it redis redis-cli GET "horizon:session:YOUR_SESSION_ID"

# Check session TTL
docker exec -it redis redis-cli TTL "horizon:session:YOUR_SESSION_ID"
```

### 05. Path Parameters (`05-path-parameters/`)

Example usage of path parameters and regex pattern matching. Extracts URL parameters with various patterns.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/05-path-parameters
```

**Main Features:**
- **Basic Path Parameters**: Dynamic paths like `/users/:id`
- **Regex Patterns**: Restrict parameter values (e.g., `[0-9]+`, `[a-zA-Z]+`)
- **Multiple Parameters**: Define multiple parameters in one path
- **Mixed Paths**: Combination of fixed and dynamic segments

**Implemented Routes:**
```
// Basic path parameter
GET /users/:id

// ID with numbers only (regex pattern)
GET /users/:id([0-9]+)

// Profile page (fixed segment + parameter)
GET /users/:id([0-9]+)/profile

// Category name with alphabets only
GET /category/:name([a-zA-Z]+)

// Multiple parameters
GET /users/:userId([0-9]+)/posts/:postId([0-9]+)

// Product code with alphanumeric only
GET /products/:code([a-zA-Z0-9]+)

// No pattern (any string)
GET /search/:query
```

**Regex Support:**

Horizon uses PCRE2 (Perl Compatible Regular Expressions 2) to provide full regex functionality.

Common pattern examples:
- `[0-9]+` - One or more digits
- `[a-z]+` - One or more lowercase letters
- `[A-Z]+` - One or more uppercase letters
- `[a-zA-Z]+` - One or more letters
- `[a-zA-Z0-9]+` - One or more alphanumeric characters
- `\d{2,4}` - 2-4 digits
- `[a-z]{3,}` - 3 or more lowercase letters
- `(true|false)` - "true" or "false"
- `.*` - Any string (0 or more characters)

Full PCRE2 syntax is supported, allowing use of more complex patterns.

**Getting Path Parameters:**
```zig
fn getUserHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) !void {
    if (req.getParam("id")) |id| {
        // Process using id
    }
}
```

### 06. Template (`06-template/`)

Example of HTML template processing using the ZTS template engine.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/06-template
```

**Endpoints:**
- `GET /` - Welcome page (template rendering)
- `GET /users` - User list (dynamic table generation)
- `GET /hello/:name` - Dynamic greeting page

**Main Features:**
- **Template Embedding**: Load templates at compile time with `@embedFile()`
- **Section-Based Rendering**: Manage templates divided into sections
- **Dynamic Content Insertion**: Generate HTML dynamically with loops and conditionals
- **Integration with Path Parameters**: Dynamic pages using URL parameters

**Usage Examples:**
```bash
# Welcome page
curl http://localhost:5000/

# User list
curl http://localhost:5000/users

# Custom greeting
curl http://localhost:5000/hello/Taro
```

**How to Use Templates:**

```zig
// Embed template file
const template = @embedFile("templates/page.html");

// Render header section
try res.renderHeader(template, .{});

// Concatenate multiple sections
var renderer = try res.renderMultiple(template);
_ = try renderer.writeHeader(.{});
_ = try renderer.writeRaw("content");
_ = try renderer.writeRaw("footer");
```

For detailed usage, see [`../docs/specs/07-template.md`](../docs/specs/07-template.md).

### 07. Static Files (`07-static-files/`)

Example usage of middleware that serves static files (HTML, CSS, JavaScript, images, etc.).

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/07-static-files
```

**Endpoints:**
- `GET /static/` - Static file index page (index.html)
- `GET /static/styles.css` - CSS file
- `GET /static/script.js` - JavaScript file
- `GET /api/hello` - API endpoint (JSON)
- `GET /api/status` - Status endpoint

**Main Features:**
- **Automatic MIME Type Detection**: Set appropriate Content-Type from file extension
- **Cache Control**: Set Cache-Control header to enable browser caching
- **Directory Traversal Protection**: Secure path processing
- **Index Files**: Automatically serve index.html when accessing directories
- **Flexible Configuration**: Customize URL prefix, root directory, etc.

**Supported File Formats:**
- **Text**: HTML, CSS, JavaScript, JSON, XML, TXT
- **Images**: PNG, JPG, GIF, SVG, ICO, WebP
- **Fonts**: WOFF, WOFF2, TTF, OTF
- **Others**: PDF, ZIP, TAR, GZIP

**Configuration Example:**
```zig
const static_middleware = horizon.StaticMiddleware.initWithConfig(.{
    .root_dir = "public",              // Root directory for static files
    .url_prefix = "/static",           // URL prefix
    .enable_cache = true,              // Enable caching
    .cache_max_age = 3600,            // Cache max age in seconds
    .index_file = "index.html",        // Index file name
});

// Register with router (recommended to register first)
try router.middlewares.use(&static_middleware);
```

**Usage Examples:**
```bash
# Access static page
curl http://localhost:8080/static/

# Get CSS file
curl http://localhost:8080/static/styles.css

# Get JavaScript file
curl http://localhost:8080/static/script.js

# API endpoint
curl http://localhost:8080/api/hello
```

**Browser Usage:**
Access `http://localhost:8080/static/` in your browser to see a beautifully styled demo page.

### 08. Error Handling (`08-error-handling/`)

Example using error handling middleware to return unified error responses (JSON format).

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/08-error-handling
```

**Endpoints:**
- `GET /` - Homepage
- `GET /users/:id([0-9]+)` - Get user information
- `GET /error` - Trigger error (500 error)
- `GET /notfound` - Non-existent path (404 error)

**Main Features:**
- **Unified Error Responses**: Return all errors in a consistent format
- **404 Error Handling**: Handle route not found
- **500 Error Handling**: Handle server errors
- **Custom Error Messages**: Customizable error messages

**Usage Examples:**
```bash
# Success response
curl http://localhost:5000/

# Get user information
curl http://localhost:5000/users/1

# 500 error
curl http://localhost:5000/error

# 404 error
curl http://localhost:5000/notfound
```

**Error Response Example (JSON):**
```json
{
  "error": {
    "code": 404,
    "message": "Requested resource not found"
  }
}
```

### 09. Error Handling (HTML) (`09-error-handling-html/`)

Example displaying error pages in HTML format. Suitable for browser viewing.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/09-error-handling-html
```

**Endpoints:**
- `GET /` - Homepage (error page demo)
- `GET /error` - 500 error page
- `GET /notfound` - 404 error page

**Main Features:**
- **Beautiful Error Pages**: Styled HTML error pages
- **Browser Support**: Optimized for browser viewing
- **Japanese Messages**: Display custom error messages in Japanese

**Browser Usage:**
Access the following URLs in your browser to see error pages:
- `http://localhost:5000/` - Demo page
- `http://localhost:5000/error` - 500 error page
- `http://localhost:5000/notfound` - 404 error page

### 10. Custom Error Handler (`10-custom-error-handler/`)

Example using a custom error handler to completely customize error responses.

**How to Run:**
```bash
make zig build examples
make exec app zig-out/bin/10-custom-error-handler
```

**Endpoints:**
- `GET /` - Homepage
- `GET /api/data` - Data retrieval API
- `GET /error` - Trigger error
- `GET /notfound` - Non-existent path

**Main Features:**
- **Complete Customization**: Freely design error responses
- **Additional Information**: Include timestamp, request information, etc.
- **Support Information**: Display support information when errors occur

**Custom Error Response Example:**
```json
{
  "error": {
    "code": 404,
    "message": "Requested resource not found",
    "timestamp": 1704067200,
    "request": {
      "method": "GET",
      "path": "/notfound"
    },
    "support": "Contact support@example.com for assistance"
  }
}
```

**Usage Examples:**
```bash
# Success response
curl http://localhost:5000/

# Get data
curl http://localhost:5000/api/data

# Custom error response (500 error)
curl http://localhost:5000/error

# Custom error response (404 error)
curl http://localhost:5000/notfound
```


## Build and Run

```bash
make zig build
```

Built executables are generated in the `zig-out/bin/` directory.


## Notes

1. **Port Number**: Samples 01-05 start by default at `http://0.0.0.0:5000`, sample 06 at `http://0.0.0.0:5000`
2. **Data Persistence**: Sample applications store data in memory, so data is lost when the server restarts
3. **Authentication**: Authentication used in samples is simplified and should not be used in production environments

## Next Steps

Use these samples as reference to develop your own Horizon applications. For detailed API specifications, see [`../docs/specs/`](../docs/specs/).
