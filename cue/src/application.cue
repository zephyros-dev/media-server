package application

import (
	"encoding/base64"
	"encoding/json"
	applicationSet "zephyros.dev/src/common:applicationSet"
	fact "zephyros.dev/tmp:fact"
)

applicationSet & {
	bazarr: {
		_
		#param: {
			name: "bazarr"
			env: {
				"PGID": fact.global_pgid
				"PUID": fact.global_puid
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
					content: "\(fact.caddy_secret_caddyfile)"
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
				"PGID": fact.global_pgid
				"PUID": fact.global_puid
			}
			volumes: {
				config: "\(fact.calibre_volume_config)/"
				books:  "\(fact.calibre_book)/"
				device: "/dev/dri"
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
					content: "\(fact.dashy_secret_config)"
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
}
