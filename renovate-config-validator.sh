#!/bin/bash
docker run --rm -it -w /tmp -v "$(pwd)":/tmp renovate/renovate renovate-config-validator
# docker run --rm -it -w /tmp -v "$(pwd)":/tmp renovate/renovate /bin/bash
