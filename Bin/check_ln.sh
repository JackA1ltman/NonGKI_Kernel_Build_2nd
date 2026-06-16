#!/bin/bash
HAS_LINKS=$(find . -type l -print -quit)

if [ -n "$HAS_LINKS" ]; then
    if [ -z "$DT_URL" ] || [ -z "$DT_BRANCH" ]; then
        echo "致命错误：检测到当前目录下存在软链接，"
        echo "但未设置设备树仓库 (DT_URL) 或分支 (DT_BRANCH) 变量！"
        echo "请编辑脚本顶部的配置区域后重试。"
        exit 1
    fi
fi
echo "正在检测内核源码目录..."
KERNEL_DIR_NAME=""

for d in */ ; do
    dir_name="${d%/}"
    
    if [ "$dir_name" = "kernel" ] || [ "$dir_name" = "temp_modules" ] || [ "$dir_name" = "vendor" ] || [ "$dir_name" = "device" ]; then
        continue
    fi
    
    if [ -f "$dir_name/Makefile" ] && [ -d "$dir_name/arch" ] && [ -d "$dir_name/block" ]; then
        KERNEL_DIR_NAME="$dir_name"
        break
    fi
done

if [ -z "$KERNEL_DIR_NAME" ]; then
    KERNEL_DIR_NAME=$(find . -maxdepth 1 -type d -name "msm-*" -print -quit | sed 's|^\./||')
fi

if [ -z "$KERNEL_DIR_NAME" ]; then
    echo "无法自动检测到内核源码目录！"
    echo "请确保在包含内核源码的上一级目录运行此脚本。"
    exit 1
fi

echo "成功锁定内核源码目录: $KERNEL_DIR_NAME"
echo "临时将内核源码移动至 kernel/$KERNEL_DIR_NAME 结构..."
if [ -d "$KERNEL_DIR_NAME" ] && [ ! -d "kernel/$KERNEL_DIR_NAME" ]; then
    mkdir -p kernel
    mv "$KERNEL_DIR_NAME" "kernel/$KERNEL_DIR_NAME"
else
    echo "目标结构 kernel/$KERNEL_DIR_NAME 已存在或源目录已移动，跳过重组。"
fi

if [ -n "$DT_URL" ] && [ -n "$DT_BRANCH" ]; then
    echo "正在拉取设备树 (分支: $DT_BRANCH)..."
    git clone "$DT_URL" -b "$DT_BRANCH" --depth=1 temp_modules
    
    if [ $? -ne 0 ]; then
        echo "设备树克隆失败，请检查网络、仓库地址或分支是否正确。"
        echo "正在回退内核目录结构保护现场..."
        mv "kernel/$KERNEL_DIR_NAME" "./$KERNEL_DIR_NAME"
        rmdir kernel 2>/dev/null || true
        exit 1
    fi

    echo "正在部署设备树 (提取 vendor 和 device)..."
    rm -rf ./vendor ./device
    
    [ -d "temp_modules/vendor" ] && mv temp_modules/vendor ./vendor
    [ -d "temp_modules/device" ] && mv temp_modules/device ./device
    
    rm -rf temp_modules
    echo "设备树部署完毕。"
fi
echo "开始扫描内核目录，并重建外部软链接为绝对路径..."

KERNEL_ABS_PATH=$(readlink -f "kernel/$KERNEL_DIR_NAME")

find "kernel/$KERNEL_DIR_NAME" -type l -print0 | while IFS= read -r -d $'\0' link; do
    target=$(readlink -f "$link")
    
    if [[ "$target" == "$KERNEL_ABS_PATH"/* ]] || [[ "$target" == "$KERNEL_ABS_PATH" ]]; then
        echo "跳过内部链接: $link"
        continue
    fi

    if [ -n "$target" ]; then
        echo "   正在重写为绝对路径: $link"
        ln -snf "$target" "$link"
    fi
done

echo "内核外部软链接绝对路径重建完毕！"

echo "正在恢复内核源码目录结构..."
if [ -d "kernel/$KERNEL_DIR_NAME" ]; then
    mv "kernel/$KERNEL_DIR_NAME" "./$KERNEL_DIR_NAME"
    rmdir kernel 2>/dev/null || true
    echo "内核源码已恢复为 ./$KERNEL_DIR_NAME"
fi

echo "========================================"
echo "           软链接修复已完成！"
echo "========================================"