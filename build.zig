const std = @import("std");

/// zigprebuild — 跨平台 C 库预编译静态库
///
/// 将 BoringSSL / nghttp2 / ngtcp2 / nghttp3 / libyaml 从官方 release 源码
/// 通过 cmake + zig cc（或 Zig 原生编译）交叉编译为多平台产物。
/// 重量库输出到 zig-out/<target>/lib/ 和 zig-out/<target>/include/；
/// 轻量库（libyaml）通过 addModule("yaml_c") 暴露 Zig 模块。
///
/// 依赖链：boringssl → ngtcp2（QUIC 加密后端）
///         nghttp2、nghttp3、libyaml 无依赖，可独立构建
///
/// 消费者项目只需通过 b.dependency("zigprebuild", ...) 引用
/// 并链接 zig-out/<target>/lib/*.a 即可，无需运行 cmake。
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ---- 平台映射 ----
    const cmake_system = switch (target.result.os.tag) {
        .macos => "Darwin",
        .linux => "Linux",
        .windows => "Windows",
        .freebsd => "FreeBSD",
        else => @panic("unsupported target OS"),
    };

    const cmake_processor = switch (target.result.cpu.arch) {
        .aarch64 => if (target.result.os.tag == .windows) "ARM64" else "aarch64",
        .x86_64 => if (target.result.os.tag == .windows) "AMD64" else "x86_64",
        else => @panic("unsupported CPU arch"),
    };

    const zig_target = b.fmt("{s}-{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
        switch (target.result.os.tag) {
            .linux => "musl",
            .windows => "gnu",
            else => "none",
        },
    });

    const cc_env = b.fmt("zig cc -target {s}", .{zig_target});

    // ---- 共享：zig-ar / zig-ranlib wrapper 脚本 ----
    // cmake 要求 AR/RANLIB 是单可执行文件，不能用带空格的子命令
    const setup_wrappers = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\ZIG="$(which zig 2>/dev/null || echo zig)"
            \\mkdir -p build/wrappers
            \\printf '#!/bin/sh\nexec %s ar "$@"\n' "$ZIG" > build/wrappers/zig-ar
            \\printf '#!/bin/sh\nexec %s ranlib "$@"\n' "$ZIG" > build/wrappers/zig-ranlib
            \\chmod +x build/wrappers/zig-ar build/wrappers/zig-ranlib
        , .{}),
    });

    // ---- 共享：子模块初始化 ----
    // nghttp3 需要 lib/sfparse（Structured Field Values 解析器）
    const init_sfparse = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\cd nghttp3
            \\if [ ! -f lib/sfparse/sfparse.c ]; then
            \\  echo "Initializing nghttp3 submodule: lib/sfparse"
            \\  git submodule update --init --depth 1 lib/sfparse
            \\fi
        , .{}),
    });

    const build_root = b.build_root.path orelse ".";
    const zig_ar = b.fmt("{s}/build/wrappers/zig-ar", .{build_root});
    const zig_ranlib = b.fmt("{s}/build/wrappers/zig-ranlib", .{build_root});

    // ---- 输出目录 ----
    const out_dir = b.fmt("zig-out/{s}", .{zig_target});

    // ================================================================
    // 1. BoringSSL
    // ================================================================
    const bs_src = "boringssl";
    const bs_build_dir = b.fmt("build/{s}/boringssl", .{zig_target});

    const bs_configure = b.addSystemCommand(&.{
        "cmake",
        "-B", bs_build_dir,
        "-GNinja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        b.fmt("-DCMAKE_SYSTEM_NAME={s}", .{cmake_system}),
        b.fmt("-DCMAKE_SYSTEM_PROCESSOR={s}", .{cmake_processor}),
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
        "-DOPENSSL_NO_ASM=ON",
        b.fmt("-DCMAKE_AR={s}", .{zig_ar}),
        b.fmt("-DCMAKE_RANLIB={s}", .{zig_ranlib}),
        "-S", bs_src,
    });
    bs_configure.step.dependOn(&setup_wrappers.step);
    bs_configure.setEnvironmentVariable("CC", cc_env);
    // 不设 CXX — BoringSSL 只有 C 和 ASM 源文件（C++ 功能可选，我们不使用）
    bs_configure.setEnvironmentVariable("GOWORK", "off");

    const bs_build = b.addSystemCommand(&.{
        "cmake", "--build", bs_build_dir, "--target", "ssl", "crypto", "--config", "Release",
    });
    bs_build.step.dependOn(&bs_configure.step);
    bs_build.setEnvironmentVariable("GOWORK", "off");

    const bs_copy = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\mkdir -p "{0s}/lib" "{0s}/include"
            \\# 新版 boringssl .a 文件在 build 根目录下
            \\cp {1s}/libssl.a "{0s}/lib/"
            \\cp {1s}/libcrypto.a "{0s}/lib/"
            \\cp -R {2s}/include/openssl "{0s}/include/"
            \\echo "Built BoringSSL: {0s}/"
        , .{ out_dir, bs_build_dir, bs_src }),
    });
    bs_copy.step.dependOn(&bs_build.step);

    // ================================================================
    // 2. nghttp2（HTTP/2 帧层，无加密依赖）
    // ================================================================
    const h2_src = "nghttp2";
    const h2_build_dir = b.fmt("build/{s}/nghttp2", .{zig_target});

    const h2_configure = b.addSystemCommand(&.{
        "cmake",
        "-B", h2_build_dir,
        "-GNinja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        b.fmt("-DCMAKE_SYSTEM_NAME={s}", .{cmake_system}),
        b.fmt("-DCMAKE_SYSTEM_PROCESSOR={s}", .{cmake_processor}),
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
        b.fmt("-DCMAKE_AR={s}", .{zig_ar}),
        b.fmt("-DCMAKE_RANLIB={s}", .{zig_ranlib}),
        "-DBUILD_STATIC_LIBS=ON",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DENABLE_LIB_ONLY=ON",
        "-DBUILD_TESTING=OFF",
        "-DENABLE_HTTP3=OFF",
        "-S", h2_src,
    });
    h2_configure.step.dependOn(&setup_wrappers.step);
    h2_configure.setEnvironmentVariable("CC", cc_env);
    h2_configure.setEnvironmentVariable("GOWORK", "off");

    const h2_build = b.addSystemCommand(&.{
        "cmake", "--build", h2_build_dir, "--config", "Release",
    });
    h2_build.step.dependOn(&h2_configure.step);
    h2_build.setEnvironmentVariable("GOWORK", "off");

    const h2_copy = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\mkdir -p "{0s}/lib" "{0s}/include/nghttp2"
            \\cp {1s}/lib/libnghttp2.a "{0s}/lib/"
            \\# 生成的头文件（nghttp2ver.h）优先于源码中的 .h.in 模板
            \\cp {1s}/lib/includes/nghttp2/nghttp2ver.h "{0s}/include/nghttp2/" 2>/dev/null || true
            \\cp {1s}/lib/includes/nghttp2/*.h "{0s}/include/nghttp2/" 2>/dev/null || true
            \\cp {2s}/lib/includes/nghttp2/*.h "{0s}/include/nghttp2/" 2>/dev/null || true
            \\echo "Built nghttp2: {0s}/"
        , .{ out_dir, h2_build_dir, h2_src }),
    });
    h2_copy.step.dependOn(&h2_build.step);

    // ================================================================
    // 3. ngtcp2（QUIC 传输层，BoringSSL 加密后端）
    // ================================================================
    const quic_src = "ngtcp2";
    const quic_build_dir = b.fmt("build/{s}/ngtcp2", .{zig_target});
    const bs_out_abs = b.fmt("{s}/{s}", .{ build_root, out_dir });

    const quic_configure = b.addSystemCommand(&.{
        "cmake",
        "-B", quic_build_dir,
        "-GNinja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        b.fmt("-DCMAKE_SYSTEM_NAME={s}", .{cmake_system}),
        b.fmt("-DCMAKE_SYSTEM_PROCESSOR={s}", .{cmake_processor}),
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
        b.fmt("-DCMAKE_AR={s}", .{zig_ar}),
        b.fmt("-DCMAKE_RANLIB={s}", .{zig_ranlib}),
        "-DENABLE_STATIC_LIB=ON",
        "-DENABLE_SHARED_LIB=OFF",
        "-DENABLE_LIB_ONLY=ON",
        "-DBUILD_TESTING=OFF",
        "-DENABLE_OPENSSL=OFF",
        "-DENABLE_BORINGSSL=ON",
        b.fmt("-DBORINGSSL_INCLUDE_DIR={s}/include", .{bs_out_abs}),
        b.fmt("-DBORINGSSL_LIBRARIES={s}/lib/libssl.a;{s}/lib/libcrypto.a", .{ bs_out_abs, bs_out_abs }),
        // check_symbol_exists("OPENSSL_IS_BORINGSSL") 对空宏失效，直接告知 cmake
        "-DHAVE_BORINGSSL=1",
        "-S", quic_src,
    });
    quic_configure.step.dependOn(&bs_copy.step); // 需要 BoringSSL 先构建
    quic_configure.setEnvironmentVariable("CC", cc_env);
    quic_configure.setEnvironmentVariable("GOWORK", "off");

    const quic_build = b.addSystemCommand(&.{
        "cmake", "--build", quic_build_dir, "--config", "Release",
    });
    quic_build.step.dependOn(&quic_configure.step);
    quic_build.setEnvironmentVariable("GOWORK", "off");

    const quic_copy = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\mkdir -p "{0s}/lib" "{0s}/include/ngtcp2"
            \\cp {1s}/lib/libngtcp2.a "{0s}/lib/"
            \\cp {1s}/crypto/boringssl/libngtcp2_crypto_boringssl.a "{0s}/lib/"
            \\# 生成的头文件（version.h）优先于源码中的 .h.in 模板
            \\cp {1s}/lib/includes/ngtcp2/version.h "{0s}/include/ngtcp2/" 2>/dev/null || true
            \\cp {2s}/lib/includes/ngtcp2/*.h "{0s}/include/ngtcp2/" 2>/dev/null || true
            \\cp {2s}/crypto/includes/ngtcp2/*.h "{0s}/include/ngtcp2/" 2>/dev/null || true
            \\echo "Built ngtcp2: {0s}/"
        , .{ out_dir, quic_build_dir, quic_src }),
    });
    quic_copy.step.dependOn(&quic_build.step);

    // ================================================================
    // 4. nghttp3（HTTP/3 帧层，无加密依赖）
    // ================================================================
    const h3_src = "nghttp3";
    const h3_build_dir = b.fmt("build/{s}/nghttp3", .{zig_target});

    const h3_configure = b.addSystemCommand(&.{
        "cmake",
        "-B", h3_build_dir,
        "-GNinja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        b.fmt("-DCMAKE_SYSTEM_NAME={s}", .{cmake_system}),
        b.fmt("-DCMAKE_SYSTEM_PROCESSOR={s}", .{cmake_processor}),
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON",
        b.fmt("-DCMAKE_AR={s}", .{zig_ar}),
        b.fmt("-DCMAKE_RANLIB={s}", .{zig_ranlib}),
        "-DENABLE_STATIC_LIB=ON",
        "-DENABLE_SHARED_LIB=OFF",
        "-DENABLE_LIB_ONLY=ON",
        "-DBUILD_TESTING=OFF",
        "-S", h3_src,
    });
    h3_configure.step.dependOn(&setup_wrappers.step);
    h3_configure.step.dependOn(&init_sfparse.step); // 需要 sfparse 子模块
    h3_configure.setEnvironmentVariable("CC", cc_env);
    h3_configure.setEnvironmentVariable("GOWORK", "off");

    const h3_build = b.addSystemCommand(&.{
        "cmake", "--build", h3_build_dir, "--config", "Release",
    });
    h3_build.step.dependOn(&h3_configure.step);
    h3_build.setEnvironmentVariable("GOWORK", "off");

    const h3_copy = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\mkdir -p "{0s}/lib" "{0s}/include/nghttp3"
            \\cp {1s}/lib/libnghttp3.a "{0s}/lib/"
            \\# 生成的头文件（version.h）优先于源码中的 .h.in 模板
            \\cp {1s}/lib/includes/nghttp3/version.h "{0s}/include/nghttp3/" 2>/dev/null || true
            \\cp {2s}/lib/includes/nghttp3/*.h "{0s}/include/nghttp3/" 2>/dev/null || true
            \\echo "Built nghttp3: {0s}/"
        , .{ out_dir, h3_build_dir, h3_src }),
    });
    h3_copy.step.dependOn(&h3_build.step);

    // ================================================================
    // 5. libyaml（JSON 配置解析，Zig 原生编译，无 cmake 依赖）
    // ================================================================
    const yaml_c_mod = b.addModule("yaml_c", .{
        .root_source_file = b.path("yaml_c.zig"),
        .target = target,
        .optimize = optimize,
    });

    // translate-c: yaml.h → Zig 类型绑定（native target，类型定义跨平台通用）
    const yaml_h = b.addTranslateC(.{
        .root_source_file = b.path("libyaml/include/yaml.h"),
        .target = b.resolveTargetQuery(.{}),
        .optimize = optimize,
    });
    yaml_h.addIncludePath(b.path("libyaml/include"));
    yaml_c_mod.addImport("yaml_h_internal", yaml_h.createModule());

    // 编译 libyaml C 源码
    yaml_c_mod.addCSourceFiles(.{
        .root = b.path("libyaml/src"),
        .files = &.{
            "api.c",    "dumper.c", "emitter.c", "loader.c",
            "parser.c", "reader.c", "scanner.c", "writer.c",
        },
        .flags = &.{
            "-O3",
            "-std=gnu11",
            "-DYAML_VERSION_MAJOR=0",
            "-DYAML_VERSION_MINOR=2",
            "-DYAML_VERSION_PATCH=5",
            "-DYAML_VERSION_STRING=\"0.2.5\"",
        },
    });
    yaml_c_mod.addIncludePath(b.path("libyaml/src"));
    yaml_c_mod.addIncludePath(b.path("libyaml/include"));

    // 交叉编译时添加 sysroot include path
    if (b.sysroot) |s| {
        const sysroot_include = b.pathJoin(&.{ s, "usr", "include" });
        yaml_c_mod.addSystemIncludePath(.{ .cwd_relative = sysroot_include });
        const common_android_archs = [_][]const u8{
            "aarch64-linux-android",
            "arm-linux-androideabi",
            "x86_64-linux-android",
            "i686-linux-android",
        };
        for (common_android_archs) |triple| {
            const arch_inc = b.pathJoin(&.{ s, "usr", "include", triple });
            yaml_c_mod.addSystemIncludePath(.{ .cwd_relative = arch_inc });
        }
    }

    // ---- 默认构建目标：全部 5 个库 ----
    b.default_step.dependOn(&bs_copy.step);
    b.default_step.dependOn(&h2_copy.step);
    b.default_step.dependOn(&quic_copy.step);
    b.default_step.dependOn(&h3_copy.step);
}
