#!/usr/bin/env bash
# Shell author: JackA1ltman <cs2dtzq@163.com>
# 20250610

find_toolchain_prefix() {
    local toolchain_bin_dir="$1"

    if [ ! -d "$toolchain_bin_dir" ]; then
        echo "Error: Folder '$toolchain_bin_dir' not existed." >&2
        return 1
    fi

    local tools_to_check=("ar" "nm" "ld" "objdump" "readelf" "strip")
    local possible_prefixes=()
    local real_target_name=""
    local prefix=""

    for tool in "${tools_to_check[@]}"; do
        for tool_path in "$toolchain_bin_dir"/*"${tool}"; do
            if [ -x "$tool_path" ] && [ -f "$tool_path" ]; then
                real_target_name=$(basename "$(readlink -f "$tool_path")")
                prefix="${real_target_name%%-${tool}}"

                if [ -n "$prefix" ] && [ "$prefix" != "$real_target_name" ]; then
                    possible_prefixes+=("$prefix-")
                fi
            fi
        done
    done

    if [ ${#possible_prefixes[@]} -eq 0 ]; then
        echo "Error: No recognizable toolchain prefixes found in '$toolchain_bin_dir' using tools: ${tools_to_check[*]}" >&2
        return 1
    fi

    local sorted_prefixes
    sorted_prefixes=$(printf "%s\n" "${possible_prefixes[@]}" | sort -u | awk '{ print length, $0 }' | sort -n)

    local min_length=6
    local shortest_prefix=""

    while IFS= read -r line; do
        local len=$(echo "$line" | cut -d' ' -f1)
        local prefix_value=$(echo "$line" | cut -d' ' -f2-)

        if [ "$len" -ge "$min_length" ]; then
            shortest_prefix="$prefix_value"
            echo "Debug: Found prefix with length $len: $prefix_value" >&2
            break
        else
            echo "Debug: Skipped prefix '$prefix_value' (length $len < $min_length)" >&2
        fi
    done <<< "$sorted_prefixes"

    if [ -n "$shortest_prefix" ]; then
        echo "$shortest_prefix"
        return 0
    else
        echo "Error: Could not find a prefix with length >= $min_length characters." >&2
        echo "Available prefixes were:" >&2
        printf "%s\n" "${possible_prefixes[@]}" | sort -u >&2
        return 1
    fi
}

if [ "$1" == "GCC_64" ]; then
    SET="$GITHUB_WORKSPACE/gcc-64/bin"
    REAL_PREFIX=$(find_toolchain_prefix "$SET")
    if [ -n "$REAL_PREFIX" ]; then
        echo "GCC_64=CROSS_COMPILE=$GITHUB_WORKSPACE/gcc-64/bin/${REAL_PREFIX}" >> "$GITHUB_ENV"
        echo "Detected shortest 64-bit prefix (>5 chars): ${REAL_PREFIX}"
    else
        echo "Error: Could not determine 64-bit GCC prefix in $SET." >&2
        exit 1
    fi
elif [ "$1" == "GCC_32" ]; then
    SET="$GITHUB_WORKSPACE/gcc-32/bin"
    REAL_PREFIX=$(find_toolchain_prefix "$SET")
    if [ -n "$REAL_PREFIX" ]; then
        echo "GCC_32=CROSS_COMPILE_ARM32=$GITHUB_WORKSPACE/gcc-32/bin/${REAL_PREFIX}" >> "$GITHUB_ENV"
        echo "Detected shortest 32-bit prefix (>5 chars): ${REAL_PREFIX}"
    else
        echo "Error: Could not determine 32-bit GCC prefix in $SET." >&2
        exit 1
    fi
else
    echo "Usage: $0 [GCC_64|GCC_32]" >&2
    exit 1
fi
