@extern(embed)
package main

_fact: _ @embed(file="tmp/fact.json")

snapper_configs: [
	for disk in _fact.disks.storage.disks_list {
		path: "\(_fact.global_disks_storage_path)/\(disk)"
		name: disk
		vars: {
			ALLOW_USERS:      _fact.ansible_env.USER
			ALLOW_GROUPS:     _fact.ansible_env.USER
			SYNC_ACL:         true
			TIMELINE_CREATE:  false
			TIMELINE_CLEANUP: false
		}
	},
] + [{
	path: "/home"
	name: "home"
	vars: {
		ALLOW_USERS:            _fact.ansible_env.USER
		ALLOW_GROUPS:           _fact.ansible_env.USER
		SYNC_ACL:               true
		TIMELINE_LIMIT_HOURLY:  "6"
		TIMELINE_LIMIT_DAILY:   "7"
		TIMELINE_LIMIT_WEEKLY:  "0"
		TIMELINE_LIMIT_MONTHLY: "0"
		TIMELINE_LIMIT_YEARLY:  "0"
	}
}]
