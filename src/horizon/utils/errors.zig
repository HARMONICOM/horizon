const std = @import("std");

/// Horizon framework error type
pub const Horizon = error{
    InvalidRequest,
    InvalidResponse,
    InvalidPathPattern,
    RouteNotFound,
    MiddlewareError,
    SessionError,
    JsonParseError,
    JsonSerializeError,
    ServerError,
    ConnectionError,
    OutOfMemory,
    RegexCompileFailed,
    MatchDataCreateFailed,
    MatchFailed,
};
