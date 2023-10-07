package application

import (
	fact "zephyros.dev/tmp:fact"
	applicationSet "zephyros.dev/src/common:applicationSet"
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
				config: "\(fact.bazarr_web_config)"
				home:   "\(fact.global_media)"
			}
		}
		#pod: spec: containers: [{
			image: "bazarr"
			name:  "web"
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
			image: "caddy"
			name:  "instance"
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
				config: "\(fact.calibre_volume_config)"
				books:  "\(fact.calibre_book)"
				device: "/dev/dri"
			}
		}

		#pod: spec: containers: [{
			image: "calibre"
			name:  "web"
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
			image: "dashy"
			name:  "web"
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
}
