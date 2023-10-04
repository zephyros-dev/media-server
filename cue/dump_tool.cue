package foo

import (
	"encoding/yaml"
	"tool/cli"
	application "zephyros.dev/src:application"
)

_applicationName: string @tag(applicationName)

command: dump: {
	print: cli.Print & {
		text: yaml.MarshalStream(application[_applicationName])
	}
}
