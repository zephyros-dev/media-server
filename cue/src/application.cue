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
						mountPath: "/config"
						name:      "config"
					}, {
						mountPath: "/home"
						name:      "home"
					}]
				}]
				volumes: [{
					hostPath: {
						path: "\(fact.bazarr_web_config)"
						type: "Directory"
					}
					name: "config"
				}, {
					hostPath: {
						path: "\(fact.global_media)"
						type: "Directory"
					}
					name: "home"
				}]
			}
		}
	}
}
