const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Request = horizon.Request;
const Response = horizon.Response;
const SessionStore = horizon.SessionStore;
const Errors = horizon.Errors;

// グローバルセッションストア
var session_store: SessionStore = undefined;

/// CookieからセッションIDを抽出（簡易版）
fn extractSessionId(req: *Request) ?[]const u8 {
    if (req.getHeader("Cookie")) |cookie| {
        // 簡易的なCookie解析（実際のアプリケーションでは適切なパーサーを使用）
        if (std.mem.indexOf(u8, cookie, "session_id=")) |start| {
            const value_start = start + 11; // "session_id=".len
            if (std.mem.indexOfPos(u8, cookie, value_start, ";")) |end| {
                return cookie[value_start..end];
            } else {
                return cookie[value_start..];
            }
        }
    }
    return null;
}

/// ログインハンドラー
fn loginHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = req;

    // セッションを作成
    const session = try session_store.create();
    try session.set("user_id", "123");
    try session.set("username", "alice");
    try session.set("logged_in", "true");

    // セッションIDをCookieに設定
    const cookie = try std.fmt.allocPrint(allocator, "session_id={s}; Path=/; HttpOnly; Max-Age=3600", .{session.id});
    defer allocator.free(cookie);
    try res.setHeader("Set-Cookie", cookie);

    try res.json("{\"status\":\"ok\",\"message\":\"Logged in successfully\"}");
}

/// ログアウトハンドラー
fn logoutHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    if (extractSessionId(req)) |session_id| {
        _ = session_store.remove(session_id);
    }

    // Cookieを削除
    try res.setHeader("Set-Cookie", "session_id=; Path=/; HttpOnly; Max-Age=0");

    try res.json("{\"status\":\"ok\",\"message\":\"Logged out successfully\"}");
}

/// セッション情報を取得
fn sessionInfoHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    if (extractSessionId(req)) |session_id| {
        if (session_store.get(session_id)) |session| {
            const user_id = session.get("user_id") orelse "unknown";
            const username = session.get("username") orelse "unknown";

            const json = try std.fmt.allocPrint(allocator, "{{\"session_id\":\"{s}\",\"user_id\":\"{s}\",\"username\":\"{s}\",\"valid\":true}}", .{ session_id, user_id, username });
            defer allocator.free(json);
            try res.json(json);
            return;
        }
    }

    res.setStatus(.unauthorized);
    try res.json("{\"error\":\"No valid session\"}");
}

/// 保護されたエンドポイント
fn protectedHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    if (extractSessionId(req)) |session_id| {
        if (session_store.get(session_id)) |session| {
            if (session.get("logged_in")) |logged_in| {
                if (std.mem.eql(u8, logged_in, "true")) {
                    const username = session.get("username") orelse "unknown";
                    const json = try std.fmt.allocPrint(allocator, "{{\"message\":\"Welcome {s}!\",\"protected\":true}}", .{username});
                    defer allocator.free(json);
                    try res.json(json);
                    return;
                }
            }
        }
    }

    res.setStatus(.unauthorized);
    try res.json("{\"error\":\"Authentication required\"}");
}

/// ホームページ
fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Session Example</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }
        \\        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        \\        code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
        \\        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Horizon Session Example</h1>
        \\    <p>This example demonstrates session management in Horizon.</p>
        \\    <div class="endpoint">
        \\        <h3>Endpoints</h3>
        \\        <p><code>POST /api/login</code> - Create a session</p>
        \\        <p><code>POST /api/logout</code> - Destroy a session</p>
        \\        <p><code>GET /api/session</code> - Get session information</p>
        \\        <p><code>GET /api/protected</code> - Protected endpoint (requires login)</p>
        \\    </div>
        \\    <div>
        \\        <button onclick="login()">Login</button>
        \\        <button onclick="logout()">Logout</button>
        \\        <button onclick="getSession()">Get Session Info</button>
        \\        <button onclick="accessProtected()">Access Protected</button>
        \\    </div>
        \\    <div id="result" style="margin-top: 20px;"></div>
        \\    <script>
        \\        async function login() {
        \\            const res = await fetch('/api/login', { method: 'POST' });
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function logout() {
        \\            const res = await fetch('/api/logout', { method: 'POST' });
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function getSession() {
        \\            const res = await fetch('/api/session');
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function accessProtected() {
        \\            const res = await fetch('/api/protected');
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\    </script>
        \\</body>
        \\</html>
    ;
    try res.html(html);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // セッションストアを初期化
    session_store = SessionStore.init(allocator);
    defer session_store.deinit();

    // サーバーアドレスを設定
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // サーバーを初期化
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // ルートを登録
    try srv.router.get("/", homeHandler);
    try srv.router.post("/api/login", loginHandler);
    try srv.router.post("/api/logout", logoutHandler);
    try srv.router.get("/api/session", sessionInfoHandler);
    try srv.router.get("/api/protected", protectedHandler);

    // 起動時にルート一覧を表示するオプションを有効化
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon Session example running on http://0.0.0.0:5000\n", .{});

    // サーバーを起動
    try srv.listen();
}
