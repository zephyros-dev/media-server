@extern(embed)
package application

import (
	"encoding/json"
	"encoding/yaml"
	"strings"
	"path"
	core "k8s.io/api/core/v1"
)

_applicationName: string @tag(name)

// Have to use MarshalStream since cue export does not make stream yaml
yaml.MarshalStream(_application[_applicationName])

// Type check for the container variables
_fact_embed: _ @embed(file="tmp/fact.json")
#container: {
	become:           bool
	caddy_proxy_port: int32
	caddy_proxy_url:  string
	caddy_rewrite: [...{
		src:  string
		dest: string
	}]
	caddy_sso:                    bool
	dashy_icon:                   string
	dashy_only:                   bool
	dashy_statusCheckAcceptCodes: string
	host_network:                 bool
	kind:                         "kube" | "container"
	kube_quadlet_options: [string]: string
	postgres_action: "none" | "export" | "import" | "clean"
	preserve_volume: bool
	state:           "started" | "absent"
	volumes: [string]: string
}
_fact: _fact_embed & {container: [string]: #container}

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
	rootless_cap: rootless & userns_share
}

_applicationSet: [applicationName=string]: {
	#param: {
		secret: {
			string?: {
				type:    "file" | "env"
				content: string
			}
		}
		volumes: {
			for k, v in _fact.container[strings.Replace(applicationName, "-", "_", -1)].volumes {"\(k)": {
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

	#pod: core.#Pod & {
		apiVersion: "v1"
		kind:       "Pod"
		metadata: {
			annotations: "io.podman.annotations.infra.name": "\(applicationName)-pod"
			name: applicationName
		}
		spec: {
			volumes: [for k, v in #param.volumes {
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
			}] + [for k, v in #param.secret if v.type == "file" {
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

	#secret: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: applicationName
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

	#volume: [for k, v in #param.volumes if v.type == "pvc" {
		core.#PersistentVolumeClaim & {
			apiVersion: "v1"
			kind:       "PersistentVolumeClaim"
			metadata: {
				name: "\(applicationName)-\(k)"
			}
		}
	}]

	[#pod, #secret] + #volume
}

_application: _applicationSet & {
	audiobookshelf: {
		_
		#pod: _profile.rootless_cap & {
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
		#param: {
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

	calibre: {
		_
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

	// Already set to run as rootless in image build
	dashy: {
		_
		#param: {
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
								for k, v in _fact.container
								if (v.dashy_only || v.caddy_proxy_port > 0) && k != "dashy" {
									_url_key:    strings.Replace(k, "_", "-", -1)
									_url_public: string | *"https://\(_url_key).\(_fact.server_domain)"
									if k == "cockpit" {
										_url_public: "https://server.\(_fact.dynv6_zone)"
									}
									if v.state == "started" {
										title: strings.ToTitle(_url_key)
										if v.dashy_icon == "" {
											icon: "hl-\(_url_key)"
										}
										if v.dashy_icon != "" {
											if strings.HasPrefix(v.dashy_icon, "/") {
												icon: "https://\(_url_key).\(_fact.server_domain)\(v.dashy_icon)"
											}
											if !strings.HasPrefix(v.dashy_icon, "/") {
												icon: v.dashy_icon
											}
										}
										if v.caddy_sso {
											statusCheckAllowInsecure: true
											if v.caddy_proxy_url == "" {
												if v.host_network {
													statusCheckUrl: "http://\(_fact.caddyfile_host_address):\(v.caddy_proxy_port)"
												}
												if !v.host_network {
													statusCheckUrl: "http://\(_url_key):\(v.caddy_proxy_port)"
												}
											}
											if v.caddy_proxy_url != "" {
												statusCheckUrl: v.caddy_proxy_url
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
				mountPath: "/app/user-data/conf.yml"
				subPath:   "conf.yml"
			}]
		}]
	}

	ddns: {
		_
		#param: {
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
		#pod: _profile.rootless_cap & {
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
	// TODO: rootless?
	immich: {
		_
		#param: {
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
				mountPath: "/var/lib/postgresql/data:z"
			}]
		}] + [if _fact.container.immich.postgres_action == "none" for v in [{
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
				name:      "ml-cache"
				mountPath: "/cache:U"
			}]
		}] {v}]
	}

	// Placeholder for getting volume list
	jellyfin: {
		_
	}

	jdownloader: {
		_
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
		#pod: spec: containers: [{
			name:  "web"
			image: "librespeed"
		}]
	}

	lidarr: {
		_
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

	// Already rootless
	miniflux: {
		_
		#param: {
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
				mountPath: "/var/lib/postgresql/data:z"
			}]
		}] + [if _fact.container.miniflux.postgres_action == "none" for v in [{
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

	// TODO: rootless?
	nextcloud: {
		_
		#param: {
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
				mountPath: "/var/lib/postgresql/data:z"
			}]
		}] + [if _fact.container.nextcloud.postgres_action == "none" for v in [{
			name:  "web"
			image: "nextcloud"
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

	paperless: {
		_
		#param: {
			secret: {
				paperless_dbpass: {
					type:    "env"
					content: _fact.paperless_dbpass
				}
				paperless_ocr_language: {
					type:    "env"
					content: _fact.paperless_ocr_language
				}
				paperless_ocr_languages: {
					type:    "env"
					content: _fact.paperless_ocr_languages
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
				mountPath: "/var/lib/postgresql/data:z"
			}]
		}] + [if _fact.container.paperless.postgres_action == "none" for v in [{
			name:  "redis"
			image: "paperless-redis"
			securityContext: {
				runAsUser:  _fact.ansible_user_uid
				runAsGroup: _fact.ansible_user_gid
			}
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
			// Do not chown paperless volume as it is chowned by the container process
			volumeMounts: [{
				name:      "consume"
				mountPath: "/usr/src/paperless/consume:z"
			}, {
				name:      "data"
				mountPath: "/usr/src/paperless/data:z"
			}, {
				name:      "export"
				mountPath: "/usr/src/paperless/export:z"
			}, {
				name:      "media"
				mountPath: "/usr/src/paperless/media:z"
			}]
		}] {v}]
	}

	prowlarr: {
		_
		#pod: spec: containers: [{
			name:  "web"
			image: "prowlarr"
			volumeMounts: [{
				name:      "config"
				mountPath: "/config:z"
			}]
		}]
	}

	pymedusa: {
		_
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
		#param: {
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
				}] + [for k, v in #param.volumes {
					name:  "SAMBA_VOLUME_CONFIG_\(k)"
					value: "[\(k)]; path=/shares/\(k); valid users = \(_fact.ansible_user); guest ok = no; read only = no; browseable = yes;"
				}] + [{
					name: "ACCOUNT_\(_fact.ansible_user)"
					valueFrom: secretKeyRef: {
						name: "samba"
						key:  "ACCOUNT_\(_fact.ansible_user)"
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
		}
	}

	scrutiny: {
		_
		#param: {
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
					hostPort:      _fact.scrutiny_port
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
		#param: {
			secret: {
				speedtest_app_key: {
					type:    "env"
					content: _fact.speedtest_app_key
				}
			}
		}

		#pod: spec: containers: [{
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

	syncthing: {
		_
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
					name:      "koreader-book"
					mountPath: "/var/syncthing/koreader/book"
				}]
			}]
		}
	}

	transmission: {
		_
		#param: {
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
		#pod: spec: containers: [{
			name:  "web"
			image: "trilium"
			volumeMounts: [{
				name:      "data"
				mountPath: "/home/node/trilium-data:z"
			}]
		}]
	}

	wol: {
		_
		#param: {
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
