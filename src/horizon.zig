// Core modules
pub const Errors = @import("horizon/utils/errors.zig");
pub const Middleware = @import("horizon/middleware.zig");
pub const Request = @import("horizon/request.zig").Request;
pub const Response = @import("horizon/response.zig").Response;

// Server, Router, and Context
pub const Server = @import("horizon/server.zig").Server;
pub const Router = @import("horizon/router.zig").Router;
pub const RouteHandler = @import("horizon/router.zig").RouteHandler;
pub const RouteGroup = @import("horizon/router.zig").RouteGroup;
pub const Context = @import("horizon/context.zig").Context;

// Utilities
pub const pcre2 = @import("horizon/libs/pcre2.zig");
pub const RedisClient = @import("horizon/utils/redisClient.zig").RedisClient;
pub const zts = @import("zts");

// Middlewares
pub const LoggingMiddleware = @import("horizon/middlewares/loggingMiddleware.zig").LoggingMiddleware;
pub const LogLevel = @import("horizon/middlewares/loggingMiddleware.zig").LogLevel;
pub const CorsMiddleware = @import("horizon/middlewares/corsMiddleware.zig").CorsMiddleware;
pub const BearerAuthMiddleware = @import("horizon/middlewares/httpAuthMiddleware.zig").BearerAuthMiddleware;
pub const BasicAuthMiddleware = @import("horizon/middlewares/httpAuthMiddleware.zig").BasicAuthMiddleware;
pub const StaticMiddleware = @import("horizon/middlewares/staticMiddleware.zig").StaticMiddleware;
pub const ErrorMiddleware = @import("horizon/middlewares/errorMiddleware.zig").ErrorMiddleware;
pub const ErrorFormat = @import("horizon/middlewares/errorMiddleware.zig").ErrorFormat;

// Session functionality (optional)
const SessionMW = @import("horizon/middlewares/sessionMiddleware.zig");
pub const SessionMiddleware = SessionMW.SessionMiddleware;
pub const Session = SessionMW.Session;
pub const SessionStore = SessionMW.SessionStore;
pub const SessionStoreBackend = SessionMW.SessionStoreBackend;
pub const MemoryBackend = SessionMW.MemoryBackend;
pub const RedisBackend = SessionMW.RedisBackend;
