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
		}

		#pod: {
			metadata: {
				annotations: {
					"bind-mount-options": "\(fact.bazarr_web_config):z"
				}
			}
			spec: {
				containers: [{
					image: "bazarr"
					name:  "web"
					volumeMounts: [{
						name:      "config"
						mountPath: "/config"
					}, {
						name:      "home"
						mountPath: "/home"
					}]
				}]
				volumes: [{
					name: "config"
					hostPath: {
						path: "\(fact.bazarr_web_config)"
						type: "Directory"
					}
				}, {
					name: "home"
					hostPath: {
						path: "\(fact.global_media)"
						type: "Directory"
					}
				}]
			}
		}
	}

	caddy: {
		_
		#param: {
			name: "caddy"
			secret: {
				Caddyfile: "\(fact.caddy_secret_caddyfile)"
			}
			volume: [
				"caddy_volume_config",
				"caddy_volume_data",
			]
		}
		#pod: {
			spec: {
				containers: [{
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
						name:      "caddyfile"
						readOnly:  true
						mountPath: "/etc/caddy/Caddyfile"
						subPath:   "Caddyfile"
					}]
				}]
				volumes: [{
					name: "config"
					persistentVolumeClaim: claimName: "caddy_volume_config"
				}, {
					name: "data"
					persistentVolumeClaim: claimName: "caddy_volume_data"
				}, {
					name: "caddyfile"
					secret: {
						secretName: "caddy-secret"
						items: [{
							key:  "Caddyfile"
							path: "Caddyfile"
						}]
					}
				}]
			}
		}
	}
}
