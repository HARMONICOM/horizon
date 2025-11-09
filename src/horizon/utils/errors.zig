const std = @import("std");

/// Horizonフレームワークのエラー型
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
