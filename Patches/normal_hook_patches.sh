#!/bin/bash
# Patches author: weishu <twsxtd@gmail.com>
#                 F-19-F @ Github
#                 blackslahxx @ Github
# Shell authon: xiaoleGun <1592501605@qq.com>
#               bdqllW <bdqllT@gmail.com>
#               JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 3.18, 3.10, 3.4
# 20240123

patch_files=(
    fs/exec.c
    fs/open.c
    fs/read_write.c
    fs/stat.c
    fs/devpts/inode.c
    drivers/input/input.c
    security/selinux/hooks.c
)

KERNEL_VERSION=$(head -n 3 Makefile | grep -E 'VERSION|PATCHLEVEL' | awk '{print $3}' | paste -sd '.')
FIRST_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $1}')
SECOND_VERSION=$(echo "$KERNEL_VERSION" | awk -F '.' '{print $2}')

for i in "${patch_files[@]}"; do

    if grep -q "ksu" "$i"; then
        echo "Warning: $i contains KernelSU"
        continue
    fi

    case $i in

    # fs/ changes
    ## exec.c
    fs/exec.c)
        sed -i '/static int do_execveat_common/i\#ifdef CONFIG_KSU\nextern bool ksu_execveat_hook __read_mostly;\nextern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,\n			void *envp, int *flags);\nextern int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr,\n				 void *argv, void *envp, int *flags);\n#endif' fs/exec.c
        if grep -q "return __do_execve_file(fd, filename, argv, envp, flags, NULL);" fs/exec.c; then
            sed -i '/return __do_execve_file(fd, filename, argv, envp, flags, NULL);/i\	#ifdef CONFIG_KSU\n	if (unlikely(ksu_execveat_hook))\n		ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n	else\n		ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);\n	#endif' fs/exec.c
        else
            sed -i '/if (IS_ERR(filename))/i\	#ifdef CONFIG_KSU\n	if (unlikely(ksu_execveat_hook))\n		ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n	else\n		ksu_handle_execveat_sucompat(&fd, &filename, &argv, &envp, &flags);\n	#endif' fs/exec.c
        fi
        ;;

    ## open.c
    fs/open.c)
        if grep -q "long do_faccessat(int dfd, const char __user \*filename, int mode)" fs/open.c; then
            sed -i '/long do_faccessat(int dfd, const char __user \*filename, int mode)/i\#ifdef CONFIG_KSU\nextern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n			 int *flags);\n#endif' fs/open.c
        else
            sed -i '/SYSCALL_DEFINE3(faccessat, int, dfd, const char __user \*, filename, int, mode)/i\#ifdef CONFIG_KSU\nextern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode,\n			 int *flags);\n#endif' fs/open.c
        fi
        sed -i '/if (mode & ~S_IRWXO)/i\	#ifdef CONFIG_KSU\n	ksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n	#endif\n' fs/open.c
        ;;

    ## read_write.c
    fs/read_write.c)
        sed -i '/ssize_t vfs_read(struct file/i\#ifdef CONFIG_KSU\nextern bool ksu_vfs_read_hook __read_mostly;\nextern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr,\n		size_t *count_ptr, loff_t **pos);\n#endif' fs/read_write.c
        sed -i '/ssize_t vfs_read(struct file/,/ssize_t ret;/{/ssize_t ret;/a\
        #ifdef CONFIG_KSU\
        if (unlikely(ksu_vfs_read_hook))\
            ksu_handle_vfs_read(&file, &buf, &count, &pos);\
        #endif
        }' fs/read_write.c
        ;;

    ## stat.c
    fs/stat.c)
        if grep -q "int vfs_statx(int dfd, const char __user \*filename, int flags," fs/stat.c; then
            sed -i '/int vfs_statx(int dfd, const char __user \*filename, int flags,/i\#ifdef CONFIG_KSU\nextern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n#endif' fs/stat.c
            sed -i '/unsigned int lookup_flags = LOOKUP_FOLLOW | LOOKUP_AUTOMOUNT;/a\\n	#ifdef CONFIG_KSU\n	ksu_handle_stat(&dfd, &filename, &flags);\n	#endif' fs/stat.c
        else
            sed -i '/int vfs_fstatat(int dfd, const char __user \*filename, struct kstat \*stat,/i\#ifdef CONFIG_KSU\nextern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n#endif\n' fs/stat.c
            sed -i '/if ((flag & ~(AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT |/i\	#ifdef CONFIG_KSU\n	ksu_handle_stat(&dfd, &filename, &flag);\n	#endif\n' fs/stat.c
        fi
        ;;

    ## fs/devpts changes
    ### fs/devpts/inode.c
    fs/devpts/inode.c)
        if grep -q "void \*devpts_get_priv(struct dentry \*dentry)" fs/devpts/inode.c; then
            sed -i '/void \*devpts_get_priv(struct dentry \*dentry)/i\extern int ksu_handle_devpts(struct inode*);\n' fs/devpts/inode.c
            sed -i '/if (dentry->d_sb->s_magic != DEVPTS_SUPER_MAGIC)/i\    ksu_handle_devpts(dentry->d_inode);' fs/devpts/inode.c
        fi
        ;;

    # drivers/input changes
    ## input.c
    drivers/input/input.c)
        sed -i '/static void input_handle_event/i\#ifdef CONFIG_KSU\nextern bool ksu_input_hook __read_mostly;\nextern int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);\n#endif\n' drivers/input/input.c
        if grep -q "int disposition = input_get_disposition(dev, type, code, &value)" drivers/input/input.c; then
            sed -i '/int disposition = input_get_disposition(dev, type, code, &value);/a\	#ifdef CONFIG_KSU\n	if (unlikely(ksu_input_hook))\n		ksu_handle_input_handle_event(&type, &code, &value);\n	#endif' drivers/input/input.c
        else
            sed -i '/disposition = input_get_disposition(dev, type, code, \&value);/a\#ifdef CONFIG_KSU\n\tif (unlikely(ksu_input_hook))\n\t\tksu_handle_input_handle_event(\&type, \&code, \&value);\n#endif' drivers/input/input.c
        fi
        ;;

    # security/ changes
    ## security/selinux/hooks.c
    security/selinux/hooks.c)
        if [ "$FIRST_VERSION" -lt 4 ] && [ "$SECOND_VERSION" -lt 18 ]; then
            sed -i '/^static int selinux_bprm_set_creds(struct linux_binprm \*bprm)/i static int check_nnp_nosuid(const struct linux_binprm *bprm, struct task_security_struct *old_tsec, struct task_security_struct *new_tsec) {\n    int nnp = (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS);\n    int nosuid = (bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID);\n    int rc;\n\n    if (!nnp && !nosuid)\n        return 0;\n\n    if (new_tsec->sid == old_tsec->sid)\n        return 0;\n\n    rc = security_bounded_transition(old_tsec->sid, new_tsec->sid);\n    if (rc) {\n        if (nnp)\n            return -EPERM;\n        else\n            return -EACCES;\n    }\n    return 0;\n}\n' security/selinux/hooks.c
            sed -i '/if *(bprm->unsafe *& *LSM_UNSAFE_NO_NEW_PRIVS)/, /return *-EPERM;/c\ \t\trc = check_nnp_nosuid(bprm, old_tsec, new_tsec);\n\t\tif (rc)\n\t\t\treturn rc;' security/selinux/hooks.c
            awk '
                                                       BEGIN { insert = 0 }
                                                       /rc = security_transition_sid\(old_tsec->sid, isec->sid,/ { insert = 1 }
                                                       { print }
                                                       /return rc;/ {
                                                         if (insert) {
                                                           print "        rc = check_nnp_nosuid(bprm, old_tsec, new_tsec);"
                                                           print "        if (rc)"
                                                           print "            new_tsec->sid = old_tsec->sid;"
                                                           insert = 0
                                                         }
                                                       }
                                                       ' security/selinux/hooks.c > security/selinux/hooks.c.new && mv security/selinux/hooks.c.new security/selinux/hooks.c
            sed -i '/^\tif ((bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID) ||$/{
                                                       N
                                                       N
                                                       /^\tif ((bprm->file->f_path.mnt->mnt_flags & MNT_NOSUID) ||\n\t    (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS))\n\t\tnew_tsec->sid = old_tsec->sid;$/d
                                                       }' security/selinux/hooks.c
            sed -i '/if (!nnp && !nosuid)/i \#ifdef CONFIG_KSU\n\tstatic u32 ksu_sid;\n\tchar *secdata;\n\tint error;\n\tu32 seclen;\n#endif' security/selinux/hooks.c
            sed -i '/return 0; \/\* No change in credentials \*\//a\\n    if (!ksu_sid)\n        security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);\n\n    error = security_secid_to_secctx(old_tsec->sid, &secdata, &seclen);\n    if (!error) {\n        rc = strcmp("u:r:init:s0", secdata);\n        security_release_secctx(secdata, seclen);\n        if (rc == 0 && new_tsec->sid == ksu_sid)\n            return 0;\n    }' security/selinux/hooks.c
        elif [ "$FIRST_VERSION" -lt 5 ] && [ "$SECOND_VERSION" -lt 10 ]; then
            sed -i '/int nnp = (bprm->unsafe & LSM_UNSAFE_NO_NEW_PRIVS);/i\    static u32 ksu_sid;\n    char *secdata;' security/selinux/hooks.c
            sed -i '/if (!nnp && !nosuid)/i\    int error;\n    u32 seclen;\n' security/selinux/hooks.c
            sed -i '/return 0; \/\* No change in credentials \*\//a\\n    if (!ksu_sid)\n        security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);\n\n    error = security_secid_to_secctx(old_tsec->sid, &secdata, &seclen);\n    if (!error) {\n        rc = strcmp("u:r:init:s0", secdata);\n        security_release_secctx(secdata, seclen);\n        if (rc == 0 && new_tsec->sid == ksu_sid)\n            return 0;\n    }' security/selinux/hooks.c
        fi
        ;;
    esac

done
