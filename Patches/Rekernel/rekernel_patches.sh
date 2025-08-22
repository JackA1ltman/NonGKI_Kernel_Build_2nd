#!/usr/bin/env bash
# Patches author: Sakion-Team @ Github
# Shell author: JackA1ltman <cs2dtzq@163.com>
# Tested kernel versions: 5.4, 4.19, 4.14, 4.9, 4.4, 3.18
# 20250822
patch_files=(
    drivers/android/binder.c
    drivers/android/binder_alloc.c
    kernel/signal.c
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
    ## android/binder.c
    drivers/android/binder.c)
        sed -i '/#include <linux\/spinlock.h>/a /* REKERNEL */\n#include <../rekernel/rekernel.h>\n/* REKERNEL */' drivers/android/binder.c
        awk '
NR==FNR {
    if (/binder_inner_proc_unlock\(target_thread->proc\);/) {
        last_match_line = FNR
    }
    next
}
{
    print
}
FNR == last_match_line {
    print "/* REKERNEL */";
    print "\t\tif (start_rekernel_server() == 0) {";
    print "\t\t\tif (target_proc";
    print "\t\t\t\t&& (NULL != target_proc->tsk)";
    print "\t\t\t\t&& (NULL != proc->tsk)";
    print "\t\t\t\t&& (task_uid(target_proc->tsk).val <= MAX_SYSTEM_UID)";
    print "\t\t\t\t&& (proc->pid != target_proc->pid)";
    print "\t\t\t\t&& line_is_frozen(target_proc->tsk)) {";
    print "     \t\t\t\tchar binder_kmsg[PACKET_SIZE];";
    print "\t\t\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), \"type=Binder,bindertype=reply,oneway=0,from_pid=%d,from=%d,target_pid=%d,target=%d;\", proc->pid, task_uid(proc->tsk).val, target_proc->pid, task_uid(target_proc->tsk).val);";
    print "         \t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));";
    print "\t\t\t}";
    print "   \t\t}";
    print "/* REKERNEL */"
}
' drivers/android/binder.c drivers/android/binder.c > drivers/android/binder.c.new
        mv drivers/android/binder.c.new drivers/android/binder.c
        sed -i '/e->to_node = target_node->debug_id;/a /* REKERNEL */\n\t\tif (start_rekernel_server() == 0) {\n\t\t\tif (target_proc\n\t\t\t\t&& (NULL != target_proc->tsk)\n\t\t\t\t&& (NULL != proc->tsk)\n\t\t\t\t&& (task_uid(target_proc->tsk).val > MIN_USERAPP_UID)\n\t\t\t\t&& (proc->pid != target_proc->pid)\n\t\t\t\t&& line_is_frozen(target_proc->tsk)) {\n\t \t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), \"type=Binder,bindertype=transaction,oneway=%d,from_pid=%d,from=%d,target_pid=%d,target=%d;\", tr->flags & TF_ONE_WAY, proc->pid, task_uid(proc->tsk).val, target_proc->pid, task_uid(target_proc->tsk).val);\n\t \t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t\t}\n\t\t}\n/* REKERNEL */' drivers/android/binder.c
        ;;

    ## android/binder_alloc.c
    drivers/android/binder_alloc.c)
        sed -i '/#include <linux\/highmem.h>/a /* REKERNEL */\n#include <../rekernel/rekernel.h>\n/* REKERNEL */' drivers/android/binder_alloc.c
        awk '
/struct rb_node \*n = alloc->free_buffers.rb_node;/ {
    count++;
    if (count == 2) {
        print "/* REKERNEL */";
        print "\tstruct task_struct *proc_task = NULL;";
        print "/* REKERNEL */";
    }
}
{
    print;
}
' drivers/android/binder_alloc.c > drivers/android/binder_alloc.c.new
        mv drivers/android/binder_alloc.c.new drivers/android/binder_alloc.c
        sed -i '/if (is_async &&/i/* REKERNEL */\n\tif (is_async\n\t\t&& (alloc->free_async_space < 3 * (size + sizeof(struct binder_buffer))\n\t\t|| (alloc->free_async_space < WARN_AHEAD_SPACE))) {\n\t\trcu_read_lock();\n\t\tproc_task = find_task_by_vpid(alloc->pid);\n\t\trcu_read_unlock();\n\t\tif (proc_task != NULL && start_rekernel_server() == 0) {\n\t\t\tif (line_is_frozen(proc_task)) {\n\t \t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), \"type=Binder,bindertype=free_buffer_full,oneway=1,from_pid=%d,from=%d,target_pid=%d,target=%d;\", current->pid, task_uid(current).val, proc_task->pid, task_uid(proc_task).val);\n\t \t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t\t}\n\t\t}\n\t}\n/* REKERNEL */' drivers/android/binder_alloc.c
        ;;

    # kernel
    ## signal.c
    kernel/signal.c)
        sed -i '/#include <asm\/cacheflush.h>/a /* REKERNEL */\n#include <../drivers/rekernel/rekernel.h>\n/* REKERNEL */' kernel/signal.c
        sed -i '/int ret = -ESRCH;/a /* REKERNEL */\n\tif (start_rekernel_server() == 0) {\n\t\tif (line_is_frozen(current) && (sig == SIGKILL || sig == SIGTERM || sig == SIGABRT || sig == SIGQUIT)) {\n\t \t\t\tchar binder_kmsg[PACKET_SIZE];\n\t\t\tsnprintf(binder_kmsg, sizeof(binder_kmsg), \"type=Signal,signal=%d,killer_pid=%d,killer=%d,dst_pid=%d,dst=%d;\", sig, task_tgid_nr(p), task_uid(p).val, task_tgid_nr(current), task_uid(current).val);\n\t \t\t\tsend_netlink_message(binder_kmsg, strlen(binder_kmsg));\n\t\t}\n\t}\n/* REKERNEL */' kernel/signal.c
        ;;
    esac

done
