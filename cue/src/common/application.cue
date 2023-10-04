package applicationSet

import (
	fact "zephyros.dev/tmp:fact"
	core "k8s.io/api/core/v1"
)

[applicationName=_]: {
	#param: {
		name: string
		env: {
			string?: string
		}
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

	#envSecret: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)-env"
		}
		type:       "Opaque"
		stringData: {
			TZ: fact.global_timezone
		} & {for k, v in #param.env {
			"\(k)": v
		}}
	}

	// #volume: null
	// #secret: null
	[
		#pod,
		#envSecret,
		// #volume,
		// #secret,
	]
}
