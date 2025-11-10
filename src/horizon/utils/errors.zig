const std = @import("std");

/// Horizon framework error type
pub const Horizon = error{
    InvalidRequest,
    InvalidResponse,
    RouteNotFound,
    MiddlewareError,
    SessionError,
    JsonParseError,
    JsonSerializeError,
    ServerError,
    ConnectionError,
    OutOfMemory,
};
