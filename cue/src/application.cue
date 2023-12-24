package application

import (
	"encoding/json"
	"encoding/yaml"
	"strings"
	core "k8s.io/api/core/v1"
	fact "zephyros.dev/tmp:fact"
)

_applicationSet: [applicationName=_]: {
	#param: {
		name: string
		secret: {
			string?: {
				type:    "file" | "env"
				content: string
			}
		}
		volumes: string?: string
	}

	#pod: core.#Pod & {
		apiVersion: "v1"
		kind:       "Pod"
		metadata: {
			annotations: {
				"io.podman.annotations.infra.name": "\(#param.name)-pod"
			}
			labels: app: "\(#param.name)"
			name: "\(#param.name)"
		}
		spec: {
			volumes: [for k, v in #param.volumes {
				name: k
				if v !~ "^\/" {
					persistentVolumeClaim: claimName: v
				}
				if v =~ "^\/.+[^\/]$" {
					hostPath: {
						path: v
						type: "File"
					}
				}
				if v =~ "^\/.+\/$" {
					hostPath: {
						path: v
						type: "Directory"
					}
				}
			}] + [for k, v in #param.secret if v.type == "file" {
				name: k
				secret: {
					secretName: "\(#param.name)"
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

	#secret: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)"
		}
		type: "Opaque"
		stringData: {
			for k, v in #param.secret if v.type == "file" {
				"\(k)": v.content
			}
		} & {
			for k, v in #param.secret if v.type == "env" {
				"\(k)": v.content
			}
		}
	}

	#volume: [for k, v in #param.volumes if v !~ "^\/" {
		core.#PersistentVolumeClaim & {
			apiVersion: "v1"
			kind:       "PersistentVolumeClaim"
			metadata: {
				name: v
			}
		}
	}]

	[#pod, #secret] + #volume
}

_applicationSet & {
	audiobookshelf: {
		_
		#param: {
			name: "audiobookshelf"
			volumes: {
				audiobooks: "\(fact.audiobookshelf_volume_audiobooks)/"
				config:     "\(fact.audiobookshelf_volume_config)/"
				metadata:   "\(fact.audiobookshelf_volume_metadata)/"
				podcasts:   "\(fact.audiobookshelf_volume_podcasts)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "audiobookshelf"
			volumeMounts: [{
				name:      "audiobooks"
				mountPath: "/audiobooks"
			}, {
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "metadata"
				mountPath: "/metadata:U,z"
			}, {
				name:      "podcasts"
				mountPath: "/podcasts"
			}]
		}]
	}

	bazarr: {
		_
		#param: {
			name: "bazarr"
			volumes: {
				config: "\(fact.bazarr_web_config)/"
				home:   "\(fact.global_media)/"
			}
		}
		#pod: spec: containers: [{
			name:  "web"
			image: "bazarr"
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}]
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "home"
				mountPath: "/home"
			}]
		}]
	}

	ddns: {
		_
		#param: {
			name: "ddns"
			secret: {
				Caddyfile: {
					type:    "file"
					content: """
					{
						dynamic_dns {
							provider dynv6 \(fact.ddns_dynv6_token)
							domains {
								\(fact.dynv6_zone) *.\(fact.server_subdomain)
							}
						}
					}
					"""
				}
			}
			volumes: {
				config: "ddns_volume_config"
				data:   "ddns_volume_data"
			}
		}

		#pod: spec: {
			hostNetwork: true
			containers: [{
				name:  "instance"
				image: "ddns"
				volumeMounts: [{
					name:      "config"
					mountPath: "/config"
				}, {
					name:      "data"
					mountPath: "/data"
				}, {
					name:      "Caddyfile"
					readOnly:  true
					mountPath: "/etc/caddy/Caddyfile"
					subPath:   "Caddyfile"
				}]
			}]
		}
	}

	caddy: {
		_
		#param: {
			name: "caddy"
			secret: {
				Caddyfile: {
					type:    "file"
					content: "\(fact.caddyfile_content)"
				}
			}
			volumes: {
				config: "caddy_volume_config"
				data:   "caddy_volume_data"
			}
		}
		#pod: spec: containers: [{
			name:  "instance"
			image: "caddy"
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
				mountPath: "/config"
				name:      "config"
			}, {
				mountPath: "/data"
				name:      "data"
			}, {
				name:      "Caddyfile"
				readOnly:  true
				mountPath: "/etc/caddy/Caddyfile"
				subPath:   "Caddyfile"
			}]
		}]
	}

	calibre: {
		_
		#param: {
			name: "calibre"
			volumes: {
				config: "\(fact.calibre_volume_config)/"
				books:  "\(fact.calibre_book)/"
				device: "/dev/dri/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "calibre"
			ports: [{
				// Used for the calibre wireless device connection
				containerPort: 9090
				hostPort:      59090
			}]
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}]
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "books"
				mountPath: "/books"
			}, {
				name:      "device"
				mountPath: "/dev/dri"
			}]
		}]
	}

	dashy: {
		_
		#param: {
			name: "dashy"
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
								for k, v in fact.container
								if !v.dashy_skip {
									_url_key:    strings.Replace(k, "_", "-", -1)
									_url_public: "https://\(_url_key).\(fact.server_domain)"
									if v.state == "started" {
										title: strings.ToTitle(_url_key)
										if v.dashy_icon == "" {
											icon: "hl-\(_url_key)"
										}
										if v.dashy_icon != "" {
											if strings.HasPrefix(v.dashy_icon, "/") {
												icon: "https://\(_url_key).\(fact.server_domain)\(v.dashy_icon)"
											}
											if !strings.HasPrefix(v.dashy_icon, "/") {
												icon: v.dashy_icon
											}
										}
										if v.caddy_sso {
											statusCheckAllowInsecure: true
											if v.dashy_statusCheckUrl == "" {
												if v.host_network {
													statusCheckUrl: "http://\(fact.caddyfile_host_address):\(v.caddy_proxy_port)"
												}
												if !v.host_network {
													statusCheckUrl: "http://\(_url_key):\(v.caddy_proxy_port)"
												}
											}
											if v.dashy_statusCheckUrl != "" {
												statusCheckUrl: v.dashy_statusCheckUrl
											}
										}
										if !v.caddy_sso {
											statusCheckUrl: _url_public
										}
										if v.dashy_statusCheckAcceptCodes != "" {
											statusCheckAcceptCodes: v.dashy_statusCheckAcceptCodes
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
				mountPath: "/app/public/conf.yml"
				subPath:   "conf.yml"
			}]
			securityContext: {
				runAsGroup: 0
				runAsUser:  0
			}
		}]
	}

	filebrowser: {
		_
		#param: {
			name: "filebrowser"
			volumes: {
				srv:           "\(fact.global_media)/"
				"database.db": "\(fact.filebrowser_volume)/database.db"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "filebrowser"
			volumeMounts: [{
				name:      "srv"
				mountPath: "/srv"
			}, {
				name:      "database.db"
				mountPath: "/database.db:U,z"
			}]
		}]
	}

	immich: {
		_
		#param: {
			name: "immich"
			volumes: {
				database: "\(fact.immich_volume_database)/"
				upload:   "\(fact.immich_volume_upload)/"
			} & {
				ml_cache: "immich_volume_ml_cache"
			}
			secret: {
				database_password: {
					type:    "env"
					content: "\(fact.immich_database_password)"
				}
				jwt_secret: {
					type:    "env"
					content: "\(fact.immich_jwt_secret)"
				}
			}
		}

		#pod: spec: containers: [{
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
		}] + [if fact.container.immich.postgres_action == "none" for v in [{
			name:  "redis"
			image: "immich-redis"
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
				name:      "ml_cache"
				mountPath: "/cache:U"
			}]
		}] {v}]
	}

	jdownloader: {
		_
		#param: {
			name: "jdownloader"
			volumes: {
				config: "\(fact.jdownloader_volume_config)/"
				output: "\(fact.global_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "jdownloader"
			// Needed for chown the output directory
			// https://github.com/jlesage/docker-jdownloader-2/blob/0091b8358fccea902af05fa29d05f567f073543b/rootfs/etc/cont-init.d/55-jdownloader2.sh
			// https://github.com/jlesage/docker-baseimage-gui#taking-ownership-of-a-directory
			env: [{
				name:  "USER_ID"
				value: "\(fact.global_puid)"
			}, {
				name:  "GROUP_ID"
				value: "\(fact.global_pgid)"
			}]
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "output"
				mountPath: "/output"
			}]
		}]
	}

	kavita: {
		_
		#param: {
			name: "kavita"
			volumes: {
				config: "\(fact.kavita_volume_data)/"
				home:   "\(fact.global_media)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "kavita"
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "home"
				mountPath: "/home:ro"
			}]
		}]
	}

	koreader: {
		_
		#param: {
			name: "koreader"
			volumes: {
				config: "\(fact.koreader_volume_data)/"
				device: "/dev/dri/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "koreader"
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}]
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "device"
				mountPath: "/dev/dri"
			}]
			securityContext: capabilities: add: ["CAP_NET_RAW"]
		}]
	}

	kosync: {
		_
		#param: {
			name: "kosync"
			volumes: {
				redis: "\(fact.kosync_volume_redis_data)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "kosync"
			volumeMounts: [{
				name:      "redis"
				mountPath: "/var/lib/redis"
			}]
		}]
	}

	librespeed: {
		_
		#param: name: "librespeed"

		#pod: spec: containers: [{
			name:  "web"
			image: "librespeed"
		}]
	}

	lidarr: {
		_
		#param: {
			name: "lidarr"
			volumes: {
				home:      "\(fact.global_media)/"
				config:    "\(fact.lidarr_web_config)/"
				downloads: "\(fact.transmission_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "lidarr"
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}]
			volumeMounts: [{
				name:      "home"
				mountPath: "/home"
			}, {
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "downloads"
				mountPath: "/downloads"
			}]
		}]
	}

	miniflux: {
		_
		#param: {
			name: "miniflux"
			secret: {
				miniflux_postgres_password: {
					type:    "env"
					content: "\(fact.miniflux_postgres_password)"
				}
				miniflux_admin_password: {
					type:    "env"
					content: "\(fact.miniflux_admin_password)"
				}
				miniflux_database_url: {
					type:    "env"
					content: "postgres://miniflux:\(fact.miniflux_postgres_password)@localhost:5432/miniflux?sslmode=disable"
				}
			}
			volumes: {
				database: "\(fact.miniflux_volume_database)/"
			}
		}
		#pod: spec: containers: [{
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
		}] + [if fact.container.miniflux.postgres_action == "none" for v in [{
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

	navidrome: {
		_
		#param: {
			name: "navidrome"
			volumes: {
				data:  "\(fact.navidrome_web_data)/"
				music: "\(fact.navidrome_music)/"
			}
		}

		#pod: spec: containers: [{
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
				mountPath: "/data:U,z"
			}, {
				name:      "music"
				mountPath: "/music:ro"
			}]
		}]
	}

	paperless: {
		_
		#param: {
			name: "paperless"
			secret: {
				paperless_dbpass: {
					type:    "env"
					content: "\(fact.paperless_dbpass)"
				}
				paperless_ocr_language: {
					type:    "env"
					content: "\(fact.paperless_ocr_language)"
				}
				paperless_ocr_languages: {
					type:    "env"
					content: "\(fact.paperless_ocr_languages)"
				}
				paperless_secret_key: {
					type:    "env"
					content: "\(fact.paperless_secret_key)"
				}
				paperless_url: {
					type:    "env"
					content: "https://paperless.\(fact.server_domain)"
				}
			}
			volumes: {
				redis:    "\(fact.paperless_volume_redis_data)/"
				database: "\(fact.paperless_volume_database_data)/"
				consume:  "\(fact.paperless_volume_webserver_consume)/"
				data:     "\(fact.paperless_volume_webserver_data)/"
				export:   "\(fact.paperless_volume_webserver_export)/"
				media:    "\(fact.paperless_volume_webserver_media)/"
			}
		}

		#pod: spec: containers: [{
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
		}] + [if fact.container.paperless.postgres_action == "none" for v in [{
			name:  "redis"
			image: "paperless-redis"
			volumeMounts: [{
				name:      "redis"
				mountPath: "/data:U,z"
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
				name: "PAPERLESS_OCR_LANGUAGES"
				valueFrom: secretKeyRef: {
					name: "paperless"
					key:  "paperless_ocr_languages"
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

	nextcloud: {
		_
		#param: {
			name: "nextcloud"
			secret: {
				postgres_password: {
					type:    "env"
					content: "\(fact.nextcloud_postgres_password)"
				}
				redis_password: {
					type:    "env"
					content: "\(fact.nextcloud_redis_password)"
				}
			}
			volumes: {
				data:     "\(fact.nextcloud_volume_web_data)/"
				database: "\(fact.nextcloud_volume_db_data)/"
				storage:  "\(fact.nextcloud_volume_web_storage)/"
			}
		}

		#pod: spec: containers: [{
			name:  "postgres"
			image: "nextcloud-postgres"
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
		}] + [if fact.container.nextcloud.postgres_action == "none" for v in [{
			name:  "web"
			image: "nextcloud"
			env: [{
				name:  "NEXTCLOUD_TRUSTED_DOMAINS"
				value: "nextcloud.\(fact.server_domain)"
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
			args: ["redis-server", "--requirepass", "\(fact.nextcloud_redis_password)"]
		}] {v}] + [if fact.debug {
			name:  "adminer"
			image: "docker.io/adminer"
			ports: [{
				containerPort: 8080
				hostPort:      38080
			}]
		}]
	}

	prowlarr: {
		_
		#param: {
			name: "prowlarr"
			volumes: {
				config: "\(fact.prowlarr_web_config)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "prowlarr"
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}]
		}]
	}

	pymedusa: {
		_
		#param: {
			name: "pymedusa"
			volumes: {
				home:      "\(fact.global_media)/"
				config:    "\(fact.pymedusa_web_config)/"
				downloads: "\(fact.transmission_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "pymedusa"
			volumeMounts: [{
				name:      "home"
				mountPath: "/home"
			}, {
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "downloads"
				mountPath: "/downloads"
			}]
		}]
	}

	radarr: {
		_
		#param: {
			name: "radarr"
			volumes: {
				home:      "\(fact.global_media)/"
				config:    "\(fact.radarr_web_config)/"
				downloads: "\(fact.transmission_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "radarr"
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}]
			volumeMounts: [{
				name:      "home"
				mountPath: "/home"
			}, {
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "downloads"
				mountPath: "/downloads"
			}]
		}]
	}

	samba: {
		_
		#param: {
			name: "samba"
			secret: {
				ACCOUNT_root: {
					type:    "env"
					content: "\(fact.samba_password)"
				}
			}
			volumes: {
				home:    "\(fact.ansible_user_dir)/"
				disk:    "\(fact.ansible_user_dir)/disk/"
				disks:   "\(fact.global_disks_data)/"
				storage: "\(fact.global_storage)/"
			}
		}

		#pod: spec: {
			containers: [{
				name:  "instance"
				image: "samba"
				env: [{
					name:  "AVAHI_DISABLE"
					value: "1"
				}, {
					name:  "GROUP_root"
					value: "0"
				}, {
					name:  "SAMBA_GLOBAL_CONFIG_case_SPACE_sensitive"
					value: "yes"
				}, {
					name:  "UID_root"
					value: "0"
				}, {
					name:  "WSDD2_DISABLE"
					value: "1"
				}] + [for k, v in #param.volumes {
					name:  "SAMBA_VOLUME_CONFIG_\(k)"
					value: "[\(k)]; path=/shares/\(k); \(fact.samba_shares_settings)"
				}] + [{
					name: "ACCOUNT_root"
					valueFrom: secretKeyRef: {
						name: "samba"
						key:  "ACCOUNT_root"
					}}]
				volumeMounts: [{
					name:      "home"
					mountPath: "/shares/home"
				}, {
					name:      "disk"
					mountPath: "/shares/disk"
				}, {
					name:      "disks"
					mountPath: "/shares/disks"
				}, {
					name:      "storage"
					mountPath: "/shares/storage"
				}]
			}]
			hostNetwork: true
		}
	}

	scrutiny: {
		_
		#param: {
			name: "scrutiny"
			secret: {
				"scrutiny.yaml": {
					type:    "file"
					content: yaml.Marshal(fact.scrutiny_config)
				}
			}
			volumes: {udev: "/run/udev/"} &
				{for v in fact.scrutiny_device_list {"\(v)": "\(v)"}}
		}

		#pod: spec: {
			containers: [{
				name:  "web"
				image: "scrutiny"
				ports: [{
					containerPort: 8080
					hostPort:      fact.scrutiny_port
				}]
				volumeMounts: [{
					name:      "udev"
					mountPath: "/run/udev:ro"
				}, {
					name:      "scrutiny.yaml"
					readOnly:  true
					mountPath: "/opt/scrutiny/config/scrutiny.yaml"
					subPath:   "scrutiny.yaml"
				}] + [for v in fact.scrutiny_device_list {
					{
						name:      v
						mountPath: v
					}
				}]
				securityContext: {
					capabilities: add: ["SYS_RAWIO", "SYS_ADMIN"]
					// Required for nvme drives to work: https://github.com/containers/podman/issues/17833
					privileged: true
				}
			}]
		}
	}

	syncthing: {
		_
		#param: {
			name: "syncthing"
			volumes: {
				data: "\(fact.syncthing_data)/"
			}
		}

		#pod: spec: {
			containers: [{
				name:  "web"
				image: "syncthing"
				volumeMounts: [{
					name:      "data"
					mountPath: "/var/syncthing:U,z"
				}]
			}]
			hostNetwork: true
		}
	}

	transmission: {
		_
		#param: {
			name: "transmission"
			secret: {
				USER: {
					type:    "env"
					content: "\(fact.transmission_user)"
				}
				PASS: {
					type:    "env"
					content: "\(fact.transmission_password)"
				}
			}
			volumes: {
				home:   "\(fact.global_media)/"
				config: "\(fact.transmission_web_config)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "transmission"
			env: [{
				name:  "PGID"
				value: fact.global_pgid
			}, {
				name:  "PUID"
				value: fact.global_puid
			}] + [{
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
				mountPath: "/config:U,z"
			}]
		}]
	}

	trilium: {
		_
		#param: {
			name: "trilium"
			volumes: {
				data: "\(fact.trilium_volume_data)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "trilium"
			volumeMounts: [{
				name:      "data"
				mountPath: "/home/node/trilium-data:U,z"
			}]
		}]
	}

	wol: {
		_
		#param: {
			name: "wol"
			secret: {
				WOLWEBBCASTIP: {
					type:    "env"
					content: fact.wol_bcast_ip
				}
				"devices.json": {
					type:    "file"
					content: json.Marshal(fact.wol_config_devices)
				}
			}
		}

		#pod: spec: {
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
