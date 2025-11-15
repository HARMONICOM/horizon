## Getting Started with Horizon

This guide walks you through:

1. Setting up the environment
2. Creating a minimal Horizon server
3. Understanding a typical project structure

It assumes basic familiarity with Zig.

---

## 1. Install Zig and Dependencies

- **Zig version**: Horizon targets **Zig 0.15.2** or later.
- **PCRE2** (`libpcre2-8`): Required for regex‑based routing.

If you use the provided Docker environment, all dependencies are preconfigured.

---

## 2. Creating a Minimal Server

Below is a simplified version of a typical Horizon application:

```zig
const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Welcome to Horizon!</h1>");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Register routes
    try srv.router.get("/", homeHandler);

    // Optional: show route list on startup
    // srv.show_routes_on_startup = true;

    // Start server (blocking)
    try srv.listen();
}
```

Compile and run:

```bash
zig build
./zig-out/bin/horizon_test   # or your own target
```

Then open `http://localhost:5000/` in your browser.

---

## 3. Project Structure (Typical)

When using Horizon as a framework, a common layout is:

```text
src/
  main.zig       # Entry point
  root.zig       # Helper/import hub (optional)
  routes/        # Route modules
  views/         # Templates (ZTS)
```

Routes are usually organized in separate files (see `horizon_sample/src/routes`).

---

## 4. Next Steps

- **Routing basics**: See [`routing.md`](./routing.md)
- **Working with requests/responses**: See [`request-response.md`](./request-response.md)
- **Middleware and logging/auth**: See [`middleware.md`](./middleware.md)


