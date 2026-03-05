#!/bin/bash
# Patches author: simonpunk @ Gitlab
#                 backslashxx @ Github
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18
# 20251120

# This Hook is only available for SuSFS v2.0.00 onwards.

patch_files=(
    fs/exec.c
    fs/open.c
    fs/read_write.c
    fs/stat.c
    fs/namei.c
    fs/devpts/inode.c
    drivers/input/input.c
    drivers/tty/pty.c
    security/security.c
    security/selinux/hooks.c
    kernel/reboot.c
    kernel/sys.c
)

PATCH_LEVEL="2.0.00"
KERNEL_VERSION=$(head -n 3 Makefile | grep -E 'VERSION|PATCHLEVEL' | awk '{print $3}' | paste -sd '.')
FIRST_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $1}')
SECOND_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $2}')

echo "Current susfs patch version:$PATCH_LEVEL"

for i in "${patch_files[@]}"; do

    if grep -q "ksu_handle" "$i"; then
        echo "[-] Warning: $i contains KernelSU"
        echo "[+] Code in here:"
        grep -n "ksu_handle" "$i"
        echo "[-] End of file."
        echo "======================================"
        continue
    fi

    case $i in
    # fs/ changes
    ## exec.c
    fs/exec.c)
        echo "======================================"

        sed -i '/#include <linux\/vmalloc.h>/a\#ifdef CONFIG_KSU_SUSFS\n#include <linux/susfs_def.h>\n#endif' fs/exec.c
        if grep -q "__do_execve_file" "fs/exec.c"; then
            sed -i '/static int __do_execve_file(int fd, struct filename \*filename,/i #ifdef CONFIG_KSU_SUSFS\nextern bool ksu_execveat_hook __read_mostly;\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool susfs_is_sdcard_android_data_decrypted __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\n\t\t\tvoid *envp, int *flags);\nextern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv,\n\t\t\t\tvoid *envp, int *flags);\n#endif' fs/exec.c
        else
            sed -i '/^static int do_execveat_common(int fd, struct filename \*filename,/i\#ifdef CONFIG_KSU_SUSFS\nextern bool ksu_execveat_hook __read_mostly;\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool susfs_is_sdcard_android_data_decrypted __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\n\t\t\tvoid *envp, int *flags);\nextern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\n\t\t\t\t void *argv, void *envp, int *flags);\n#endif\n' fs/exec.c
        fi
        sed -i '/return PTR_ERR(filename);/a\#ifdef CONFIG_KSU_SUSFS\n\tif (likely(susfs_is_current_proc_umounted()) || !ksu_su_compat_enabled) {\n\t\tgoto orig_flow;\n\t}\n\tif (unlikely(ksu_execveat_hook || !susfs_is_sdcard_android_data_decrypted)) {\n\t\tksu_handle_execveat(\&fd, \&filename, \&argv, \&envp, \&flags);\n\t} else if ((__ksu_is_allow_uid_for_current(current_uid().val))) {\n\t\tksu_handle_execveat_sucompat(\&fd, \&filename, \&argv, \&envp, \&flags);\n\t}\norig_flow:\n#endif' fs/exec.c

        if grep -q "ksu_handle_execveat_sucompat" "fs/exec.c"; then
            echo "[+] fs/exec.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_execveat_sucompat" "fs/exec.c")"
        else
            echo "[-] fs/exec.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## open.c
    fs/open.c)
        sed -i '/#include <linux\/compat.h>/a #ifdef CONFIG_KSU_SUSFS\n#include <linux\/susfs_def.h>\n#endif' fs/open.c
        if grep -q "do_faccessat" "fs/open.c" >/dev/null 2>&1; then
            sed -i '/long do_faccessat(int dfd, const char __user \*filename, int mode)/i #ifdef CONFIG_KSU_SUSFS\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n\t\t\tint *flags);\n#endif' fs/open.c
        else
            sed -i '/SYSCALL_DEFINE3(faccessat/i #ifdef CONFIG_KSU_SUSFS\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n             int *flags);\n#endif' fs/open.c
        fi
        sed -i '/if (mode & ~S_IRWXO)/i #ifdef CONFIG_KSU_SUSFS\n    if (likely(susfs_is_current_proc_umounted()) || !ksu_su_compat_enabled) {\n        goto orig_flow;\n    }\n\n    if (unlikely(__ksu_is_allow_uid_for_current(current_uid().val))) {\n        ksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n    }\n\norig_flow:\n#endif' fs/open.c

        if grep -q "ksu_handle_faccessat" "fs/open.c"; then
            echo "[+] fs/open.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_faccessat" "fs/open.c")"
        else
            echo "[-] fs/open.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## read_write.c
    fs/read_write.c)
        if grep -q "ksu_init_rc_hook" "drivers/kernelsu/ksud.c"; then
            sed -i '/SYSCALL_DEFINE3(read,/i #ifdef CONFIG_KSU\nextern bool ksu_init_rc_hook __read_mostly;\nextern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd);\n#endif' fs/read_write.c
            if grep -q "ksys_read" "fs/read_write.c" >/dev/null 2>&1; then
                sed -i '/return ksys_read(fd, buf, count);/i #ifdef CONFIG_KSU\n\tif (unlikely(ksu_init_rc_hook))\n\t\tksu_handle_sys_read(fd);\n#endif' fs/read_write.c
            else
                sed -i '0,/if (f\.file) {/{s/if (f\.file) {/\n#ifdef CONFIG_KSU\n\tif (unlikely(ksu_init_rc_hook))\n\t\tksu_handle_sys_read(fd);\n#endif\n\tif (f.file) {/}' fs/read_write.c
            fi
        else
            sed -i '/SYSCALL_DEFINE3(read,/i #ifdef CONFIG_KSU\nextern bool ksu_vfs_read_hook __read_mostly;\nextern __attribute__((cold)) int ksu_handle_sys_read(unsigned int fd,\n\t\t\tchar __user **buf_ptr, size_t *count_ptr);\n#endif' fs/read_write.c
            if grep -q "ksys_read" "fs/read_write.c" >/dev/null 2>&1; then
                sed -i '/return ksys_read(fd, buf, count);/i #ifdef CONFIG_KSU\n\tif (unlikely(ksu_vfs_read_hook))\n\t\tksu_handle_sys_read(fd, &buf, &count);\n#endif' fs/read_write.c
            else
                sed -i '0,/if (f\.file) {/{s/if (f\.file) {/\n#ifdef CONFIG_KSU\n\tif (unlikely(ksu_vfs_read_hook))\n\t\tksu_handle_sys_read(fd, \&buf, \&count);\n#endif\n\tif (f.file) {/}' fs/read_write.c
            fi
        fi

        if grep -q "ksu_init_rc_hook" "fs/read_write.c"; then
            echo "[+] fs/read_write.c Patched!"
            echo "[+] Count: $(grep -c "ksu_init_rc_hook" "fs/read_write.c")"
        elif grep -q "ksu_handle_sys_read" "fs/read_write.c"; then
            echo "[+] fs/read_write.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_sys_read" "fs/read_write.c")"
        else
            echo "[-] fs/read_write.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## stat.c
    fs/stat.c)
        if grep -q "unistd" "fs/stat.c" && ! grep -q "susfs_def.h" "fs/stat.c"; then
            sed -i '/#include <asm\/unistd.h>/a\#ifdef CONFIG_KSU_SUSFS\n#include <linux\/susfs_def.h>\n#endif' fs/stat.c
        else
            sed -i '/#include <asm\/uaccess.h>/i #ifdef CONFIG_KSU_SUSFS\n#include <linux\/susfs_def.h>\n#endif' fs/stat.c
        fi

        if grep -q "ksu_handle_vfs_fstat" "drivers/kernelsu/ksud.c"; then
            if grep -q "vfs_statx_fd" "fs/stat.c"; then
                sed -i '/int vfs_statx_fd(unsigned int fd, struct kstat \*stat,/i\#ifdef CONFIG_KSU_SUSFS\nextern bool ksu_init_rc_hook __read_mostly;\nextern void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr);\n#endif \/\/ #ifdef CONFIG_KSU_SUSFS' fs/stat.c
                sed -i '/\t\tfdput(f);/i\#ifdef CONFIG_KSU_SUSFS\n\t\tif (unlikely(ksu_init_rc_hook)) {\n\t\t\tksu_handle_vfs_fstat(fd, \&stat->size);\n\t\t}\n#endif \/\/ #ifdef CONFIG_KSU_SUSFS' fs/stat.c

            else
                sed -i '/int vfs_fstat(unsigned int fd, struct kstat \*stat)/i\#ifdef CONFIG_KSU_SUSFS\nextern bool ksu_init_rc_hook __read_mostly;\nextern void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr);\n#endif \/\/ #ifdef CONFIG_KSU_SUSFS' fs/stat.c
                sed -i '/\t\tfdput(f);/i\#ifdef CONFIG_KSU_SUSFS\n\t\tif (unlikely(ksu_init_rc_hook)) {\n\t\t\tksu_handle_vfs_fstat(fd, \&stat->size);\n\t\t}\n#endif \/\/ #ifdef CONFIG_KSU_SUSFS' fs/stat.c

            fi

        elif grep -q "ksu_init_rc_hook" "drivers/kernelsu/ksud.c"; then
            sed -i '/#if !defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_SYS_NEWFSTATAT)/i\#ifdef CONFIG_KSU_SUSFS\nextern bool ksu_init_rc_hook __read_mostly;\nextern void ksu_handle_sys_newfstatat(int fd, loff_t *kstat_size_ptr);\n#endif\n' fs/stat.c
            awk '/return cp_new_stat\(&stat, statbuf\);/{line=$0; lnum=NR} {lines[NR]=$0} END {for(i=1;i<=NR;i++) if(i==lnum) {print "#ifdef CONFIG_KSU_SUSFS"; print "\tif (unlikely(ksu_init_rc_hook)) {"; print "\t\tksu_handle_sys_newfstatat(dfd, &stat.size);"; print "\t}"; print "#endif"; print lines[i]} else print lines[i]}' fs/stat.c > fs/stat.c.tmp && mv fs/stat.c.tmp fs/stat.c

        else
            if grep -q "vfs_statx" "fs/stat.c"; then
                echo "[+] Checked vfs_statx existed in Kernel!"

                sed -i '/int vfs_statx(int dfd, const char __user \*filename, int flags,/i #ifdef CONFIG_KSU_SUSFS\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n#endif' fs/stat.c
                sed -i '/unsigned int lookup_flags = LOOKUP_FOLLOW | LOOKUP_AUTOMOUNT;/a #ifdef CONFIG_KSU_SUSFS\n\tif (likely(susfs_is_current_proc_umounted()) || !ksu_su_compat_enabled) {\n\t\tgoto orig_flow;\n\t}\n\n\tif (unlikely(__ksu_is_allow_uid_for_current(current_uid().val))) {\n\t\tksu_handle_stat(&dfd, &filename, &flags);\n\t}\norig_flow:\n#endif' fs/stat.c
            else
                sed -i '/EXPORT_SYMBOL(vfs_fstat);/i #ifdef CONFIG_KSU_SUSFS\nextern bool ksu_su_compat_enabled __read_mostly;\nextern bool __ksu_is_allow_uid_for_current(uid_t uid);\nextern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n#endif\n' fs/stat.c
                sed -i '/unsigned int lookup_flags = 0;/a #ifdef CONFIG_KSU_SUSFS\n\tif (likely(susfs_is_current_proc_umounted()) || !ksu_su_compat_enabled) {\n\t\tgoto orig_flow;\n\t}\n\n\tif (unlikely(__ksu_is_allow_uid_for_current(current_uid().val))) {\n\t\tksu_handle_stat(&dfd, &filename, &flags);\n\t}\norig_flow:\n#endif' fs/stat.c
            fi
        fi

        if grep -q "ksu_handle_newfstat_ret" "drivers/kernelsu/syscall_table_hook.c" >/dev/null 2>&1; then
            sed -i '/SYSCALL_DEFINE2(newfstat, unsigned int, fd, struct stat __user \*, statbuf)/i\#ifdef CONFIG_KSU\nextern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);\n#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)\nextern void ksu_handle_fstat64_ret(unsigned int *fd, struct stat64 __user **statbuf_ptr); \/\/ optional\n#endif\n#endif\n' fs/stat.c
            sed -i '/error = cp_new_stat(\&stat, statbuf);/a\#ifdef CONFIG_KSU\n\tksu_handle_newfstat_ret(\&fd, \&statbuf);\n#endif\n' fs/stat.c
            awk '/error = cp_new_stat64\(&stat, statbuf\);/{line=$0; lnum=NR} {lines[NR]=$0} END {for(i=1;i<=NR;i++) {print lines[i]; if(i==lnum) {print "#ifdef CONFIG_KSU // for 32-bit"; print "\tksu_handle_fstat64_ret(&fd, &statbuf);"; print "#endif"}}}' fs/stat.c > fs/stat.c.tmp && mv fs/stat.c.tmp fs/stat.c
        fi

        if grep -q "ksu_init_rc_hook" "fs/stat.c"; then
            echo "[+] fs/stat.c Patched!"
            echo "[+] Count: $(grep -c "ksu_init_rc_hook" "fs/stat.c")"
        elif grep -q "ksu_handle_stat" "fs/stat.c"; then
            echo "[+] fs/stat.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_stat" "fs/stat.c")"
        else
            echo "[-] fs/stat.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## namei.c
    fs/namei.c)
        if grep "throne_tracker" "fs/namei.c" >/dev/null 2>&1; then
            echo "[-] Warning: fs/namei.c contains KernelSU"
            echo "[+] Code in here:"
            grep -n "throne_tracker" "fs/namei.c"
            echo "[-] End of file."
        elif [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 19 ]; then
            sed -i '/if (unlikely(err)) {/a \#ifdef CONFIG_KSU\n\t\tif (unlikely(strstr(current->comm, "throne_tracker"))) {\n\t\t\terr = -ENOENT;\n\t\t\tgoto out_err;\n\t\t}\n#endif' fs/namei.c

            if grep -q "throne_tracker" "fs/namei.c"; then
                echo "[+] fs/namei.c Patched!"
                echo "[+] Count: $(grep -c "throne_tracker" "fs/namei.c")"
            else
                echo "[-] fs/namei.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] Kernel needn't throne_tracker, Skipped."
        fi

        echo "======================================"
        ;;
    ## devpts/inode.c
    fs/devpts/inode.c)
        sed -i '/#include <linux\/seq_file.h>/a\#ifdef CONFIG_KSU_SUSFS\n#include <linux/susfs_def.h>\n#endif' fs/devpts/inode.c
        sed -i '/^struct dentry \*devpts_pty_new(struct pts_fs_info \*fsi, int index, void \*priv)/i\#ifdef CONFIG_KSU_SUSFS\nextern int ksu_handle_devpts(struct inode*);\n#endif\n' fs/devpts/inode.c
        sed -i '/if (dentry->d_sb->s_magic != DEVPTS_SUPER_MAGIC)/i\#ifdef CONFIG_KSU_SUSFS\n\tif (likely(susfs_is_current_proc_umounted())) {\n\t\tgoto orig_flow;\n\t}\n\tksu_handle_devpts(dentry->d_inode);\norig_flow:\n#endif\n' fs/devpts/inode.c

        if grep -q "ksu_handle_devpts" "fs/devpts/inode.c"; then
            echo "[+] fs/devpts/inode.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_devpts" "fs/devpts/inode.c")"
        else
            echo "[-] fs/devpts/inode.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    # drivers/ changes
    ## input/input.c
    drivers/input/input.c)
        sed -i '/^static void input_handle_event(struct input_dev \*dev,/i\#ifdef CONFIG_KSU\nextern bool ksu_input_hook __read_mostly;\nextern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);\n#endif\n' drivers/input/input.c
        sed -i '/if (disposition != INPUT_IGNORE_EVENT && type != EV_SYN)/i\#ifdef CONFIG_KSU_SUSFS\n\tif (unlikely(ksu_input_hook))\n\t\tksu_handle_input_handle_event(\&type, \&code, \&value);\n#endif\n' drivers/input/input.c

        if grep -q "ksu_handle_input_handle_event" "drivers/input/input.c"; then
            echo "[+] drivers/input/input.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_input_handle_event" "drivers/input/input.c")"
        else
            echo "[-] drivers/input/input.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## tty/pty.c
    drivers/tty/pty.c)
        if grep -q "ksu_handle_devpts" "kernel/sucompat.c" >/dev/null 2>&1; then
            echo "[+] Checked ksu_handle_devpts existed in KernelSU!"

            sed -i '/^static struct tty_struct \*pts_unix98_lookup(struct tty_driver \*driver,/i\#ifdef CONFIG_KSU\nextern int ksu_handle_devpts(struct inode*);\n#endif\n' drivers/tty/pty.c
            sed -i '0,/struct tty_struct \*tty;/{s/struct tty_struct \*tty;/&\n#ifdef CONFIG_KSU\n\tksu_handle_devpts((struct inode *)file->f_path.dentry->d_inode);\n#endif/}' drivers/tty/pty.c

            if grep -q "ksu_handle_devpts" "drivers/tty/pty.c"; then
                echo "[+] drivers/tty/pty.c Patched!"
                echo "[+] Count: $(grep -c "ksu_handle_devpts" "drivers/tty/pty.c")"
            else
                echo "[-] drivers/tty/pty.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] KernelSU have no devpts, Skipped."
        fi

        echo "======================================"
        ;;

    # security/ changes
    ## security.c
    security/security.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 19 ]; then
            sed -i '/int security_binder_set_context_mgr(struct task_struct/i \#ifdef CONFIG_KSU\n\extern int ksu_bprm_check(struct linux_binprm *bprm);\n\extern int ksu_handle_rename(struct dentry *old_dentry, struct dentry *new_dentry);\n\extern int ksu_handle_setuid(struct cred *new, const struct cred *old);\n\#endif' security/security.c
            sed -i '/ret = security_ops->bprm_check_security(bprm);/i \#ifdef CONFIG_KSU\n\tksu_bprm_check(bprm);\n\#endif' security/security.c
            sed -i '/if (unlikely(IS_PRIVATE(old_dentry->d_inode) ||/i \#ifdef CONFIG_KSU\n\tksu_handle_rename(old_dentry, new_dentry);\n\#endif' security/security.c
            sed -i '/return security_ops->task_fix_setuid(new, old, flags);/i \#ifdef CONFIG_KSU\n\tksu_handle_setuid(new, old);\n\#endif' security/security.c

            if grep -q "ksu_handle_setuid" "security/security.c"; then
                echo "[+] security/security.c Patched!"
                echo "[+] Count: $(grep -c "ksu_handle_setuid" "security/security.c")"
            else
                echo "[-] security/security.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] Kernel needn't setuid, Skipped."
        fi

        echo "======================================"
        ;;
    ## selinux/hooks.c
    security/selinux/hooks.c)
        if grep "security_secid_to_secctx" "security/selinux/hooks.c"; then
            echo "[-] Detected security_secid_to_secctx existed, security/selinux/hooks.c Patched!"
        else
            sed -i '/int nnp = (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS);/i\#ifdef CONFIG_KSU\n    static u32 ksu_sid;\n    char *secdata;\n#endif' security/selinux/hooks.c
            sed -i '/if (!nnp && !nosuid)/i\#ifdef CONFIG_KSU\n    int error;\n    u32 seclen;\n#endif' security/selinux/hooks.c
            sed -i '/return 0; \/\* No change in credentials \*\//a\\n#ifdef CONFIG_KSU\n    if (!ksu_sid)\n        security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);\n\n    error = security_secid_to_secctx(old_tsec->sid, &secdata, &seclen);\n    if (!error) {\n        rc = strcmp("u:r:init:s0", secdata);\n        security_release_secctx(secdata, seclen);\n        if (rc == 0 && new_tsec->sid == ksu_sid)\n            return 0;\n    }\n#endif' security/selinux/hooks.c
        fi

        if grep -q "security_secid_to_secctx" "security/selinux/hooks.c"; then
            echo "[+] security/selinux/hooks.c Patched!"
            echo "[+] Count: $(grep -c "security_secid_to_secctx" "security/selinux/hooks.c")"
        else
            echo "[-] security/selinux/hooks.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    # kernel/ changes
    ## reboot.c
    kernel/reboot.c)
        sed -i '/SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,/i \#ifdef CONFIG_KSU\n\extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\n\#endif' kernel/reboot.c
        sed -i '/int ret = 0;/a #ifdef CONFIG_KSU_SUSFS\n    ret = ksu_handle_sys_reboot(magic1, magic2, cmd, \&arg);\n    if (ret) {\n        goto orig_flow;\n    }\n    return ret;\norig_flow:\n#endif' kernel/reboot.c

        if grep -q "ksu_handle_sys_reboot" "kernel/reboot.c"; then
            echo "[+] kernel/reboot.c Patched!"
            echo "[+] Count: $(grep -c "ksu_handle_sys_reboot" "kernel/reboot.c")"
        else
            echo "[-] kernel/reboot.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    ## sys.c
    kernel/sys.c)
        if grep -q "ksu_handle_setresuid" "drivers/kernelsu/setuid_hook.c" >/dev/null 2>&1; then

            if grep -q "__sys_setresuid" "kernel/sys.c" >/dev/null 2>&1; then
                sed -i '/^SYSCALL_DEFINE3(setresuid, uid_t, ruid, uid_t, euid, uid_t, suid)/i\#ifdef CONFIG_KSU\nextern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);\n#endif\n' kernel/sys.c
                sed -i '/return __sys_setresuid(ruid, euid, suid);/i\#ifdef CONFIG_KSU_SUSFS\n\tif (ksu_handle_setresuid(ruid, euid, suid)) {\n\t\tpr_info("Something wrong with ksu_handle_setresuid()\\\\n");\n\t}\n#endif\n' kernel/sys.c
            else
                sed -i '/^SYSCALL_DEFINE3(setresuid, uid_t, ruid, uid_t, euid, uid_t, suid)/i\#ifdef CONFIG_KSU\nextern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);\n#endif\n' kernel/sys.c
                sed -i '0,/\tif ((ruid != (uid_t) -1) && !uid_valid(kruid))/b; /\tif ((ruid != (uid_t) -1) && !uid_valid(kruid))/i\#ifdef CONFIG_KSU_SUSFS\n\tif (ksu_handle_setresuid(ruid, euid, suid)) {\n\t\tpr_info("Something wrong with ksu_handle_setresuid()\\\\n");\n\t}\n#endif' kernel/sys.c
            fi

            if grep -q "ksu_handle_setresuid" "kernel/sys.c"; then
                echo "[+] kernel/sys.c Patched!"
                echo "[+] Count: $(grep -c "ksu_handle_setresuid" "kernel/sys.c")"
            else
                echo "[-] kernel/sys.c patch failed for unknown reasons, please provide feedback in time."
            fi
        else
            echo "[-] KernelSU have no ksu_handle_setresuid, Skipped."
        fi

        echo "======================================"
        ;;
    esac

done
