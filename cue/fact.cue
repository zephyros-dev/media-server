@extern(embed)
package main

import (
	"encoding/json"
	"encoding/yaml"
	"strings"
	"path"
	core "k8s.io/api/core/v1"
)

_fact_embed: _ @embed(file="tmp/fact.json")
// Type check for fact
_fact: _fact_embed & {
	disks: {
		storage?: {
			fs_type: string | *"btrfs"
			disks_list: [...string]
		}
		parity?: {
			fs_type: string | *"ext4"
			disks_list: [...string]
		}
	}

	//  Root volume folder
	global_volume_path: string
	// Media folder, shared among Jellyfin, Pymedusa, Radarr, bazarr for hardlink
	global_media: string
	// Global folder for manual download file
	global_download: string
}

_profile: {
	lsio: {
		metadata: annotations: "io.podman.annotations.userns": "keep-id:uid=911,gid=911"
		spec: containers: [...{
			securityContext: {
				runAsUser:  0
				runAsGroup: 0
			}
		}]
	}
	rootless: spec: containers: [...{
		securityContext: {
			runAsUser:  _fact.ansible_user_uid
			runAsGroup: _fact.ansible_user_gid
		}
	}]
	userns_share: metadata: annotations: "io.podman.annotations.userns": "keep-id"
	rootless_userns: rootless & userns_share
}

application: [applicationName=string]: {
	param: {
		become:            *false | bool
		caddy_proxy_port?: int32
		caddy_proxy_url?:  string
		caddy_rewrite?: [...{
			src:  string
			dest: string
		}]
		caddy_sso:                     *false | bool
		dashy_icon?:                   string
		dashy_show:                    *true | bool // Show service endpoint in dashy
		dashy_statusCheckAcceptCodes?: int32 | >99 | <600
		host_network:                  *false | bool
		kind:                          *"kube" | "container"
		quadlet_kube_options?: {
			[string]: string
		}
		quadlet_build_options?: {
			[string]: string
		}
		postgres_action: *"none" | "export" | "import" | "clean"
		preserve_volume: *true | bool
		state:           *"started" | "absent"
		volumes?: {
			[string]: string
		}
		secret?: {
			[string]: {
				type:    "file" | "env"
				content: string
			}
		}
	}

	transform: {
		volumes: [string]: {
			type:  "pvc" | "file" | "absolutePathDir" | "relativePathDir"
			value: string
		}
		volumes: {
			if param.volumes != _|_
			for k, v in param.volumes {"\(k)": {
				_volume_path: path.Join([_fact.global_volume_path, applicationName, path.Clean(v)])
				if v == "pvc" {
					type:  "pvc"
					value: "\(applicationName)-\(k)"
				}
				if v =~ "\/.+[^\/]$" {
					type: "file"
					if path.IsAbs(v) {
						value: v
					}
					if v =~ "^\\.\/" {
						value: _volume_path
					}
				}
				if path.IsAbs(v) {
					type:  "absolutePathDir"
					value: path.Clean(v)
				}
				if v =~ "^\\.\/.+\/$" || v == "./" {
					type:  "relativePathDir"
					value: _volume_path
				}
			}}
		}
	}

	#pod: *null | core.#Pod & {
		apiVersion: "v1"
		kind:       "Pod"
		metadata: {
			annotations: "io.podman.annotations.infra.name": "\(applicationName)-pod"
			name: applicationName
		}
		spec: {
			volumes: [for k, v in transform.volumes {
				name: k
				if v.type == "pvc" {
					persistentVolumeClaim: claimName: v.value
				}
				if v.type == "file" {
					hostPath: {
						path: v.value
						type: "File"
					}
				}
				if v.type == "absolutePathDir" || v.type == "relativePathDir" {
					hostPath: {
						path: v.value
						type: "Directory"
					}
				}
			}] + [
				if param.secret != _|_
				for k, v in param.secret if v.type == "file" {
					name: k
					secret: {
						secretName: applicationName
						items: [{
							key:  k
							path: k
						}]
					}
				}]
		}
	}

	// Waiting for the function to check existence and concrete value
	// https://github.com/cue-lang/cue/issues/943

	#secret: [
		if param.secret != _|_ {
			core.#Secret & {
				apiVersion: "v1"
				kind:       "Secret"
				metadata: {
					name: applicationName
				}
				type: "Opaque"
				stringData: {
					for k, v in param.secret if v.type == "file" {
						"\(k)": v.content
					}
				} & {
					for k, v in param.secret if v.type == "env" {
						"\(k)": v.content
					}
				}
			}
		},
	]

	#volume: [
		for k, v in transform.volumes if v.type == "pvc" {
			core.#PersistentVolumeClaim & {
				apiVersion: "v1"
				kind:       "PersistentVolumeClaim"
				metadata: {
					name: "\(applicationName)-\(k)"
				}
			}
		}]

	// Have to use MarshalStream since cue export does not make stream yaml
	manifest: yaml.MarshalStream([#pod] + #secret + #volume)
}

application: {
	audiobookshelf: {
		_
		param: {
			caddy_proxy_port: 80
			volumes: {
				audiobooks: "\(_fact.global_storage)/Audiobooks/"
				config:     "./config/"
				metadata:   "./metadata/"
				podcasts:   "\(_fact.global_storage)/Podcasts/"
			}
		}
		#pod: _profile.rootless_userns & {
			spec: containers: [{
				name:  "web"
				image: "audiobookshelf"
				securityContext: capabilities: add: ["CAP_NET_BIND_SERVICE"]
				volumeMounts: [{
					name:      "audiobooks"
					mountPath: "/audiobooks"
				}, {
					name:      "config"
					mountPath: "/config:z"
				}, {
					name:      "metadata"
					mountPath: "/metadata:z"
				}, {
					name:      "podcasts"
					mountPath: "/podcasts"
				}]
			}]
		}
	}

	bazarr: {
		_
		param: {
			caddy_proxy_port: 6767
			caddy_sso:        true
			volumes: {
				config: "./web/config/"
				home:   "\(_fact.global_media)/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "bazarr"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}, {
					name:      "home"
					mountPath: "/home"
				}]
			}]
		}
	}

	caddy: {
		_
		param: {
			preserve_volume: true
			volumes: {
				config: "pvc"
				data:   "pvc"
			}
			secret: {
				Caddyfile: {
					type:    "file"
					content: _fact.caddyfile_content
				}
			}
		}
		#pod: _profile.rootless & {
			spec: containers: [{
				name:  "instance"
				image: "caddy"
				securityContext: capabilities: add: ["CAP_NET_BIND_SERVICE"]
				ports: [{
					containerPort: 80
					hostPort:      80
				}, {
					containerPort: 443
					hostPort:      443
				}, {
					containerPort: 443
					hostPort:      443
					protocol:      "UDP"
				}]
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:U"
				}, {
					name:      "data"
					mountPath: "/data:U"
				}, {
					name:      "Caddyfile"
					readOnly:  true
					mountPath: "/etc/caddy/Caddyfile"
					subPath:   "Caddyfile"
				}]
			}]
		}
	}

	calibre_content: {
		_
		param: {
			caddy_proxy_url:              "http://calibre:8081"
			dashy_icon:                   "/favicon.png"
			dashy_statusCheckAcceptCodes: 401
		}
	}

	calibre: {
		_
		param: {
			caddy_proxy_port:             8080
			caddy_sso:                    true
			dashy_statusCheckAcceptCodes: 401
			volumes: {
				books:  "\(_fact.global_media)/Storage/Books/"
				config: "./config/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "calibre"
				ports: [{
					// Used for the calibre wireless device connection
					containerPort: 9090
					hostPort:      59090
				}]
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}, {
					name:      "books"
					mountPath: "/books"
				}]
			}]
		}
	}

	cockpit: {
		_
		param: {
			caddy_proxy_url: "https://\(_fact.caddyfile_host_address):9090"
		}
	}

	// Already set to run as rootless in image build
	dashy: {
		_
		param: {
			caddy_proxy_port: 8080
			caddy_sso:        true
			dashy_show:       false
			secret: {
				"conf.yml": {
					type: "file"
					content: yaml.Marshal({
						appConfig: {
							iconSize:    "large"
							layout:      "vertical"
							statusCheck: true
							theme:       "Material"
						}
						sections: [{
							name: "All"
							items: [
								for k, v in application
								if v.param.dashy_show {
									_url_key:    strings.Replace(k, "_", "-", -1)
									_url_public: string | *"https://\(_url_key).\(_fact.server_domain)"
									if v.param.state == "started" {
										title: strings.ToTitle(_url_key)
										if v.param.dashy_icon == _|_ {
											icon: "hl-\(_url_key)"
										}
										if v.param.dashy_icon != _|_ {
											if strings.HasPrefix(v.param.dashy_icon, "/") {
												icon: "https://\(_url_key).\(_fact.server_domain)\(v.param.dashy_icon)"
											}
											if !strings.HasPrefix(v.param.dashy_icon, "/") {
												icon: v.param.dashy_icon
											}
										}
										if v.param.caddy_sso {
											statusCheckAllowInsecure: true
											if v.param.caddy_proxy_port != _|_ {
												if v.param.host_network {
													statusCheckUrl: "http://\(_fact.caddyfile_host_address):\(v.param.caddy_proxy_port)"
												}
												if !v.param.host_network {
													statusCheckUrl: "http://\(_url_key):\(v.param.caddy_proxy_port)"
												}
											}
											if v.param.caddy_proxy_url != _|_ {
												statusCheckUrl: v.param.caddy_proxy_url
											}
										}
										if !v.param.caddy_sso {
											statusCheckUrl: _url_public
										}
										if v.param.dashy_statusCheckAcceptCodes != _|_ {
											statusCheckAcceptCodes: v.param.dashy_statusCheckAcceptCodes
										}
										url: _url_public
									}
								},
							]
						}]
					})
				}
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "dashy"
			volumeMounts: [{
				name:      "conf.yml"
				readOnly:  true
				mountPath: "/app/user-data/conf.yml"
				subPath:   "conf.yml"
			}]
		}]
	}

	ddns: {
		_
		param: {
			preserve_volume: true
			quadlet_kube_options: Network: "pasta" // Use pasta network instead of host since it can preserve the IP address from the host machine
			volumes: {
				config: "pvc"
				data:   "pvc"
			}
			secret: {
				Caddyfile: {
					type:    "file"
					content: """
					{
						dynamic_dns {
							provider dynv6 \(_fact.ddns_dynv6_token)
							domains {
								\(_fact.dynv6_zone) *.\(_fact.server_subdomain)
							}
						}
					}
					"""
				}
			}
		}

		// ddns has to be ran separately since caddy is ran inside a podman network, so it does not have the IP address of the host
		#pod: _profile.rootless & {
			spec: containers: [{
				name:  "instance"
				image: "ddns"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:U"
				}, {
					name:      "data"
					mountPath: "/data:U"
				}, {
					name:      "Caddyfile"
					readOnly:  true
					mountPath: "/etc/caddy/Caddyfile"
					subPath:   "Caddyfile"
				}]
			}]
		}
	}

	filebrowser: {
		_
		param: {
			caddy_proxy_port: 80
			volumes: {
				"database.db": "./database.db"
				srv:           "\(_fact.global_media)/"
			}
		}
		#pod: _profile.rootless_userns & {
			spec: containers: [{
				name:  "web"
				image: "filebrowser"
				securityContext: capabilities: add: ["CAP_NET_BIND_SERVICE"]
				volumeMounts: [{
					name:      "srv"
					mountPath: "/srv"
				}, {
					name:      "database.db"
					mountPath: "/database.db:z"
				}]
			}]}
	}

	flaresolverr: {
		_
		#pod: _profile.rootless & {
			spec: containers: [{
				name:  "web"
				image: "flaresolverr"
			}]
		}
	}

	immich: {
		_
		param: {
			caddy_proxy_port: 3001
			volumes: {
				database:   "./database/"
				"ml-cache": "pvc"
				redis:      "pvc"
				upload:     "\(_fact.global_media)/Storage/Picture/Immich/"
			}
			secret: {
				database_password: {
					type:    "env"
					content: _fact.immich_database_password
				}
				jwt_secret: {
					type:    "env"
					content: _fact.immich_jwt_secret
				}
			}
		}

		#pod: _profile.rootless_userns & {
			spec: containers: [{
				name:  "postgres"
				image: "immich-postgres"
				env: [{
					name:  "POSTGRES_DB"
					value: "immich"
				}, {
					name:  "POSTGRES_USER"
					value: "immich"
				}, {
					name: "POSTGRES_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "immich"
						key:  "database_password"
					}
				}]
				volumeMounts: [{
					name:      "database"
					mountPath: "/var/lib/postgresql/data:U,z"
				}]
			}] + [if param.postgres_action == "none" for v in [{
				name:  "redis"
				image: "immich-redis"
				volumeMounts: [{
					name:      "redis"
					mountPath: "/data:U"
				}]
			}, {
				name:  "server"
				image: "immich-server"
				args: ["start.sh", "immich"]
				env: [{
					name:  "DB_DATABASE_NAME"
					value: "immich"
				}, {
					name:  "DB_HOSTNAME"
					value: "localhost"
				}, {
					name:  "DB_USERNAME"
					value: "immich"
				}, {
					name:  "NODE_ENV"
					value: "production"
				}, {
					name:  "REDIS_HOSTNAME"
					value: "localhost"
				}, {
					name: "JWT_SECRET"
					valueFrom: secretKeyRef: {
						name: "immich"
						key:  "jwt_secret"
					}
				}, {
					name: "DB_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "immich"
						key:  "database_password"
					}
				}]
				volumeMounts: [{
					name:      "upload"
					mountPath: "/usr/src/app/upload"
				}]
			}, {
				name:  "microservices"
				image: "immich-server"
				args: ["start.sh", "microservices"]
				env: [{
					name:  "DB_DATABASE_NAME"
					value: "immich"
				}, {
					name:  "DB_HOSTNAME"
					value: "localhost"
				}, {
					name:  "DB_USERNAME"
					value: "immich"
				}, {
					name:  "NODE_ENV"
					value: "production"
				}, {
					name:  "REDIS_HOSTNAME"
					value: "localhost"
				}, {
					name: "JWT_SECRET"
					valueFrom: secretKeyRef: {
						name: "immich"
						key:  "jwt_secret"
					}
				}, {
					name: "DB_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "immich"
						key:  "database_password"
					}
				}]
				volumeMounts: [{
					name:      "upload"
					mountPath: "/usr/src/app/upload"
				}]
			}, {
				name:  "machine-learning"
				image: "immich-machine-learning"
				env: [{
					name:  "NODE_ENV"
					value: "production"
				}]
				volumeMounts: [{
					name:      "upload"
					mountPath: "/usr/src/app/upload"
				}, {
					name:      "ml-cache"
					mountPath: "/cache:U"
				}]
			}] {v}]
		}
	}

	// Placeholder for getting volume list
	jellyfin: {
		_
		param: {
			caddy_proxy_port: 8096
			// This is a hack so we can migrate the folder fields to volumes
			// Once podman support mounting nvidia gpu in quadlet kubernetes we can remove this
			// https://github.com/containers/podman/issues/17833
			kind: "container"
			volumes: {
				cache:  "./cache/"
				config: "./config/"
				media:  "\(_fact.global_media)/"
			}
		}
	}

	jdownloader: {
		_
		param: {
			caddy_proxy_port: 5800
			volumes: {
				config: "./config/"
				output: "\(_fact.global_download)/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "jdownloader"
				// https://github.com/jlesage/docker-jdownloader-2/blob/0091b8358fccea902af05fa29d05f567f073543b/rootfs/etc/cont-init.d/55-jdownloader2.sh
				// https://github.com/jlesage/docker-baseimage-gui#taking-ownership-of-a-directory
				env: [{
					name:  "USER_ID"
					value: "911"
				}, {
					name:  "GROUP_ID"
					value: "911"
				}]
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}, {
					name:      "output"
					mountPath: "/output"
				}]
			}]
		}
	}

	kavita: {
		_
		param: {
			caddy_proxy_port: 5000
			caddy_rewrite: [{
				src:  "/"
				dest: "/login"
			}]
			volumes: {
				config: "./data/"
				home:   "\(_fact.global_media)/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "kavita"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}, {
					name:      "home"
					mountPath: "/home:ro"
				}]
			}]
		}
	}

	koreader: {
		_
		param: {
			caddy_proxy_port:             3000
			caddy_sso:                    true
			dashy_statusCheckAcceptCodes: 401
			dashy_icon:                   "/favicon.ico"
			volumes: {
				config: "./data/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "koreader"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}]
				securityContext: capabilities: add: ["CAP_NET_RAW"]
			}]}
	}

	librespeed: {
		_
		param: caddy_proxy_port: 80
		#pod: spec: containers: [{
			name:  "web"
			image: "librespeed"
		}]
	}

	lidarr: {
		_
		param: {
			caddy_proxy_port: 8686
			caddy_sso:        true
			volumes: {
				config: "./web/config/"
				home:   "\(_fact.global_media)/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "lidarr"
				volumeMounts: [{
					name:      "home"
					mountPath: "/home"
				}, {
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	miniflux: {
		_
		param: {
			caddy_proxy_port: 8080
			volumes: {
				database: "./database/"
			}
			secret: {
				miniflux_postgres_password: {
					type:    "env"
					content: _fact.miniflux_postgres_password
				}
				miniflux_admin_password: {
					type:    "env"
					content: _fact.miniflux_admin_password
				}
				miniflux_database_url: {
					type:    "env"
					content: "postgres://miniflux:\(_fact.miniflux_postgres_password)@localhost:5432/miniflux?sslmode=disable"
				}
			}
		}
		#pod: _profile.rootless_userns & {
			spec: containers: [{
				name:  "postgres"
				image: "miniflux-postgres"
				env: [{
					name:  "POSTGRES_USER"
					value: "miniflux"
				}] + [{
					name: "POSTGRES_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "miniflux"
						key:  "miniflux_postgres_password"
					}
				}]
				volumeMounts: [{
					name:      "database"
					mountPath: "/var/lib/postgresql/data:U,z"
				}]
			}] + [if param.postgres_action == "none" for v in [{
				name:  "web"
				image: "miniflux"
				env: [{
					name:  "RUN_MIGRATIONS"
					value: "1"
				}, {
					name:  "CREATE_ADMIN"
					value: "1"
				}, {
					name:  "ADMIN_USERNAME"
					value: "admin"
				}] + [{
					name: "ADMIN_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "miniflux"
						key:  "miniflux_admin_password"
					}
				}, {
					name: "DATABASE_URL"
					valueFrom: secretKeyRef: {
						name: "miniflux"
						key:  "miniflux_database_url"
					}
				}]
			}] {v}]
		}
	}

	navidrome: {
		_
		param: {
			caddy_proxy_port: 4533
			volumes: {
				data:  "./data/"
				music: "\(_fact.global_media)/Download/torrent/complete/Music/"
			}
		}
		#pod: _profile.userns_share & {
			spec: containers: [{
				name:  "web"
				image: "navidrome"
				env: [{
					name:  "ND_BASEURL"
					value: ""
				}, {
					name:  "ND_LOGLEVEL"
					value: "info"
				}, {
					name:  "ND_SCANSCHEDULE"
					value: "1h"
				}, {
					name:  "ND_SESSIONTIMEOUT"
					value: "24h"
				}]
				volumeMounts: [{
					name:      "data"
					mountPath: "/data:z"
				}, {
					name:      "music"
					mountPath: "/music:ro"
				}]
			}]}
	}

	netdata: {
		_
		param: {
			caddy_proxy_port:             19999
			host_network:                 true
			dashy_show:                   true
			dashy_statusCheckAcceptCodes: 401
			state:                        _fact.netdata_state
		}
	}

	nextcloud: {
		_
		param: {
			caddy_proxy_port: 80
			volumes: {
				data:     "./web/data/"
				database: "./db/data/"
				redis:    "pvc"
				storage:  "./web/storage/"
			}
			secret: {
				postgres_password: {
					type:    "env"
					content: _fact.nextcloud_postgres_password
				}
				redis_password: {
					type:    "env"
					content: _fact.nextcloud_redis_password
				}
			}
		}

		#pod: {
			metadata: annotations: "io.podman.annotations.userns": "keep-id:uid=33,gid=33"
			spec: containers: [{
				name:  "postgres"
				image: "nextcloud-postgres"
				securityContext: {
					runAsUser:  33
					runAsGroup: 33
				}
				env: [{
					name:  "POSTGRES_DB"
					value: "nextcloud"
				}, {
					name:  "POSTGRES_USER"
					value: "postgres"
				}] + [{
					name: "POSTGRES_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "nextcloud"
						key:  "postgres_password"
					}
				}]
				volumeMounts: [{
					name:      "database"
					mountPath: "/var/lib/postgresql/data:U,z"
				}]
			}] + [if param.postgres_action == "none" for v in [{
				name:  "web"
				image: "nextcloud"
				securityContext: {
					runAsUser:  0
					runAsGroup: 0
				}
				env: [{
					name:  "NEXTCLOUD_TRUSTED_DOMAINS"
					value: "nextcloud.\(_fact.server_domain)"
				}, {
					name:  "OVERWRITEPROTOCOL"
					value: "https"
				}, {
					name:  "POSTGRES_DB"
					value: "nextcloud"
				}, {
					name:  "POSTGRES_HOST"
					value: "localhost:5432"
				}, {
					name:  "POSTGRES_USER"
					value: "postgres"
				}, {
					name:  "REDIS_HOST"
					value: "localhost"
				}] + [{
					name: "POSTGRES_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "nextcloud"
						key:  "postgres_password"
					}
				}, {
					name: "REDIS_HOST_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "nextcloud"
						key:  "redis_password"
					}
				}]
				volumeMounts: [{
					name:      "data"
					mountPath: "/var/www/html:z"
				}, {
					name:      "storage"
					mountPath: "/var/www/html/data:z"
				}]
			}, {
				name:  "redis"
				image: "nextcloud-redis"
				args: ["redis-server", "--requirepass", _fact.nextcloud_redis_password]
				volumeMounts: [{
					name:      "redis"
					mountPath: "/data:U"
				}]
			}, {
				name:  "office"
				image: "nextcloud-office"
				env: [{
					name:  "server_name"
					value: "nextcloud-office.\(_fact.server_domain)"
				}, {
					name:  "aliasgroup1"
					value: "nextcloud.\(_fact.server_domain)"
				}, {
					// https://sdk.collaboraonline.com/docs/installation/Proxy_settings.html#reverse-proxy-settings-in-apache2-config-ssl-termination
					name:  "extra_params"
					value: "--o:ssl.enable=false --o:ssl.termination=true"
				}]
				securityContext: {
					capabilities: add: ["MKNOD"]
				}
			}] {v}] + [if _fact.debug {
				name:  "adminer"
				image: "docker.io/adminer"
				ports: [{
					containerPort: 8080
					hostPort:      38080
				}]
			}]
		}
	}

	nextcloud_office: {
		_
		param: {
			caddy_proxy_url: "http://nextcloud:9980"
			dashy_show:      false
		}
	}

	paperless: {
		_
		param: {
			caddy_proxy_port: 8000
			quadlet_build_options: PodmanArgs: "--build-arg=INSTALL_LANGUAGE=\(_fact.paperless_ocr_languages)"
			volumes: {
				consume:  "./webserver/consume/"
				data:     "./webserver/data/"
				database: "./database/data/"
				export:   "./webserver/export/"
				media:    "./webserver/media/"
				redis:    "pvc"
			}
			secret: {
				paperless_dbpass: {
					type:    "env"
					content: _fact.paperless_dbpass
				}
				paperless_ocr_language: {
					type:    "env"
					content: _fact.paperless_ocr_language
				}
				paperless_secret_key: {
					type:    "env"
					content: _fact.paperless_secret_key
				}
				paperless_url: {
					type:    "env"
					content: "https://paperless.\(_fact.server_domain)"
				}
			}
		}

		#pod: _profile.rootless_userns & {
			spec: containers: [{
				name:  "postgres"
				image: "paperless-postgres"
				env: [{
					name:  "POSTGRES_DB"
					value: "paperless"
				}, {
					name:  "POSTGRES_USER"
					value: "paperless"
				}, {
					name: "POSTGRES_PASSWORD"
					valueFrom: secretKeyRef: {
						name: "paperless"
						key:  "paperless_dbpass"
					}
				}]
				volumeMounts: [{
					name:      "database"
					mountPath: "/var/lib/postgresql/data:U,z"
				}]
			}] + [if param.postgres_action == "none" for v in [{
				name:  "redis"
				image: "paperless-redis"
				volumeMounts: [{
					name:      "redis"
					mountPath: "/data:U"
				}]
			}, {
				name:  "gotenberg"
				image: "gotenberg"
				args: [
					"gotenberg",
					"--chromium-disable-javascript=true",
					"--chromium-allow-list=file:///tmp/.*",
				]
			}, {
				name:  "tika"
				image: "tika"
			}, {
				// https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=682407
				// Huge picture will cause gs to crash
				// TODO: We need to be able to adjust the -r value of gs, but currently I'm not sure how to do it on ocrmypdf
				name:  "webserver"
				image: "paperless-ngx"
				env: [{
					name:  "PAPERLESS_DBHOST"
					value: "localhost"
				}, {
					name:  "PAPERLESS_OCR_SKIP_ARCHIVE_FILE"
					value: "always"
				}, {
					name:  "PAPERLESS_REDIS"
					value: "redis://localhost:6379"
				}, {
					name:  "PAPERLESS_TIKA_ENABLED"
					value: "1"
				}, {
					name:  "PAPERLESS_TIKA_ENDPOINT"
					value: "http://localhost:9998"
				}, {
					name:  "PAPERLESS_TIKA_GOTENBERG_ENDPOINT"
					value: "http://localhost:3000"
				}] + [{
					name: "PAPERLESS_DBPASS"
					valueFrom: secretKeyRef: {
						name: "paperless"
						key:  "paperless_dbpass"
					}
				}, {
					name: "PAPERLESS_OCR_LANGUAGE"
					valueFrom: secretKeyRef: {
						name: "paperless"
						key:  "paperless_ocr_language"
					}
				}, {
					name: "PAPERLESS_SECRET_KEY"
					valueFrom: secretKeyRef: {
						name: "paperless"
						key:  "paperless_secret_key"
					}
				}, {
					name: "PAPERLESS_URL"
					valueFrom: secretKeyRef: {
						name: "paperless"
						key:  "paperless_url"
					}
				}]
				// Do not chown paperless volume as it is chowned by the container process
				volumeMounts: [{
					name:      "consume"
					mountPath: "/usr/src/paperless/consume:U,z"
				}, {
					name:      "data"
					mountPath: "/usr/src/paperless/data:U,z"
				}, {
					name:      "export"
					mountPath: "/usr/src/paperless/export:U,z"
				}, {
					name:      "media"
					mountPath: "/usr/src/paperless/media:U,z"
				}]
			}] {v}]
		}
	}

	prowlarr: {
		_
		param: {
			caddy_sso:        true
			caddy_proxy_port: 9696
			volumes: config: "./web/config/"
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "prowlarr"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	pymedusa: {
		_
		param: {
			caddy_sso:        true
			caddy_proxy_port: 8081
			dashy_icon:       "favicon-local"
			volumes: {
				config: "./web/config/"
				home:   "\(_fact.global_media)/"
			}
		}
		#pod: _profile.userns_share & {
			spec: containers: [{
				name:  "web"
				image: "pymedusa"
				volumeMounts: [{
					name:      "home"
					mountPath: "/home"
				}, {
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	radarr: {
		_
		param: {
			caddy_sso:        true
			caddy_proxy_port: 7878
			volumes: {
				config: "./web/config/"
				home:   "\(_fact.global_media)/"
			}
		}
		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "radarr"
				volumeMounts: [{
					name:      "home"
					mountPath: "/home"
				}, {
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	samba: {
		_
		param: {
			quadlet_kube_options: Network: "pasta"
			volumes: {
				storage: "\(_fact.global_storage)/"
			}
			secret: {
				"ACCOUNT_\(_fact.ansible_user)": {
					type:    "env"
					content: _fact.samba_password
				}
			}
		}

		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "instance"
				image: "samba"
				ports: [{
					containerPort: 445
					hostPort:      445
				}]
				env: [{
					name:  "AVAHI_DISABLE"
					value: "1"
				}, {
					name:  "SAMBA_GLOBAL_CONFIG_case_SPACE_sensitive"
					value: "yes"
				}, {
					name:  "UID_\(_fact.ansible_user)"
					value: "911"
				}, {
					name:  "WSDD2_DISABLE"
					value: "1"
				}] + [for k, v in param.volumes {
					name:  "SAMBA_VOLUME_CONFIG_\(k)"
					value: "[\(k)]; path=/shares/\(k); valid users = \(_fact.ansible_user); guest ok = no; read only = no; browseable = yes;"
				}] + [{
					name: "ACCOUNT_\(_fact.ansible_user)"
					valueFrom: secretKeyRef: {
						name: "samba"
						key:  "ACCOUNT_\(_fact.ansible_user)"
					}}]
				volumeMounts: [{
					name:      "storage"
					mountPath: "/shares/storage"
				}]
			}]
		}
	}

	scrutiny: {
		_
		param: {
			become:           true
			caddy_sso:        true
			caddy_proxy_port: scrutiny_port
			host_network:     true
			volumes: {
				udev:   "/run/udev/"
				device: "/dev/"
			}
			secret: {
				"scrutiny.yaml": {
					type: "file"
					content: yaml.Marshal({
						notify: {
							urls: [
								"discord://\(_fact.scrutiny_discord_token)@\(_fact.scrutiny_discord_channel)",
							]
						}
					})
				}
			}
		}

		#pod: spec: {
			containers: [{
				name:  "web"
				image: "scrutiny"
				ports: [{
					containerPort: 8080
					hostPort:      scrutiny_port
				}]
				volumeMounts: [{
					name:      "udev"
					mountPath: "/run/udev:ro"
				}, {
					name:      "scrutiny.yaml"
					readOnly:  true
					mountPath: "/opt/scrutiny/config/scrutiny.yaml"
					subPath:   "scrutiny.yaml"
				}, {
					name:      "device"
					mountPath: "/dev/"
				}]
				securityContext: {
					// Required for nvme drives to work: https://github.com/containers/podman/issues/17833
					privileged: true
				}
			}]
		}
	}

	speedtest: {
		_
		param: {
			caddy_proxy_port: 80
			dashy_icon:       "favicon-local"
			volumes: {
				config: "./config/"
				db:     "./db/data/"
			}
			secret: {
				speedtest_app_key: {
					type:    "env"
					content: _fact.speedtest_app_key
				}
			}
		}

		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "speedtest"
				env: [{
					name:  "DB_CONNECTION"
					value: "sqlite"
				}, {
					name:  "DISPLAY_TIMEZONE"
					value: _fact.ansible_date_time.tz
				}, {
					name:  "SPEEDTEST_SCHEDULE"
					value: "0 * * * *"
				}, {
					name:  "PRUNE_RESULTS_OLDER_THAN"
					value: "365"
				}, {
					name: "APP_KEY"
					valueFrom: secretKeyRef: {
						name: "speedtest"
						key:  "speedtest_app_key"
					}
				}]
				volumeMounts: [{
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	syncthing: {
		_
		param: {
			caddy_proxy_port: 8384
			caddy_sso:        true
			host_network:     true
			quadlet_kube_options: Network: "pasta"
			volumes: {
				data: "./"
			}
		}
		transform: volumes: koreader: {
			type: "absolutePathDir"
			value: path.Join([application.koreader.transform.volumes.config.value, "book"])
		}
		#pod: _profile.userns_share & {
			spec: containers: [{
				name:  "web"
				image: "syncthing"
				// https://docs.syncthing.net/users/firewall.html
				ports: [{
					containerPort: 8384
					hostPort:      8384
				}, {
					containerPort: 22000
					hostPort:      22000
					protocol:      "TCP"
				}, {
					containerPort: 22000
					hostPort:      22000
					protocol:      "UDP"
				}, {
					containerPort: 21027
					hostPort:      21027
					protocol:      "UDP"
				}]
				volumeMounts: [{
					name:      "data"
					mountPath: "/var/syncthing:z"
				}, {
					name:      "koreader"
					mountPath: "/var/syncthing/koreader/book"
				}]
			}]
		}
	}

	transmission: {
		_
		param: {
			caddy_proxy_port:             9091
			dashy_statusCheckAcceptCodes: 401
			volumes: {
				home:   "\(_fact.global_media)/"
				config: "./web/config/"
			}
			secret: {
				USER: {
					type:    "env"
					content: _fact.transmission_user
				}
				PASS: {
					type:    "env"
					content: _fact.transmission_password
				}
			}
		}

		#pod: _profile.lsio & {
			spec: containers: [{
				name:  "web"
				image: "transmission"
				env: [{
					name: "USER"
					valueFrom: secretKeyRef: {
						name: "transmission"
						key:  "USER"
					}}, {
					name: "PASS"
					valueFrom: secretKeyRef: {
						name: "transmission"
						key:  "PASS"
					}
				}]
				ports: [{
					containerPort: 51413
					hostPort:      51413
				}, {
					containerPort: 51413
					hostPort:      51413
					protocol:      "UDP"
				}]
				volumeMounts: [{
					name:      "home"
					mountPath: "/home"
				}, {
					name:      "config"
					mountPath: "/config:z"
				}]
			}]
		}
	}

	trilium: {
		_
		param: {
			caddy_proxy_port: 8080
			volumes: {
				data: "./data/"
			}
		}
		#pod: {
			metadata: annotations: "io.podman.annotations.userns": "keep-id:uid=1000,gid=1000"
			spec: containers: [{
				name:  "web"
				image: "trilium"
				securityContext: {
					runAsUser:  0
					runAsGroup: 0
				}
				volumeMounts: [{
					name:      "data"
					mountPath: "/home/node/trilium-data:z"
				}]
			}]
		}
	}

	wol: {
		_
		param: {
			caddy_proxy_port: 8089
			caddy_sso:        true
			dashy_icon:       "mdi-desktop-classic"
			host_network:     true
			secret: {
				WOLWEBBCASTIP: {
					type:    "env"
					content: _fact.wol_bcast_ip
				}
				"devices.json": {
					type:    "file"
					content: json.Marshal(_fact.wol_config_devices)
				}
			}
		}

		#pod: _profile.rootless & {
			spec: {
				containers: [{
					name:  "web"
					image: "wol"
					env: [{
						name:  "WOLWEBVDIR"
						value: "/"
					}, {
						name: "WOLWEBBCASTIP"
						valueFrom: secretKeyRef: {
							name: "wol"
							key:  "WOLWEBBCASTIP"
						}
					}]
					volumeMounts: [{
						name:      "devices.json"
						readOnly:  true
						mountPath: "/wolweb/devices.json"
						subPath:   "devices.json"
					}]
				}]
				hostNetwork: true
			}
		}
	}
}

restic_backup_path: _fact.global_volume_path
restic_env: {
	B2_ACCOUNT_ID:     _fact.restic_b2_account_id
	B2_ACCOUNT_KEY:    _fact.restic_b2_account_key
	BACKUP_PATHS:      restic_backup_path
	RESTIC_PASSWORD:   _fact.restic_password
	RESTIC_REPOSITORY: "\(_fact.restic_repository)\(restic_backup_path)"
	EXCLUDE_FILE:      "/etc/restic/exclude"
	RETENTION_MONTHS:  1
	RETENTION_WEEKS:   1
	RETENTION_DAYS:    1
	RESTIC_CACHE_DIR:  "/etc/restic/cache"
}
restic_env_path: "/etc/restic/restic.env"

scrutiny_port: 18080

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
