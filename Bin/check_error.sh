#!/usr/bin/env bash
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# 20250610

LOG_FILE="error.log"

print_separator() {
    echo "--------------------------------------------------------"
}

analyze_errors() {
    local log_file="$1"
    local error_found=false
    local error_count=0
    local current_error_lines=()
    local processing_error=false

    if [ ! -f "$log_file" ]; then
        echo "Error: Log file '$log_file' not existed。"
        exit 1
    fi

    echo "Analyzing log file: $log_file"
    print_separator

    while IFS= read -r line; do
        if [[ "$line" =~ " error:" || "$line" =~ " fatal error:" || "$line" =~ "undefined reference to" ]]; then
            processing_error=true
            error_found=true
            error_count=$((error_count + 1))

            current_error_lines=()
            current_error_lines+=("$line")
        elif [[ "$line" =~ "note:" || "$line" =~ "make["[0-9]"]:" && "$line" =~ "***" && "$processing_error" == true ]]; then

            current_error_lines+=("$line")
        elif [[ "$processing_error" == true && -n "$line" ]]; then

            current_error_lines+=("$line")
        else

            if [[ "$processing_error" == true ]]; then
                process_error_block "${current_error_lines[@]}" "$error_count"
                processing_error=false
                current_error_lines=()
            fi
        fi
    done < "$log_file"

    if [[ "$processing_error" == true ]]; then
        process_error_block "${current_error_lines[@]}" "$error_count"
    fi

    print_separator
    if [ "$error_found" = true ]; then
        echo "Total found $error_count error(s). "
        echo "Please carefully review the error messages and suggestions above.(Only Chinese) "
        touch have_error
    else
        echo "Not found any errors."
    fi
    print_separator
}

process_error_block() {
    local -a error_block=("${@:2}")
    local current_error_num="$1"

    echo "Error #$current_error_num:"
    for error_line in "${error_block[@]}"; do
        echo "  $error_line"
    done

    local error_type="非常见错误"
    local suggestion="请按编译输出错误结果，结合利用搜索引擎尝试解决"

    if grep -q "No such file or directory" <<< "${error_block[@]}"; then
        error_type="头文件或源文件缺失"
        suggestion="建议: 检查文件路径是否正确，或是否缺少依赖的开发库（例如: libssl-dev, zlib1g-dev）。"
    elif grep -q "undefined reference to" <<< "${error_block[@]}"; then
        error_type="链接错误: 缺少库或函数"
        suggestion="建议: 检查是否缺少链接的库（例如: -lssl, -lcrypto），或库的路径是否在LDFLAGS/LDLIBS中，或函数名是否拼写错误。"
    elif grep -q "unrecognized command line option" <<< "${error_block[@]}"; then
        error_type="编译器选项不支持"
        suggestion="建议: 你的编译器版本可能过旧或过新。检查Makefile中传递给编译器的选项，看是否与当前编译器版本兼容。考虑升级或降级工具链。"
    elif grep -q "misleading-indentation" <<< "${error_block[@]}"; then
        error_type="代码缩进与逻辑不符"
        suggestion="建议: 这是一个代码风格/逻辑潜在错误。在'if'、'for'、'while'等语句后添加大括号 '{}' 来明确代码块范围。或禁用此警告（不推荐）。"
    elif grep -q "type specifier missing" <<< "${error_block[@]}"; then
        error_type="C语言类型声明缺失"
        suggestion="建议: 变量或函数声明可能缺少类型（如'int'）。对于内核模块，可能是头文件缺失或顺序问题，或不同内核版本API变化。"
    elif grep -q "make["[0-9]"]:" <<< "${error_block[@]}" && grep -q "Error [0-9]" <<< "${error_block[@]}"; then
        error_type="Makefile构建错误"
        suggestion="建议: 这是Makefile规则执行失败。查看前面的具体错误信息，通常是某个子命令（如'gcc'，'ld'，'sh'）返回了非零状态码。"
    elif grep -q "target emulation unknown" <<< "${error_block[@]}"; then
        error_type="链接器仿真模式错误"
        suggestion="建议: 你的链接器（ld）不识别特定的仿真模式。检查是否混用了LLVM和GNU工具链，或确保LD变量正确指向LLVM的lld。"
    elif grep -q "cannot open" <<< "${error_block[@]}" && grep -q ".gz" <<< "${error_block[@]}"; then
        error_type="文件缺失（可能配置未生成）"
        suggestion="建议: 检查是否已运行'make defconfig'或你的设备特定的config。如果之前执行过'make mrproper'，需要重新配置。"
    elif grep -q "makes pointer from integer without a cast" <<< "${error_block[@]}"; then
        error_type="类型转换错误（指针与整数）"
        suggestion="建议: 这是一个严重的类型不匹配。通常是函数返回类型与预期不符（如返回int但期望指针）。可能需要修改源代码，或使用更兼容的编译器。"
    elif grep -q "MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver)" <<< "${error_block[@]}"; then
        error_type="Clang版本异常"
        suggestion="建议: 这是编译器与KernelSU不兼容的问题，通常发生在KernelSU官方版和SukiSU-Ultra上，对于官方版，可选择v0.9.5旧版，对于SukiSU-Ultra，一般建议更换KernelSU分支。"
    elif grep -q "not found (required by clang) " <<< "${error_block[@]}"; then
        error_type="Clang版本异常"
        suggestion="建议: 当前编译所用系统版本过老，若是20.04请使用22.04，反之latest。"
    elif grep -q "multiple definition of 'yylloc'" <<< "${error_block[@]}"; then
        error_type="内核缺陷"
        suggestion="建议: 将scripts/dtc/dtc-lexer.lex.c_shipped中的YYLTYPE yylloc;修改成extern YYLTYPE yylloc;"
    elif grep -q "assembler command failed with exit code 1" <<< "${error_block[@]}"; then
        error_type="Clang编译器错误"
        suggestion="建议: 更换Clang编译器版本"
    elif grep -q "incompatible pointer types passing 'atomic_long_t *'" <<< "${error_block[@]}"; then
        error_type="源代码指针类型错误"
        suggestion="建议: 通常为嵌入手动修补后cred.h产生的错误，将代码中atomic_inc_not_zero更换成atomic_long_inc_not_zero即可"
    fi

    echo "Error: $error_type"
    echo "Suggestion: $suggestion"
    print_separator
}

# Main
if [ "$#" -gt 0 ]; then
    LOG_FILE="$1"
fi

analyze_errors "$LOG_FILE"
