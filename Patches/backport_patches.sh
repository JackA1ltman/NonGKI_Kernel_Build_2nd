#!/bin/bash
# Patches author: backslashxx @ Github
# Shell author: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18, 3.10, 3.4
# 20250323
patch_files=(
    fs/namespace.c
    fs/internal.h
    kernel/trace/trace_kprobe.c
    mm/maccess.c
    include/linux/uaccess.h
    include/linux/seccomp.h
)

PATCH_DATE="2025-11-14"
KERNEL_VERSION=$(head -n 3 Makefile | grep -E 'VERSION|PATCHLEVEL' | awk '{print $3}' | paste -sd '.')
FIRST_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $1}')
SECOND_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $2}')

echo "Current backport patch version:$PATCH_DATE"

for i in "${patch_files[@]}"; do

    if grep -q "path_umount" "$i"; then
        echo "[-] Warning: $i contains Backport"
        echo "[+] Code in here:"
        grep -n "path_umount" "$i"
        echo "[-] End of file."
        echo "======================================"
        continue
    elif grep -q "selinux_inode(inode)" "$i"; then
        echo "[-] Warning: $i contains Backport"
        echo "[+] Code in here:"
        grep -n "selinux_inode(inode)" "$i"
        echo "[-] End of file."
        echo "======================================"
        continue
    elif grep -q "selinux_cred(new)" "$i"; then
        echo "[-] Warning: $i contains Backport"
        echo "[+] Code in here:"
        grep -n "selinux_cred" "$i"
        echo "[-] End of file."
        echo "======================================"
        continue
    fi

    case $i in

    # fs/ changes
    ## fs/namespace.c
    fs/namespace.c)
        echo "======================================"

        sed -i '/^SYSCALL_DEFINE2(umount, char __user \*, name, int, flags)/i\static int can_umount(const struct path *path, int flags)\n{\n\tstruct mount *mnt = real_mount(path->mnt);\n\tif (!may_mount())\n\t\treturn -EPERM;\n\tif (path->dentry != path->mnt->mnt_root)\n\t\treturn -EINVAL;\n\tif (!check_mnt(mnt))\n\t\treturn -EINVAL;\n\tif (mnt->mnt.mnt_flags \& MNT_LOCKED) \/\* Check optimistically *\/\n\t\treturn -EINVAL;\n\tif (flags \& MNT_FORCE \&\& !capable(CAP_SYS_ADMIN))\n\t\treturn -EPERM;\n\treturn 0;\n}\n\/\/ caller is responsible for flags being sane\nint path_umount(struct path *path, int flags)\n{\n\tstruct mount *mnt = real_mount(path->mnt);\n\tint ret;\n\tret = can_umount(path, flags);\n\tif (!ret)\n\t\tret = do_umount(mnt, flags);\n\t\/\* we mustn'"'"'t call path_put() as that would clear mnt_expiry_mark *\/\n\tdput(path->dentry);\n\tmntput_no_expire(mnt);\n\treturn ret;\n}\n' fs/namespace.c

        if grep -q "can_umount" "fs/namespace.c"; then
            echo "[+] fs/namespace.c Patched!"
            echo "[+] Count: $(grep -c "can_umount" "fs/namespace.c")"
        else
            echo "[-] fs/namespace.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## fs/internal.h
    fs/internal.h)
        sed -i '/^extern void __init mnt_init(void);$/a\int path_umount(struct path *path, int flags);' fs/internal.h

        if grep -q "path_umount" "fs/internal.h"; then
            echo "[+] fs/internal.h Patched!"
            echo "[+] Count: $(grep -c "path_umount" "fs/internal.h")"
        else
            echo "[-] fs/internal.h patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    # mm/ changes
    ## mm/maccess.c
    mm/maccess.c)
        if grep -q "strncpy_from_user_nofault" "drivers/kernelsu/sucompat.c" >/dev/null 2>&1; then
            sed -i 's/strncpy_from_unsafe_user/strncpy_from_user_nofault/g' mm/maccess.c

            if grep -q "strncpy_from_user_nofault" "mm/maccess.c"; then
                echo "[+] mm/maccess.c Patched!"
                echo "[+] Count: $(grep -c "strncpy_from_user_nofault" "mm/maccess.c")"
            else
                echo "[-] mm/maccess.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] KernelSU have no strncpy_from_user_nofault, Skipped."
        fi

        echo "======================================"
        ;;

    # kernel/ changes
    # trace/trace_kprobe.c
    kernel/trace/trace_kprobe.c)
        if grep -q "strncpy_from_user_nofault" "drivers/kernelsu/sucompat.c" >/dev/null 2>&1; then
            sed -i 's/strncpy_from_unsafe_user/strncpy_from_user_nofault/g' kernel/trace/trace_kprobe.c

            if grep -q "strncpy_from_user_nofault" "kernel/trace/trace_kprobe.c"; then
                echo "[+] kernel/trace/trace_kprobe.c Patched!"
                echo "[+] Count: $(grep -c "strncpy_from_user_nofault" "kernel/trace/trace_kprobe.c")"
            else
                echo "[-] kernel/trace/trace_kprobe.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] KernelSU have no strncpy_from_user_nofault, Skipped."
        fi

        echo "======================================"
        ;;

    # include/ changes
    ## include/linux/uaccess.h
    include/linux/uaccess.h)
        if grep -q "strncpy_from_user_nofault" "drivers/kernelsu/sucompat.c" >/dev/null 2>&1; then
            sed -i 's/^extern long strncpy_from_unsafe_user/long strncpy_from_user_nofault/' include/linux/uaccess.h

            if grep -q "strncpy_from_user_nofault" "include/linux/uaccess.h"; then
                echo "[+] include/linux/uaccess.h Patched!"
                echo "[+] Count: $(grep -c "strncpy_from_user_nofault" "include/linux/uaccess.h")"
            else
                echo "[-] include/linux/uaccess.h patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] KernelSU have no strncpy_from_user_nofault, Skipped."
        fi

        echo "======================================"
        ;;

    ## linux/seccomp.h
    include/linux/seccomp.h)
        echo "======================================"

        if grep -q "filter_count" "include/linux/seccomp.h" >/dev/null 2>&1; then
            echo "[-] Detected filter_count in kernel, Skipped."
        else
            sed -i '/#include <linux\/thread_info.h>/a\#include <linux\/atomic.h>' include/linux/seccomp.h
            sed -i '/struct seccomp_filter \*filter;/i\ \tatomic_t filter_count;' include/linux/seccomp.h

            if grep -q "filter_count" "include/linux/seccomp.h"; then
                echo "[+] include/linux/seccomp.h Patched!"
                echo "[+] Count: $(grep -c "filter_count" "include/linux/seccomp.h")"
            else
                echo "[-] include/linux/seccomp.h patch failed for unknown reasons, please provide feedback in time."
            fi
        fi

        echo "======================================"
        ;;
    esac

done
