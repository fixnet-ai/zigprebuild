//! 重新导出 NNG (nanomsg-next-gen) C API 绑定，供消费方（zf.ipc 等）使用。
//!
//! translate-c 生成的 nng.h 绑定通过 nng_h_internal 导入，
//! 本文件按需显式重新导出符号，保持 API 稳定（照 yaml_c.zig 形状，不整包暴露）。
//!
//! 注意：
//! - req/rep/pair 协议 open 函数位于 protocol/ 子头文件（nng.h 不含），此处
//!   手写 extern 声明；`nng_req_open`/`nng_rep_open` 是头文件里的宏别名
//!   （→ nng_req0_open/nng_rep0_open），非真实符号，本模块以别名形式提供。
//! - `NNG_OPT_REQ_RESENDTIME` 同样在 req.h 中，按计划以 `NNG_OPT_RESENDTIME`
//!   别名导出。
//! - 静态库由消费方链接 zig-out/<target>/lib/libnng.a。

const nng_h = @import("nng_h_internal");

// ---- 类型 ----
pub const nng_socket = nng_h.nng_socket;
pub const nng_listener = nng_h.nng_listener;
pub const nng_dialer = nng_h.nng_dialer;
pub const nng_pipe = nng_h.nng_pipe;
pub const nng_msg = nng_h.nng_msg;
pub const nng_ctx = nng_h.nng_ctx;
pub const nng_aio = nng_h.nng_aio;
pub const nng_duration = nng_h.nng_duration;
pub const nng_sockaddr = nng_h.nng_sockaddr;
// nng_pipe_notify 的回调签名所需（头文件中与 notify 同组声明）
pub const nng_pipe_ev = nng_h.nng_pipe_ev;
pub const nng_pipe_cb = nng_h.nng_pipe_cb;

// ---- 错误码（nng_errno_enum 全集）----
pub const NNG_EINTR = nng_h.NNG_EINTR;
pub const NNG_ENOMEM = nng_h.NNG_ENOMEM;
pub const NNG_EINVAL = nng_h.NNG_EINVAL;
pub const NNG_EBUSY = nng_h.NNG_EBUSY;
pub const NNG_ETIMEDOUT = nng_h.NNG_ETIMEDOUT;
pub const NNG_ECONNREFUSED = nng_h.NNG_ECONNREFUSED;
pub const NNG_ECLOSED = nng_h.NNG_ECLOSED;
pub const NNG_EAGAIN = nng_h.NNG_EAGAIN;
pub const NNG_ENOTSUP = nng_h.NNG_ENOTSUP;
pub const NNG_EADDRINUSE = nng_h.NNG_EADDRINUSE;
pub const NNG_ESTATE = nng_h.NNG_ESTATE;
pub const NNG_ENOENT = nng_h.NNG_ENOENT;
pub const NNG_EPROTO = nng_h.NNG_EPROTO;
pub const NNG_EUNREACHABLE = nng_h.NNG_EUNREACHABLE;
pub const NNG_EADDRINVAL = nng_h.NNG_EADDRINVAL;
pub const NNG_EPERM = nng_h.NNG_EPERM;
pub const NNG_EMSGSIZE = nng_h.NNG_EMSGSIZE;
pub const NNG_ECONNABORTED = nng_h.NNG_ECONNABORTED;
pub const NNG_ECONNRESET = nng_h.NNG_ECONNRESET;
pub const NNG_ECANCELED = nng_h.NNG_ECANCELED;
pub const NNG_ENOFILES = nng_h.NNG_ENOFILES;
pub const NNG_ENOSPC = nng_h.NNG_ENOSPC;
pub const NNG_EEXIST = nng_h.NNG_EEXIST;
pub const NNG_EREADONLY = nng_h.NNG_EREADONLY;
pub const NNG_EWRITEONLY = nng_h.NNG_EWRITEONLY;
pub const NNG_ECRYPTO = nng_h.NNG_ECRYPTO;
pub const NNG_EPEERAUTH = nng_h.NNG_EPEERAUTH;
pub const NNG_ENOARG = nng_h.NNG_ENOARG;
pub const NNG_EAMBIGUOUS = nng_h.NNG_EAMBIGUOUS;
pub const NNG_EBADTYPE = nng_h.NNG_EBADTYPE;
pub const NNG_ECONNSHUT = nng_h.NNG_ECONNSHUT;
pub const NNG_EINTERNAL = nng_h.NNG_EINTERNAL;
pub const NNG_ESYSERR = nng_h.NNG_ESYSERR;
pub const NNG_ETRANERR = nng_h.NNG_ETRANERR;

// ---- 常量 ----
pub const NNG_FLAG_ALLOC = nng_h.NNG_FLAG_ALLOC;
pub const NNG_FLAG_NONBLOCK = nng_h.NNG_FLAG_NONBLOCK;

pub const NNG_OPT_PEER_PID = nng_h.NNG_OPT_PEER_PID;
pub const NNG_OPT_PEER_UID = nng_h.NNG_OPT_PEER_UID;
pub const NNG_OPT_PEER_GID = nng_h.NNG_OPT_PEER_GID;
pub const NNG_OPT_IPC_PERMISSIONS = nng_h.NNG_OPT_IPC_PERMISSIONS;
pub const NNG_OPT_RECVTIMEO = nng_h.NNG_OPT_RECVTIMEO;
pub const NNG_OPT_SENDTIMEO = nng_h.NNG_OPT_SENDTIMEO;
/// req.h 中真实名为 NNG_OPT_REQ_RESENDTIME（"req:resend-time"）
pub const NNG_OPT_RESENDTIME = "req:resend-time";

pub const NNG_PIPE_EV_ADD_PRE = nng_h.NNG_PIPE_EV_ADD_PRE;
pub const NNG_PIPE_EV_ADD_POST = nng_h.NNG_PIPE_EV_ADD_POST;
pub const NNG_PIPE_EV_REM_POST = nng_h.NNG_PIPE_EV_REM_POST;

// ---- 协议 open（protocol/ 子头文件，手写 extern；宏别名→真实符号）----
pub extern fn nng_req0_open(s: *nng_h.nng_socket) c_int;
pub extern fn nng_rep0_open(s: *nng_h.nng_socket) c_int;
pub extern fn nng_pair1_open(s: *nng_h.nng_socket) c_int;
pub extern fn nng_pair1_open_poly(s: *nng_h.nng_socket) c_int;
/// 头文件宏别名（#define nng_req_open nng_req0_open）的真实符号形式
pub const nng_req_open = nng_req0_open;
pub const nng_rep_open = nng_rep0_open;

// ---- 函数 ----
pub const nng_close = nng_h.nng_close;
pub const nng_listen = nng_h.nng_listen;
pub const nng_dial = nng_h.nng_dial;
pub const nng_listener_create = nng_h.nng_listener_create;
pub const nng_listener_start = nng_h.nng_listener_start;
pub const nng_socket_set_ms = nng_h.nng_socket_set_ms;
pub const nng_socket_set_size = nng_h.nng_socket_set_size;
pub const nng_listener_set_int = nng_h.nng_listener_set_int;
pub const nng_listener_set_string = nng_h.nng_listener_set_string;
pub const nng_recvmsg = nng_h.nng_recvmsg;
pub const nng_sendmsg = nng_h.nng_sendmsg;
pub const nng_msg_alloc = nng_h.nng_msg_alloc;
pub const nng_msg_free = nng_h.nng_msg_free;
pub const nng_msg_body = nng_h.nng_msg_body;
pub const nng_msg_len = nng_h.nng_msg_len;
pub const nng_msg_append = nng_h.nng_msg_append;
pub const nng_msg_get_pipe = nng_h.nng_msg_get_pipe;
pub const nng_pipe_id = nng_h.nng_pipe_id;
pub const nng_pipe_close = nng_h.nng_pipe_close;
pub const nng_pipe_notify = nng_h.nng_pipe_notify;
pub const nng_pipe_get_int = nng_h.nng_pipe_get_int;
pub const nng_pipe_get_uint64 = nng_h.nng_pipe_get_uint64;
pub const nng_ctx_open = nng_h.nng_ctx_open;
pub const nng_ctx_close = nng_h.nng_ctx_close;
pub const nng_ctx_sendmsg = nng_h.nng_ctx_sendmsg;
pub const nng_ctx_recvmsg = nng_h.nng_ctx_recvmsg;
pub const nng_strerror = nng_h.nng_strerror;
pub const nng_version = nng_h.nng_version;
