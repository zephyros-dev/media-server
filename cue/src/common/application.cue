package applicationSet

import (
	core "k8s.io/api/core/v1"
)

[applicationName=_]: {
	#param: {
		name: string
		env: string?: string
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
			containers: [{
				envFrom: [{
					secretRef: {
						name: "\(#param.name)-env"
					}}]}]
			volumes: [ for k, v in #param.volumes {
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
			}] + [ for k, v in #param.secret if v.type == "file" {
				name: k
				secret: {
					secretName: "\(#param.name)-file"
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

	#env: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)-env"
		}
		type:       "Opaque"
		stringData: {
			for k, v in #param.env {
				"\(k)": v
			}} & {
			for k, v in #param.secret if v.type == "env" {
				"\(k)": v.content
			}
		}
	}

	#secret: core.#Secret & {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name: "\(#param.name)-file"
		}
		type: "Opaque"
		stringData: {
			for k, v in #param.secret if v.type == "file" {
				"\(k)": v.content
			}}
	}

	#volume: [ for k, v in #param.volumes if v !~ "^\/" {
		core.#PersistentVolumeClaim & {
			apiVersion: "v1"
			kind:       "PersistentVolumeClaim"
			metadata: {
				name: v
			}
		}
	}]

	[#pod, #env, #secret] + #volume
}
