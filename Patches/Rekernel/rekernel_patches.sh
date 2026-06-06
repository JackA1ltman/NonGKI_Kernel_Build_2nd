#!/usr/bin/env bash
# Patches author: Sakion-Team @ Github
#                 AlexLiuDev233 @ Github
# Shell author: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18
# 20250822
patch_files=(
    drivers/net/Kconfig
    drivers/net/Makefile
)

KERNEL_VERSION=$(head -n 3 Makefile | grep -E 'VERSION|PATCHLEVEL' | awk '{print $3}' | paste -sd '.')
FIRST_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $1}')
SECOND_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $2}')

for i in "${patch_files[@]}"; do

    if grep -q "rekernel" "$i"; then
        echo "Warning: $i contains Re:Kernel"
        continue
    fi

    case $i in
    # drivers/ changes
    ## net/Kconfig
    drivers/net/Kconfig)
        sed -i ':a;N;$!ba;s/\(.*\)\nendif/\1\nsource "drivers\/net\/rekernel\/Kconfig"\n\nendif/' drivers/net/Kconfig
        ;;
    ## net/Makefile
    drivers/net/Makefile)
        sed -i '$a\obj-$(CONFIG_REKERNEL) += rekernel/' drivers/net/Makefile
        ;;
    esac

done
