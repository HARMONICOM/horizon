# Template Engine

The Horizon framework provides template functionality using [ZTS (Zig Templates made Simple)](https://github.com/zigster64/zts).

## Overview

ZTS is a simple and efficient template engine aligned with Zig's philosophy.

### Features

- **Simple**: Zig-like section definition syntax
- **Maintainable**: Template logic controlled with Zig code
- **Efficient**: All processing at comptime
- **Type Safe**: Detects mismatches at compile time

## Section Definition

Templates use `.section_name` to separate sections.

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

## Basic Usage

### 1. Embed Template File

```zig
const template = @embedFile("templates/page.html");
```

### 2. Render Header Section

Renders the header section (content before the first `.section_name`).

```zig
fn handler(context: *horizon.Context) !void {
    try context.response.renderHeader(template, .{});
}
```

### 3. Render Specific Section

```zig
fn handler(context: *horizon.Context) !void {
    try context.response.render(template, "content", .{});
}
```

### 4. Concatenate Multiple Sections

```zig
fn handler(context: *horizon.Context) !void {
    var renderer = try context.response.renderMultiple(template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("header");
    _ = try renderer.writeRaw("content");
    _ = try renderer.writeRaw("footer");
}
```

## Inserting Dynamic Content

### Method 1: Manually Build HTML

```zig
fn handleUserList(context: *horizon.Context) !void {
    const users = [_]User{
        .{ .id = 1, .name = "Alice" },
        .{ .id = 2, .name = "Bob" },
    };

    var renderer = try context.response.renderMultiple(user_list_template);
    _ = try renderer.writeHeader(.{});

    // Dynamically generate each user row
    for (users) |user| {
        const row = try std.fmt.allocPrint(context.allocator,
            \\<tr>
            \\    <td>{d}</td>
            \\    <td>{s}</td>
            \\</tr>
            \\
        , .{ user.id, user.name });
        defer context.allocator.free(row);
        try context.response.body.appendSlice(context.allocator, row);
    }

    try context.response.body.appendSlice(context.allocator, "</tbody></table></body></html>");
}
```

### Method 2: Conditional Sections

```zig
fn handler(context: *horizon.Context) !void {
    const is_logged_in = context.request.getQuery("logged_in") != null;

    var renderer = try context.response.renderMultiple(template);
    _ = try renderer.writeHeader(.{});

    if (is_logged_in) {
        _ = try renderer.writeRaw("logged_in_content");
    } else {
        _ = try renderer.writeRaw("guest_content");
    }

    _ = try renderer.writeRaw("footer");
}
```

## API Reference

### Response.renderHeader()

Renders the header section of a template.

```zig
pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void
```

**Parameters:**
- `template_content`: Template string (comptime)
- `args`: Format arguments (currently unused)

### Response.render()

Renders a specific section.

```zig
pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void
```

**Parameters:**
- `template_content`: Template string (comptime)
- `section`: Section name (comptime)
- `args`: Format arguments (currently unused)

### Response.renderMultiple()

Returns a renderer for concatenating multiple sections.

```zig
pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content)
```

**Parameters:**
- `template_content`: Template string (comptime)

**Returns:**
- `TemplateRenderer`: Template renderer

### TemplateRenderer.writeHeader()

Writes header section.

```zig
pub fn writeHeader(self: *Self, args: anytype) !*Self
```

### TemplateRenderer.write()

Writes specified section with formatting (currently, formatting functionality is unused).

```zig
pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self
```

### TemplateRenderer.writeRaw()

Writes specified section as is.

```zig
pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self
```

## Direct ZTS Function Usage

You can also use ZTS functions directly through `horizon.zts`.

### zts.s() - Get Section Content

```zig
const content = horizon.zts.s(template, "section_name");
const header = horizon.zts.s(template, null); // Header section
```

### zts.print() - Output Section

```zig
try horizon.zts.print(template, "section_name", .{}, writer);
```

### zts.printHeader() - Output Header

```zig
try horizon.zts.printHeader(template, .{}, writer);
```

## Best Practices

### 1. Template File Placement

It is recommended to place template files in a `templates/` directory.

```
project/
├── templates/
│   ├── base.html
│   ├── welcome.html
│   └── user_list.html
├── src/
└── example/
```

### 2. Section Name Conventions

- Use lowercase and underscores
- Use meaningful names
- Examples: `user_card`, `navigation_bar`, `footer_content`

### 3. Dynamic Content Handling

- Simple value insertion: Use `std.fmt.allocPrint()`
- Complex logic: Control with Zig code
- Repeated processing: Generate dynamically with loops

### 4. Error Handling

All rendering functions return `!void`, so handle errors appropriately.

```zig
fn handler(context: *horizon.Context) !void {
    try context.response.renderHeader(template, .{}) catch |err| {
        std.debug.print("Template error: {}\n", .{err});
        context.response.setStatus(.internal_server_error);
        try context.response.text("Internal Server Error");
        return;
    };
}
```

## Examples

For complete examples, see the `example/06-template/` directory.

```bash
# Build example
make exec app "zig build"

# Run example
make exec app "./zig-out/bin/06-template"
```

## Limitations

- Template content must be a comptime value
- Section names must be comptime values
- Format argument functionality is currently limited

## References

- [ZTS GitHub Repository](https://github.com/zigster64/zts)
- [ZTS Documentation](https://github.com/zigster64/zts/blob/main/README.md)
