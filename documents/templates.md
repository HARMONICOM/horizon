## Templates

This document explains how to use Horizon’s template support powered by
**ZTS (Zig Templates made Simple)**:

- Template sections and file structure
- Rendering a single section or multiple sections
- Mixing templates with dynamic Zig‑generated HTML

---

## 1. What Is ZTS?

ZTS is a simple, compile‑time template engine for Zig.
Horizon integrates ZTS through convenience methods on `Response`.

Key characteristics:

- Section‑based templates (header/content/footer, etc.)
- All parsing and processing at comptime
- Strong type‑safety

---

## 2. Template Files and Sections

Templates are usually stored under `views/` (as described in `getting-started.md`):

```text
project/
  src/
    views/
      base.html
      welcome.html
      user_list.html
```

A template is divided into sections using `.section_name` markers:

```html
<!DOCTYPE html>
<html>
<head><title>My Page</title></head>
<body>
.header
<header>
  <h1>Welcome</h1>
</header>
.content
<main>
  <p>Main content here</p>
</main>
.footer
<footer>
  <p>&copy; 2025</p>
</footer>
</body>
</html>
```

- The part before the first `.section` is called the **header section**.
- Each `.name` starts a named section (e.g. `header`, `content`, `footer`).

---

## 3. Embedding Templates

Use `@embedFile` to load the template as a comptime string:

```zig
// Assuming this code lives under `src/`:
const welcome_template = @embedFile("views/welcome.html");
const user_list_template = @embedFile("views/user_list.html");
```

---

## 4. Rendering with `Response`

### 4.1 Render Header Section

Renders everything before the first `.section`:

```zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

fn handleWelcome(context: *Context) Errors.Horizon!void {
    try context.response.renderHeader(welcome_template, .{"Welcome to the World of Zig!"});
}
```

The `args` parameter is currently not heavily used, but kept for future formatting support.

### 4.2 Render a Specific Section

```zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

fn handler(context: *Context) Errors.Horizon!void {
    try context.response.render(welcome_template, "content", .{});
}
```

This writes only the `content` section to the response body.

### 4.3 Concatenate Multiple Sections

Use `renderMultiple` when you want to build a response from several sections:

```zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

fn handler(context: *Context) Errors.Horizon!void {
    var renderer = try context.response.renderMultiple(welcome_template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.write("header", .{});
    _ = try renderer.write("content", .{});
    _ = try renderer.write("footer", .{});
}
```

The `TemplateRenderer` object appends sections to the response body in order.

---

## 5. Mixing Dynamic Content

Often you will combine templates with dynamic data built in Zig.

### 5.1 Example: User List

```zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

fn handleUserList(context: *Context) Errors.Horizon!void {
    const users = [_]User{
        .{ .id = 1, .name = "Taro Tanaka", .email = "tanaka@example.com" },
        .{ .id = 2, .name = "Hanako Sato", .email = "sato@example.com" },
        .{ .id = 3, .name = "Ichiro Suzuki", .email = "suzuki@example.com" },
    };

    var renderer = try context.response.renderMultiple(user_list_template);
    _ = try renderer.writeHeader(.{});

    // Generate HTML row for each user
    for (users) |user| {
        const row = try std.fmt.allocPrint(
            context.allocator,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td>{s}</td>
            \\                    <td>{s}</td>
            \\                </tr>
            \\
            ,
            .{ user.id, user.name, user.email },
        );
        defer context.allocator.free(row);
        try context.response.body.appendSlice(context.allocator, row);
    }

    // Close table/body
    try context.response.body.appendSlice(context.allocator,
        \\            </tbody>
        \\        </table>
        \\    </div>
        \\</body>
        \\</html>
    );
}
```

The template provides the “frame” (head, table header, etc.), and Zig fills in rows.

### 5.2 Conditional Sections

You can decide which sections to emit based on request data:

```zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

fn handler(context: *Context) Errors.Horizon!void {
    const is_logged_in = context.request.getQuery("logged_in") != null;

    var renderer = try context.response.renderMultiple(welcome_template);
    _ = try renderer.writeHeader(.{});

    if (is_logged_in) {
        _ = try renderer.writeRaw("logged_in_content");
    } else {
        _ = try renderer.writeRaw("guest_content");
    }

    _ = try renderer.writeRaw("footer");
}
```

---

## 6. Using ZTS Functions Directly

You can also call ZTS functions directly via `horizon.zts`:

```zig
const content = horizon.zts.s(template, "section_name");
const header = horizon.zts.s(template, null); // header section

try horizon.zts.print(template, "section_name", .{}, writer);
try horizon.zts.printHeader(template, .{}, writer);
```

This is useful if you want to render to a custom writer instead of HTTP response.

---

## 7. Tips and Limitations

- Template content and section names must be **comptime** values.
- For complex logic, keep it in Zig code and use templates mainly for layout.
- Handle errors from `render*` / `write*` methods like any other `!void` functions.


