@@
@@

static int cgroup_add_file(...){
...
    if (cft->file_offset) {
        ...
		spin_unlock_irq(&cgroup_file_kn_lock);
    }

+	if (cft->ss && (cgrp->root->flags & CGRP_ROOT_NOPREFIX) && !(cft->flags & CFTYPE_NO_PREFIX)) {
+		snprintf(name, CGROUP_FILE_NAME_MAX, "%s.%s", cft->ss->name, cft->name);
+		kernfs_create_link(cgrp->kn, name, kn);
+	}
    return 0;
}
