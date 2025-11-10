# Horizon Framework Overview Specification

## 1. Overview

Horizon is a web framework developed in the Zig language, providing a simple and extensible API.

### 1.1 Design Philosophy

- **Simplicity**: Intuitive and easy-to-understand API
- **Performance**: High-speed processing leveraging Zig's characteristics
- **Extensibility**: Flexible extension through middleware system
- **Type Safety**: Safety ensured by Zig's type system

### 1.2 Main Features

1. **HTTP Server**: High-performance HTTP server implementation
2. **Routing**: RESTful routing system
   - Path parameter support (e.g., `/users/:id`)
   - PCRE2-based regex pattern matching (e.g., `/users/:id([0-9]+)`)
3. **Request/Response**: Easy manipulation of requests and responses
4. **Content Type Support**:
   - JSON, HTML, text responses
   - Template engine with ZTS (Zig Template Strings)
5. **Middleware**:
   - Custom middleware chain support
   - Built-in middlewares (authentication, CORS, logging)
6. **Session Management**: Secure session management feature

## 2. Architecture

### 2.1 Overall Structure

```
┌─────────────────┐
│   HTTP Client   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Server (HTTP)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Router      │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌──────────────┐
│Request │ │  Middleware   │
│Handler │ │    Chain      │
└───┬────┘ └──────┬────────┘
    │             │
    └─────┬───────┘
          │
          ▼
    ┌──────────┐
    │ Response │
    └──────────┘
```

### 2.2 Module Structure

#### Core Modules
- **server.zig**: HTTP server implementation
- **router.zig**: Routing system (path parameters, regex support)
- **request.zig**: HTTP request processing
- **response.zig**: HTTP response generation (JSON, HTML, template support)
- **middleware.zig**: Middleware system
- **session.zig**: Session management

#### Built-in Middlewares (middlewares/)
- **authMiddleware.zig**: Authentication middleware
- **corsMiddleware.zig**: CORS support middleware
- **loggingMiddleware.zig**: Logging middleware

#### Utilities (utils/)
- **errors.zig**: Error definitions
- **pcre2.zig**: Zig bindings for PCRE2 library (regex processing)

### 2.3 Data Flow

1. HTTP request arrives at server
2. Server converts request to `Request` object
3. Router finds route based on request method and path
4. Global or route-specific middleware is executed for the found route
5. Route handler executes and generates `Response` object
6. Response is sent to client

## 3. Technical Requirements

### 3.1 Language & Version

- Zig 0.15.2 or later

### 3.2 Dependencies

- **Zig Standard Library**: Core functionality
- **ZTS (Zig Template Strings)**: Template engine functionality
- **PCRE2 (libpcre2-8)**: Regular expression processing library
  - Used for path parameter regex matching
  - Requires external installation as system library
  - Automatically linked within Horizon module

### 3.3 Platforms

- Linux
- macOS
- Windows (Docker environment recommended)

## 4. Performance Characteristics

- **Low Latency**: High-speed processing through compile-time optimization in Zig
- **Memory Efficiency**: Efficient resource usage through explicit memory management
- **Scalability**: Asynchronous processing prepared (future extension)

## 5. Security Considerations

- Session IDs use cryptographically secure random number generator
- Memory safety is developer's responsibility (Zig characteristic)
- Input validation needs to be implemented at application level

## 6. Future Extensions Planned

- File-based routing
- Database integration (ORM, query builder)
- Advanced authentication/authorization middleware (JWT, OAuth2, etc.)
- WebSocket support
- Static file serving
- Multipart/form data parsing
- Asynchronous processing optimization
