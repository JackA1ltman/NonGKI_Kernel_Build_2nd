#!/usr/bin/env bash
# Patches author: ShirkNeko @ Github
#                 backslashxx @ Github
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18
# 20250821

patch_files=(
    fs/exec.c
    fs/open.c
    fs/read_write.c
    fs/stat.c
    drivers/input/input.c
    drivers/tty/pty.c
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
        sed -i '/#include <trace\/events\/sched.h>/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' fs/exec.c
        if grep -q "do_execveat_common" fs/exec.c; then
            awk '
/return do_execveat_common\(AT_FDCWD, filename, argv, envp, 0\);/ {
    count++;
    if (count == 1) {
        print "#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)";
        print "\ttrace_ksu_trace_execveat_hook((int *)AT_FDCWD, &filename, &argv, &envp, 0);";
        print "#endif";
    } else if (count == 2) {
        print "#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)";
        print "\ttrace_ksu_trace_execveat_sucompat_hook((int *)AT_FDCWD, &filename, NULL, NULL, NULL); /* 32-bit su */";
        print "#endif";
    }
}
{
    print;
}
' fs/exec.c > fs/exec.c.new
            mv fs/exec.c.new fs/exec.c
        else
awk '
/return do_execve_common\(filename, argv, envp\);/ {
    count++;
    if (count == 1) {
        print "#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)";
        print "\ttrace_ksu_trace_execveat_hook((int *)AT_FDCWD, &filename, &argv, &envp, 0);";
        print "#endif";
    } else if (count == 2) {
        print "#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)";
        print "\ttrace_ksu_trace_execveat_sucompat_hook((int *)AT_FDCWD, &filename, NULL, NULL, NULL); /* 32-bit su */";
        print "#endif";
    }
}
{
    print;
}
' fs/exec.c > fs/exec.c.new
            mv fs/exec.c.new fs/exec.c
        fi
        ;;

    ## open.c
    fs/open.c)
        sed -i '/#include "internal.h"/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' fs/open.c
        sed -i '/if (mode & ~S_IRWXO)/i \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n\ttrace_ksu_trace_faccessat_hook(&dfd, &filename, &mode, NULL);\n#endif' fs/open.c
        ;;

    ## read_write.c
    fs/read_write.c)
        sed -i '/#include <asm\/unistd.h>/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' fs/read_write.c
        sed -i '0,/ret = vfs_read(f.file, buf, count, &pos);/ { /ret = vfs_read(f.file, buf, count, &pos);/i \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n\ttrace_ksu_trace_sys_read_hook(fd, &buf, &count);\n#endif
                                           }' fs/read_write.c
        ;;

    ## stat.c
    fs/stat.c)
        sed -i '/#include <asm\/unistd.h>/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' fs/stat.c
        awk '
/error = vfs_fstatat\(dfd, filename, &stat, flag\);/ {
    count++;
    if (count <= 2) {
        print "#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)";
        print "\ttrace_ksu_trace_stat_hook(&dfd, &filename, &flag);";
        print "#endif";
    }
}
{
    print;
}
' fs/stat.c > fs/stat.c.new
        mv fs/stat.c.new fs/stat.c
        ;;

    # drivers
    ## input/input.c
    drivers/input/input.c)
        sed -i '/#include "input-compat.h"/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' drivers/input/input.c
        sed -i '0,/if (is_event_supported(type, dev->evbit, EV_MAX)) {/ { /if (is_event_supported(type, dev->evbit, EV_MAX)) {/i \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n\ttrace_ksu_trace_input_hook(&type, &code, &value);\n#endif
                                           }' drivers/input/input.c
        ;;

    ## pty/pty.c
    drivers/tty/pty.c)
        if [ "$FIRST_VERSION" -lt 5 ] && [ "$SECOND_VERSION" -lt 10 ]; then
            sed -i '/#include <linux\/poll.h>/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' drivers/tty/pty.c
        else
            sed -i '/#include <linux\/compat.h>/a \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n#include <..\/..\/drivers\/kernelsu\/ksu_trace.h>\n#endif' drivers/tty/pty.c
        fi

        sed -i '/mutex_lock(&devpts_mutex);/ {
                                               N
                                               /\n[[:space:]]*tty = devpts_get_priv(file->f_path.dentry);/ {
                                                   i \#if defined(CONFIG_KSU) && defined(CONFIG_KSU_TRACEPOINT_HOOK)\n\t\ttrace_ksu_trace_devpts_hook((struct inode \*)file->f_path.dentry->d_inode);\n#endif
                                               }
                                           }' drivers/tty/pty.c
        ;;

    # security/ changes
    ## selinux/hooks.c
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

    esac

done
