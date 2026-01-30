#!/bin/bash
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18
# 20251120

KSU_FOLDER=("drivers/kernelsu" "KernelSU" "KernelSU-Next")

KSU_CLEAN_FILES=("fs/exec.c" "fs/read_write.c" "fs/open.c" "fs/stat.c" "fs/devpts/inode.c" "fs/namei.c" "drivers/input/input.c" "drivers/tty/pty.c" "security/selinux/hooks.c" "kernel/reboot.c" "kernel/sys.c")

SUSFS_CLEAN_FILES=("security/selinux/avc.c" "kernel/kallsyms.c" "kernel/sys.c" "kernel/reboot.c" "fs/dcache.c" "fs/statfs.c" "fs/namespace.c" "fs/proc_namespace.c" "fs/stat.c" "fs/namei.c" "fs/readdir.c" "fs/exec.c" "fs/proc/task_mmu.c" "fs/proc/base.c" "fs/proc/fd.c" "fs/proc/cmdline.c" "fs/overlayfs/super.c" "fs/overlayfs/overlayfs.h" "fs/overlayfs/inode.c" "fs/overlayfs/inode.c" "fs/notify/fdinfo.c" "fs/devpts/inode.c" "include/linux/sched.h" "include/linux/mount.h")

SUSFS_REMAIN_CLEAN_FILES=("fs/susfs.c" "fs/sus_su.c" "include/linux/susfs.h" "include/linux/susfs_def.h")

# Removal of KernelSU

for file in "${KSU_FOLDER[@]}"; do
    rm -rf "${file}"

    if [ -f "${file}" ] || [ -d "${file}" ]; then
        echo "[-] Could not remove ${file}."
    else
        echo "[+] Cleaned for ${file}."
    fi
done

# Removal of KernelSU Hook

for file in "${KSU_CLEAN_FILES[@]}"; do
    sed -i '/#ifdef CONFIG_KSU/,/#endif/d' "${file}"

    if grep -q "CONFIG_KSU" "${file}"; then
        echo "[-] Could not remove KernelSU hook from ${file}."
    else
        echo "[+] Cleaned KernelSU Hook for ${file}."
    fi
done

# Removal of SuSFS

for file in "${SUSFS_CLEAN_FILES[@]}"; do
    perl -i -0777 -pe 's/#ifndef CONFIG_KSU_SUSFS[^\n]*\n(.*?)#else\n(.*?)#endif\n/$1/gs; s/#ifdef CONFIG_KSU_SUSFS[^\n]*\n(.*?)#else\n(.*?)#endif\n/$1/gs' "${file}"
    sed -i '/#ifdef CONFIG_KSU_SUSFS/,/#endif/d' "${file}"
    sed -i '/#if defined(CONFIG_KSU_SUSFS/,/#endif/d' "${file}"
    sed -i '/#ifndef CONFIG_KSU_SUSFS/,/#endif/d' "${file}"

    if grep -q "CONFIG_KSU_SUSFS/" "${file}"; then
        echo "[-] Could not remove SuSFS hook from ${file}."
    else
        echo "[+] Cleaned SuSFS Hook for ${file}."
    fi
done

for file in "${SUSFS_REMAIN_CLEAN_FILES[@]}"; do
    rm -f "${file}"

    if [ -f "${file}" ]; then
        echo "[-] Could not remove file ${file}."
    else
        echo "[+] Removed file ${file}."
    fi
done

if grep -q "CONFIG_KSU_SUSFS" "fs/Makefile"; then
    sed -i '/CONFIG_KSU_SUSFS/d' fs/Makefile
    if grep -q "CONFIG_KSU_SUSFS" "fs/Makefile"; then
        echo "[-] Could not remove code from fs/Makefile."
    else
        echo "[+] Removed code for fs/Makefile."
    fi
else
    echo "[-] Have no CONFIG_KSU_SUSFS in fs/Makefile"
fi
