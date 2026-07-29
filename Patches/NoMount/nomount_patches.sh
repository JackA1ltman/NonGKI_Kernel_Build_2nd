#!/bin/bash
# Patches author: maxsteeel @ Github
# Shell authon: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9
# 20260729

patch_files=(
    fs/dcache.c
    fs/Kconfig
    fs/Makefile
    fs/namei.c
    fs/proc/task_mmu.c
    fs/readdir.c
    fs/stat.c
    fs/statfs.c
)

for i in "${patch_files[@]}"; do

    if grep -q "NOMOUNT" "$i"; then
        echo "[-] Warning: $i contains NoMount"
        echo "[+] Code in here:"
        grep -n "NOMOUNT" "$i"
        echo "[-] End of file."
        echo "======================================"
        continue
    fi

    case $i in

    # fs/ changes
    ## fs/dcache.c
    fs/dcache.c)
        echo "======================================"

        sed -i '/char \*__d_path(const struct path \*path,/i\#ifdef CONFIG_NOMOUNT\nextern char *nomount_handle_dpath(const struct path *path, char *buf, int buflen);\n#endif\n' fs/dcache.c
        sed -i '/if (path->dentry->d_op && path->dentry->d_op->d_dname &&/i\#ifdef CONFIG_NOMOUNT\n\tchar *nm_path = nomount_handle_dpath(path, buf, buflen);\n\tif (unlikely(nm_path)) {\n\t\treturn nm_path;\n\t}\n#endif\n' fs/dcache.c

        if grep -q "nomount_handle_dpath" "fs/dcache.c"; then
            echo "[+] fs/dcache.c Patched!"
            echo "[+] Count: $(grep -c "nomount_handle_dpath" "fs/dcache.c")"
        else
            echo "[-] fs/dcache.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/Kconfig
    fs/Kconfig)
        sed -i ':a;N;$!ba;s/\(.*\)\nendmenu/\1\nconfig NOMOUNT\n\tbool "NoMount Path Redirection Subsystem"\n\tdefault y\n\thelp\n\t  NoMount allows path redirection and virtual file injection\n\t  without mounting filesystems. Useful for systemless modifications.\nendmenu/' fs/Kconfig

        if grep -q "NOMOUNT" "fs/Kconfig"; then
            echo "[+] fs/Kconfig Patched!"
            echo "[+] Count: $(grep -c "NOMOUNT" "fs/Kconfig")"
        else
            echo "[-] fs/Kconfig patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/Makefile
    fs/Makefile)
        sed -i '/obj-$(CONFIG_PROC_FS) += proc_namespace.o/i\obj-$(CONFIG_NOMOUNT) += nomount.o' fs/Makefile

        if grep -q "NOMOUNT" "fs/Makefile"; then
            echo "[+] fs/Makefile Patched!"
            echo "[+] Count: $(grep -c "NOMOUNT" "fs/Makefile")"
        else
            echo "[-] fs/Makefile patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/namei.c
    fs/namei.c)
        sed -i $'/^[[:space:]]*#define EMBEDDED_NAME_MAX/a\\\n#ifdef CONFIG_NOMOUNT\\\nextern struct filename *nomount_handle_getname(struct filename *name);\\\nextern int nomount_handle_permission(struct inode *inode, int mask);\\\n#endif/' fs/namei.c
        sed -i $'/audit_getname(result);/i\\\n#ifdef CONFIG_NOMOUNT\\\n\tif (!IS_ERR(result)) {\\\n\t\tresult = nomount_handle_getname(result);\\\n\t}\\\n#endif' fs/namei.c
        sed -i $'/^[[:space:]]*ret = acl_permission_check(inode, mask);/i\\\n#ifdef CONFIG_NOMOUNT\\\n\tint nm_perm = nomount_handle_permission(inode, mask);\\\n\tif (unlikely(nm_perm < 0)) return nm_perm;\\\n\tif (unlikely(nm_perm > 0)) return 0;\\\n#endif' fs/namei.c

        if grep -q "return __inode_permission2" "fs/namei.c"; then
            sed -i '0,/^[[:space:]]*if (unlikely(mask & MAY_WRITE)) {/s/^[[:space:]]*if (unlikely(mask & MAY_WRITE)) {/#ifdef CONFIG_NOMOUNT\n\tint nm_perm = nomount_handle_permission(inode, mask);\n\tif (unlikely(nm_perm < 0)) return nm_perm;\n\tif (unlikely(nm_perm > 0)) return 0;\n#endif\n&/' fs/namei.c

        else
            sed -i $'/^[[:space:]]*retval = sb_permission(inode->i_sb, inode, mask);/i\\\n#ifdef CONFIG_NOMOUNT\\\n\tint nm_perm = nomount_handle_permission(inode, mask);\\\n\tif (unlikely(nm_perm < 0)) return nm_perm;\\\n\tif (unlikely(nm_perm > 0)) return 0;\\\n#endif' fs/namei.c

        fi

        if grep -q "nomount_handle_getname" "fs/namei.c"; then
            echo "[+] fs/namei.c Patched!"
            echo "[+] Count: $(grep -c "nomount_handle_getname" "fs/namei.c")"
        else
            echo "[-] fs/namei.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/proc/task_mmu.c
    fs/proc/task_mmu.c)
        sed -i '/^static void$/{N;/show_map_vma(struct seq_file \*m, struct vm_area_struct \*vma, int is_pid)/i\#ifdef CONFIG_NOMOUNT\nextern bool nomount_spoof_mmap_metadata(struct inode *inode, dev_t *dev, unsigned long *ino);\n#endif\n
}' fs/proc/task_mmu.c
        sed -i '/pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;/i\#ifdef CONFIG_NOMOUNT\n\t\tnomount_spoof_mmap_metadata(inode, \&dev, \&ino);\n#endif\n' fs/proc/task_mmu.c

        if grep -q "nomount_spoof_mmap_metadata" "fs/proc/task_mmu.c"; then
            echo "[+] fs/proc/task_mmu.c Patched!"
            echo "[+] Count: $(grep -c "nomount_spoof_mmap_metadata" "fs/proc/task_mmu.c")"
        else
            echo "[-] fs/proc/task_mmu.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/readdir.c
    fs/readdir.c)
        sed -i '/int iterate_dir(struct file \*file, struct dir_context \*ctx)/i\#ifdef CONFIG_NOMOUNT\nextern int nomount_handle_iterate_dir(struct file *file, struct dir_context *ctx);\n#endif\n' fs/readdir.c
        sed -i '/pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;/i\#ifdef CONFIG_NOMOUNT\n\t\tnomount_spoof_mmap_metadata(inode, \&dev, \&ino);\n#endif\n' fs/readdir.c
        sed -i '/ctx->pos = file->f_pos;/a\#ifdef CONFIG_NOMOUNT\n\t\tres = nomount_handle_iterate_dir(file, ctx);\n#else' fs/readdir.c
        sed -i '/file->f_pos = ctx->pos;/i\#endif' fs/readdir.c

        if grep -q "nomount_handle_iterate_dir" "fs/readdir.c"; then
            echo "[+] fs/readdir.c Patched!"
            echo "[+] Count: $(grep -c "nomount_handle_iterate_dir" "fs/readdir.c")"
        else
            echo "[-] fs/readdir.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/stat.c
    fs/stat.c)
        if grep -q "@request_mask" "fs/stat.c"; then
            sed -i '/int vfs_getattr(const struct path \*path, struct kstat \*stat,/i\#ifdef CONFIG_NOMOUNT\nextern int nomount_handle_getattr(int ret, const struct path *path, struct kstat *stat);\n#endif\n' fs/stat.c
            sed -i '/return vfs_getattr_nosec(path, stat, request_mask, query_flags);/i\#ifdef CONFIG_NOMOUNT\n    return nomount_handle_getattr(vfs_getattr_nosec(path, stat, request_mask, query_flags), path, stat);\n#else' fs/stat.c
            sed -i '/return vfs_getattr_nosec(path, stat, request_mask, query_flags);/a\#endif' fs/stat.c

        else
            sed -i '/int vfs_getattr(struct path \*path, struct kstat \*stat)/i\#ifdef CONFIG_NOMOUNT\nextern int nomount_handle_getattr(int ret, const struct path *path, struct kstat *stat);\n#endif\n' fs/stat.c
            sed -i '/return vfs_getattr_nosec(path, stat);/i\#ifdef CONFIG_NOMOUNT\n\treturn nomount_handle_getattr(vfs_getattr_nosec(path, stat), path, stat);\n#else' fs/stat.c
            sed -i '/return vfs_getattr_nosec(path, stat);/a\#endif' fs/stat.c

        fi

        if grep -q "nomount_handle_getattr" "fs/stat.c"; then
            echo "[+] fs/stat.c Patched!"
            echo "[+] Count: $(grep -c "nomount_handle_getattr" "fs/stat.c")"
        else
            echo "[-] fs/stat.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;

    ## fs/statfs.c
    fs/statfs.c)
        sed -i '/static int flags_by_mnt(int mnt_flags)/i\#ifdef CONFIG_NOMOUNT\nextern void nomount_spoof_statfs(const struct path *path, struct kstatfs *buf);\n#endif\n' fs/statfs.c
        sed -i '/buf->f_flags = calculate_f_flags(path->mnt);/a\#ifdef CONFIG_NOMOUNT\n\tnomount_spoof_statfs(path, buf);\n#endif\n' fs/statfs.c

        if grep -q "nomount_spoof_statfs" "fs/statfs.c"; then
            echo "[+] fs/statfs.c Patched!"
            echo "[+] Count: $(grep -c "nomount_spoof_statfs" "fs/statfs.c")"
        else
            echo "[-] fs/statfs.c patch failed for unknown reasons, please provide feedback in time."
        fi

        echo "======================================"
        ;;
    esac

done
