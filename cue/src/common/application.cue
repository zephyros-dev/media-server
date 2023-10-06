package applicationSet

import (
	core "k8s.io/api/core/v1"
)

[applicationName=_]: {
	#param: {
		name: string
		env: {
			string?: string
		}
		secret: {
			string?: string
		}
		volume: [...string]
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
		spec: containers: [{
			envFrom: [{
				secretRef: {
					name: "\(#param.name)-env"
				}}]}]
	}

	#env: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)-env"
		}
		type: "Opaque"
		stringData: {for k, v in #param.env {
			"\(k)": v
		}}
	}

	#secret: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)-secret"
		}
		type: "Opaque"
		stringData: {for k, v in #param.secret {
			"\(k)": v
		}}
	}

	#volume: [
		for volumeName in #param.volume {
			core.#PersistentVolumeClaim & {
				apiVersion: "v1"
				kind:       "PersistentVolumeClaim"
				metadata: {
					name: volumeName
				}
			}
		},
	]

	[
		#pod,
		#env,
		#secret,
	] + #volume
}
