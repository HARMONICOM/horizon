# Horizon Framework Specifications

This directory contains comprehensive specifications for the Horizon framework.

## Documentation List

### [00. Overview Specification](./00-overview.md)
- Framework overview
- Architecture
- Design philosophy
- Technical requirements

### [01. HTTP Server Specification](./01-server.md)
- Server struct API
- Request processing flow
- Error handling
- Performance considerations

### [02. Routing Specification](./02-router.md)
- Router struct API
- Route registration and lookup
- Route matching behavior
- Middleware application

### [03. Request/Response Specification](./03-request-response.md)
- Request struct API
- Response struct API
- Status codes
- Header and body manipulation

### [04. Middleware Specification](./04-middleware.md)
- Middleware system architecture
- MiddlewareChain API
- How to implement middleware
- Best practices

### [05. Session Management Specification](./05-session.md)
- Session struct API
- SessionStore API
- Session creation and management
- Security considerations

### [06. API Reference](./06-api-reference.md)
- Complete API reference
- List of all types and methods
- Usage examples

## How to Read the Documentation

1. **New Users**: Start with [00. Overview Specification](./00-overview.md)
2. **Learning Specific Features**: Refer to the corresponding specification
3. **API Details Needed**: See [06. API Reference](./06-api-reference.md)

## Documentation Updates

Specifications are updated in line with implementation changes. Each specification includes the following information:

- Detailed API descriptions
- Usage examples
- Limitations
- Future extensions planned

## Feedback

For questions or suggestions about the specifications, please report them on the project's Issue tracker.
