package application

import (
	"encoding/base64"
	"encoding/json"
	"encoding/yaml"
	"strings"
	applicationSet "zephyros.dev/src/common:applicationSet"
	fact "zephyros.dev/tmp:fact"
)

applicationSet & {
	bazarr: {
		_
		#param: {
			name: "bazarr"
			env: {
				PGID: fact.global_pgid
				PUID: fact.global_puid
			}
			volumes: {
				config: "\(fact.bazarr_web_config)/"
				home:   "\(fact.global_media)/"
			}
		}
		#pod: spec: containers: [{
			name:  "web"
			image: "bazarr"
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "home"
				mountPath: "/home"
			}]
		}]
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
			env: {
				PGID: fact.global_pgid
				PUID: fact.global_puid
			}
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
					type:    "file"
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
									if v.state == "started" || v.state == "present" {
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
			name:    "immich"
			volumes: {
				database:  "\(fact.immich_volume_database)/"
				typesense: "\(fact.immich_volume_typesense)/"
				upload:    "\(fact.immich_volume_upload)/"
			} & {
				ml_cache: "immich_volume_ml_cache"
			}
			secret: {
				database_password: {
					type:    "env"
					content: "\(fact.immich_database_password)"
				}
				typesense_api_key: {
					type:    "env"
					content: "\(fact.immich_typesense_api_key)"
				}
				jwt_secret: {
					type:    "env"
					content: "\(fact.immich_jwt_secret)"
				}
			}
		}

		#pod: spec: containers: [{
			name:  "redis"
			image: "redis"
		}, {
			name:  "database"
			image: "postgres"
			env: [{
				name:  "POSTGRES_DB"
				value: "immich"
			}, {
				name:  "POSTGRES_USER"
				value: "immich"
			}, {
				name: "POSTGRES_PASSWORD"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "database_password"
				}
			}]
			volumeMounts: [{
				name:      "database"
				mountPath: "/var/lib/postgresql/data"
			}]
		}, {
			name:  "typesense"
			image: "typesense"
			env: [{
				name:  "TYPESENSE_DATA_DIR"
				value: "/data"
			}, {
				name: "TYPESENSE_API_KEY"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "typesense_api_key"
				}
			}]
			volumeMounts: [{
				name:      "typesense"
				mountPath: "/data:U,z"
			}]
		}, {
			name:  "server"
			image: "server"
			args: ["start-server.sh"]
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
				name:           "TYPESENSE_URL"
				_typesense_url: base64.Encode(null, json.Marshal(fact.immich_typesense_url))
				value:          "ha://\(_typesense_url)"
			}, {
				name: "JWT_SECRET"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "jwt_secret"
				}
			}, {
				name: "DB_PASSWORD"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "database_password"
				}
			}, {
				name: "TYPESENSE_API_KEY"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "typesense_api_key"
				}
			}]
			volumeMounts: [{
				name:      "upload"
				mountPath: "/usr/src/app/upload"
			}]
		}, {
			name:  "microservices"
			image: "server"
			args: ["start-microservices.sh"]
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
				name:  "TYPESENSE_HOST"
				value: "localhost"
			}, {
				name: "JWT_SECRET"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "jwt_secret"
				}
			}, {
				name: "DB_PASSWORD"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "database_password"
				}
			}, {
				name: "TYPESENSE_API_KEY"
				valueFrom: secretKeyRef: {
					name: "immich-env"
					key:  "typesense_api_key"
				}
			}]
			volumeMounts: [{
				name:      "upload"
				mountPath: "/usr/src/app/upload"
			}]
		}, {
			name:  "machine-learning"
			image: "machine-learning"
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
		}, {
			name:  "web"
			image: "web"
			env: [{
				name:  "IMMICH_SERVER_URL"
				value: "http://localhost:3001"
			}]
		}]
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

	jellyfin: {
		_
		#param: {
			name: "jellyfin"
			volumes: {
				cache:  "\(fact.jellyfin_volume_cache)/"
				config: "\(fact.jellyfin_volume_config)/"
				home:   "\(fact.global_media)/"
				dev:    "/dev/dri/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "jellyfin"
			volumeMounts: [{
				name:      "cache"
				mountPath: "/cache:U,z"
			}, {
				name:      "config"
				mountPath: "/config:U,z"
			}, {
				name:      "home"
				mountPath: "/home"
			}, {
				name:      "dev"
				mountPath: "/dev/dri"
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
			env: {
				PUID: fact.global_puid
				PGID: fact.global_pgid
			}
			volumes: {
				config: "\(fact.koreader_volume_data)/"
				device: "/dev/dri/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "koreader"
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
			env: {
				PUID: fact.global_puid
				PGID: fact.global_pgid
			}
			volumes: {
				home:      "\(fact.global_media)/"
				config:    "\(fact.lidarr_web_config)/"
				downloads: "\(fact.transmission_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "lidarr"
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

	navidrome: {
		_
		#param: {
			name: "navidrome"
			env: {
				ND_BASEURL:        ""
				ND_LOGLEVEL:       "info"
				ND_SCANSCHEDULE:   "1h"
				ND_SESSIONTIMEOUT: "24h"
			}
			volumes: {
				data:  "\(fact.navidrome_web_data)/"
				music: "\(fact.navidrome_music)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "navidrome"
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
			name:  "redis"
			image: "redis"
			volumeMounts: [{
				name:      "redis"
				mountPath: "/data:U,z"
			}]
		}, {
			name:  "database"
			image: "database"
			env: [{
				name:  "POSTGRES_DB"
				value: "paperless"
			}, {
				name:  "POSTGRES_USER"
				value: "paperless"
			}, {
				name: "POSTGRES_PASSWORD"
				valueFrom: secretKeyRef: {
					name: "paperless-env"
					key:  "paperless_dbpass"
				}
			}]
			volumeMounts: [{
				name:      "database"
				mountPath: "/var/lib/postgresql/data:U,z"
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
			image: "webserver"
			env:   [{
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
					name: "paperless-env"
					key:  "paperless_dbpass"
				}
			}, {
				name: "PAPERLESS_OCR_LANGUAGE"
				valueFrom: secretKeyRef: {
					name: "paperless-env"
					key:  "paperless_ocr_language"
				}
			}, {
				name: "PAPERLESS_OCR_LANGUAGES"
				valueFrom: secretKeyRef: {
					name: "paperless-env"
					key:  "paperless_ocr_languages"
				}
			}, {
				name: "PAPERLESS_SECRET_KEY"
				valueFrom: secretKeyRef: {
					name: "paperless-env"
					key:  "paperless_secret_key"
				}
			}, {
				name: "PAPERLESS_URL"
				valueFrom: secretKeyRef: {
					name: "paperless-env"
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
			env: {
				PUID: fact.global_puid
				PGID: fact.global_pgid
			}
			volumes: {
				home:      "\(fact.global_media)/"
				config:    "\(fact.radarr_web_config)/"
				downloads: "\(fact.transmission_download)/"
			}
		}

		#pod: spec: containers: [{
			name:  "web"
			image: "radarr"
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
			env:  {
				AVAHI_DISABLE:                            "1"
				GROUP_root:                               "0"
				SAMBA_GLOBAL_CONFIG_case_SPACE_sensitive: "yes"
				UID_root:                                 "0"
				WSDD2_DISABLE:                            "1"
			} & {
				for k, v in volumes {
					"SAMBA_VOLUME_CONFIG_\(k)": "[\(k)]; path=/shares/\(k); \(fact.samba_shares_settings)"
				}}
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
				}] + [ for v in fact.scrutiny_device_list {
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
			env: {
				PUID: fact.global_puid
				PGID: fact.global_pgid
			}
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
			env: {
				WOLWEBVDIR: "/"
			}
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
