#!/usr/bin/env bash
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# 20250610

find_toolchain_prefix() {
    local toolchain_bin_dir="$1"
    local possible_prefixes=()
    local real_target_name=""

    if [ ! -d "$toolchain_bin_dir" ]; then
        echo "Error: Folder '$toolchain_bin_dir' not existed." >&2
        return 1
    fi

    for compiler_path in "$toolchain_bin_dir"/*gcc; do
        if [ -x "$compiler_path" ] && [ -f "$compiler_path" ]; then
            real_target_name=$(basename "$(readlink -f "$compiler_path")")
            if [[ "$real_target_name" == *gcc ]]; then
                prefix="${real_target_name%gcc}"
                if [ -n "$prefix" ]; then
                    possible_prefixes+=("$prefix")
                fi
            fi
        fi
    done

    if [ ${#possible_prefixes[@]} -gt 0 ]; then
        local best_core_prefix=""
        local max_len=0
        for p in "${possible_prefixes[@]}"; do
            if (( ${#p} > max_len )); then
                max_len=${#p}
                best_core_prefix="$p"
            fi
        done
        echo "$best_core_prefix"
        return 0
    fi

    local fallback_prefixes=()

    for tool_path in "$toolchain_bin_dir"/*nm; do
        if [ -x "$tool_path" ] && [ -f "$tool_path" ]; then
            real_target_name=$(basename "$(readlink -f "$tool_path")")
            if [[ "$real_target_name" == *nm ]]; then
                prefix="${real_target_name%nm}"
                if [ -n "$prefix" ]; then
                    fallback_prefixes+=("$prefix")
                fi
            fi
        fi
    done

    for tool_path in "$toolchain_bin_dir"/*elfedit; do
        if [ -x "$tool_path" ] && [ -f "$tool_path" ]; then
            real_target_name=$(basename "$(readlink -f "$tool_path")")
            if [[ "$real_target_name" == *elfedit ]]; then
                prefix="${real_target_name%elfedit}"
                if [ -n "$prefix" ]; then
                    fallback_prefixes+=("$prefix")
                fi
            fi
        fi
    done

    if [ ${#fallback_prefixes[@]} -gt 0 ]; then
        local best_fallback_prefix=""
        local max_len=0
        for p in "${fallback_prefixes[@]}"; do
            if (( ${#p} > max_len )); then
                max_len=${#p}
                best_fallback_prefix="$p"
            fi
        done
        echo "$best_fallback_prefix"
        return 0
    fi

    echo "Warning: In '$toolchain_bin_dir' not found any recognizable toolchain executable (gcc/clang/nm/elfedit)." >&2
    return 1
}

if [ "$1" == "GCC_64" ]; then
    SET="$GITHUB_WORKSPACE/gcc-64/bin"
    REAL_PREFIX=$(find_toolchain_prefix "$SET")
    if [ -n "$REAL_PREFIX" ]; then
        echo "GCC_64=CROSS_COMPILE=$GITHUB_WORKSPACE/gcc-64/bin/$REAL_PREFIX" >> "$GITHUB_ENV"
        echo "Detected 64-bit GCC prefix: $REAL_PREFIX"
    else
        echo "Error: Could not determine 64-bit GCC prefix in $SET." >&2
        exit 1
    fi
elif [ "$1" == "GCC_32" ]; then
    SET="$GITHUB_WORKSPACE/gcc-32/bin"
    REAL_PREFIX=$(find_toolchain_prefix "$SET")
    if [ -n "$REAL_PREFIX" ]; then
        echo "GCC_32=CROSS_COMPILE_ARM32=$GITHUB_WORKSPACE/gcc-32/bin/$REAL_PREFIX" >> "$GITHUB_ENV"
        echo "Detected 32-bit GCC prefix: $REAL_PREFIX"
    else
        echo "Error: Could not determine 32-bit GCC prefix in $SET." >&2
        exit 1
    fi
elif [ "$1" == "GCC_32_ONLY" ]; then
    SET="$GITHUB_WORKSPACE/gcc-32/bin"
    REAL_PREFIX=$(find_toolchain_prefix "$SET")
    if [ -n "$REAL_PREFIX" ]; then
        echo "GCC_32=CROSS_COMPILE=$GITHUB_WORKSPACE/gcc-32/bin/$REAL_PREFIX" >> "$GITHUB_ENV"
        echo "Detected 32-bit ONLY GCC prefix: $REAL_PREFIX"
    else
        echo "Error: Could not determine 32-bit ONLY GCC prefix in $SET." >&2
        exit 1
    fi
else
    echo "Usage: $0 [GCC_64|GCC_32|GCC_32_ONLY]" >&2
    exit 1
fi
