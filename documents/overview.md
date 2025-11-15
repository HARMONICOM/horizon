## Horizon Overview

Horizon is a web framework written in Zig.
It focuses on **simplicity**, **performance**, and **extensibility** while
leveraging Zig’s type‑safety.

---

## 1. Design Philosophy

- **Simplicity**: Intuitive APIs and clear control flow
- **Performance**: Efficient use of Zig’s low‑level control and optimizations
- **Extensibility**: Flexible middleware system and modular design
- **Type Safety**: Strong compile‑time guarantees via Zig’s type system

---

## 2. Main Features

1. **HTTP Server**
   - Lightweight HTTP server built on Zig’s standard library
2. **Routing**
   - Method‑based routing (GET/POST/PUT/DELETE, etc.)
   - Path parameters (e.g. `/users/:id`)
   - Regex‑constrained parameters using PCRE2 (e.g. `/users/:id([0-9]+)`)
   - Route groups with `mount` / `mountWithMiddleware`
3. **Request & Response**
   - Easy access to headers, query params, and path params
   - Helpers for JSON, HTML, and text responses
4. **Templates**
   - Integration with ZTS (Zig Templates made Simple)
   - Section‑based HTML templates
5. **Middleware**
   - Global and route‑specific middleware chains
   - Built‑in middlewares for logging, CORS, authentication, errors, and static files
6. **Session Management**
   - Cookie‑based session middleware
   - In‑memory and Redis backends

---

## 3. Architecture

High‑level data flow:

```text
HTTP Client
    ↓
Server (HTTP)
    ↓
Router
    ↓
Middleware Chain → Request Handler
    ↓
Response
```

Core modules:

- `Server`: HTTP server implementation
- `Router`: Route registration and dispatch
- `Request` / `Response`: HTTP abstractions
- `Middleware`: Middleware chain and context
- `Session` / `SessionStore`: Session management
- `Template` helpers: ZTS integration

---

## 4. Technical Requirements

- **Language**: Zig **0.15.2** or later
- **Dependencies**:
  - Zig standard library
  - **ZTS (Zig Template Strings)** for templates
  - **PCRE2 (libpcre2-8)** for regex in routing

When using Horizon as a module:

- PCRE2 linking is configured in `build.zig` (you only need the library installed).
- The Docker environment in this repository already includes the required dependencies.

Supported platforms (depending on your Zig toolchain and environment):

- Linux
- macOS
- Windows (Docker environment recommended)

---

## 5. Performance & Security (High Level)

### Performance

- Low‑latency processing via Zig’s compile‑time optimization
- Efficient memory usage with explicit allocators
- Simple, predictable control flow

### Security

- Session IDs generated using cryptographically secure random bytes
- Input validation and sanitization are handled at the application level
- Recommended to run behind HTTPS and to use secure cookies in production

---

## 6. Where to Go Next

- **Set up and run a server**: See [`getting-started.md`](./getting-started.md)
- **Define routes and APIs**: See [`routing.md`](./routing.md)
- **Work with requests/responses**: See [`request-response.md`](./request-response.md)
- **Configure middleware and static files**: See [`middleware.md`](./middleware.md)
- **Add login sessions**: See [`sessions.md`](./sessions.md)
- **Render HTML templates**: See [`templates.md`](./templates.md)


