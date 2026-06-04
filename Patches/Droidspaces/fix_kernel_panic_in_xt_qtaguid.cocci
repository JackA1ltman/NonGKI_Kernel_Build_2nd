@remove_dev_stats@
@@
static int iface_stat_fmt_proc_show(struct seq_file *m, void *v)
{
    ...
-	struct rtnl_link_stats64 dev_stats;
    ...
}

@@
@@
static int iface_stat_fmt_proc_show(struct seq_file *m, void *v)
{
    ...
-	if (iface_entry->active) {
-		stats = dev_get_stats(iface_entry->net_dev,
-				      &dev_stats);
-	} else {
-		stats = &no_dev_stats;
-	}
+	stats = &no_dev_stats;
    ...
}
