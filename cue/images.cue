package main

// Pinned images, one per entry with a blank line in between so renovate bumps of
// neighbouring entries merge cleanly. Kept up to date by the regex manager in
// renovate.json; images with real build steps stay as Containerfiles instead
_image: {
	"actual": "docker.io/actualbudget/actual-server:26.10.0-alpine@sha256:67b1b5e9584e3e143b4f5c41e52b4506ed9cdd1072392d5ab5369f2d4fd0bffd"

	"audiobookshelf": "ghcr.io/advplyr/audiobookshelf:2.37.1@sha256:581d68b2a6fc7ebf58d81c878a9f387cbbc0d88ac9d37b298b9cee10168af85b"

	"bazarr": "ghcr.io/linuxserver/bazarr:latest@sha256:946dc8c5bb5331418eac60050cf40a63cb8f66ac039841dda493870e3559799c"

	"beszel": "docker.io/henrygd/beszel:0.21.0@sha256:6b39a8b64f9b15d00a25e7683e31a93c46161182a54f62713525107064e10599"

	"beszel-agent": "docker.io/henrygd/beszel-agent:0.21.0@sha256:f27b1aa2c68404bc5b9e1a2ab36653bd9b4ee14f6299862f09cd5051a4134767"

	"calibre": "ghcr.io/linuxserver/calibre:9.16.0@sha256:48c8a5ba2a20c303012b1d4b2815a2b99b362a634a571fbec101b85bfa203ba3"

	"calibre-dl": "ghcr.io/calibrain/calibre-web-automated-book-downloader:v1.4.0@sha256:4ef757349c3c7a7d90ba95b1e2a46ce4dd460a4776efbcf2aa1b1c476e7d5de5"

	"dashy": "ghcr.io/lissy93/dashy:4.8.7@sha256:689a9a88b2368cfb7646458d176edf7fa378ad02218ef0cc8ccb53e1a8a3edbf"

	"filebrowser": "ghcr.io/gtsteffaniak/filebrowser:2.1.2-beta@sha256:0ff80341ce8a9c1e3c5ac8ca319bdf9675092028b04ed97607bbfebc10810fff"

	"flaresolverr": "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"

	"immich-machine-learning": "ghcr.io/immich-app/immich-machine-learning:v3.3.3@sha256:73915f07e1f4289ba45b174c58443db74cef47ddf502613f475fc5e52458ea42"

	"immich-postgres": "ghcr.io/immich-app/postgres:18-vectorchord1.1.1@sha256:a20e21841b21b9c009daf572c844ffedfaef75fce51287bbf080edf171ef0834"

	"immich-redis": "docker.io/redis:8-alpine@sha256:3811787313eba226a2ef38658c6ccb91cd5e110edc89c37767de373120a0e5a0"

	"immich-server": "ghcr.io/immich-app/immich-server:v3.3.3@sha256:bae7664ff3aa4c2c1fcbdcdd86b40b105643c5f861f3e6a770fc760089f25862"

	"jdownloader": "docker.io/jlesage/jdownloader-2:v26.09.1@sha256:bd6cd2fdc72818f30207e677b33cd7f1b425048c4e7132624e541e99f992be4c"

	"jellyfin": "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112"

	"kavita": "ghcr.io/linuxserver/kavita:0.9.1@sha256:ded5717da004779e52bf51c1acd5ce345c9fe007a22fe97953235ec8072bc2ac"

	"koreader": "ghcr.io/zephyros-dev/koreader:v2026.03@sha256:b548495d87eaea0fa990f0e16577637f2502c95b9c1bd6157f2aa1ed03693aaa"

	"librespeed": "ghcr.io/linuxserver/librespeed:latest@sha256:05c1ca8215f958b674e8fa1c2ea43483efa54dae8f1dbe40c907af66821fdcae"

	"lidarr": "ghcr.io/linuxserver/lidarr:latest@sha256:d8549ff9ea29b4015c32257360652c1000c31ea471a2b3f0835ae77292faf35b"

	"miniflux": "ghcr.io/miniflux/miniflux:2.3.3-distroless@sha256:59e4e31b349f008ecd34b547f23498b1d8abc0c03d5f6d12bdb713ab7f7c04bf"

	"miniflux-postgres": "docker.io/postgres:18-alpine@sha256:83148c0bc09eac4d598b70a61e1404d0212b76c95c504bfd6c81a4c59ec91792"

	"musicgrabber": "docker.io/g33kphr33k/musicgrabber:4.3.1@sha256:94e99d5c8aad9a876912db2f6d2f5e17dcf2bb04c0b2b7a13811e005b828ba86"

	"navidrome": "ghcr.io/navidrome/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52"

	"nextcloud": "docker.io/nextcloud:35.0.2@sha256:301e07b7f661c122752cc2c01b76f15036a156f2b6d794c76621b7d0a6bb8a50"

	"nextcloud-office": "docker.io/collabora/code:26.04.5.1.1@sha256:bb8f3c9c5c9016045f25fccb5f0649be94469ebc7c7cc379f3576e470cccf33d"

	"nextcloud-postgres": "docker.io/postgres:18-alpine@sha256:83148c0bc09eac4d598b70a61e1404d0212b76c95c504bfd6c81a4c59ec91792"

	"nextcloud-redis": "docker.io/redis:8-alpine@sha256:3811787313eba226a2ef38658c6ccb91cd5e110edc89c37767de373120a0e5a0"

	"paperless-gotenberg": "docker.io/gotenberg/gotenberg:8.38@sha256:aa552cc115db488e0f0bcb07446aac13071ad51505b642c84bb894500907b42b"

	"paperless-postgres": "docker.io/postgres:18-alpine@sha256:83148c0bc09eac4d598b70a61e1404d0212b76c95c504bfd6c81a4c59ec91792"

	"paperless-redis": "docker.io/redis:8-alpine@sha256:3811787313eba226a2ef38658c6ccb91cd5e110edc89c37767de373120a0e5a0"

	"paperless-tika": "docker.io/apache/tika:3.3.1.0@sha256:90b7fa1dc018434075fce9e1d9b88b1e3d0ea6979d0cf86e116c79a8073ae973"

	"prowlarr": "ghcr.io/linuxserver/prowlarr:latest@sha256:b3b00047ed20f6ce2b16780145cb6a0acb51c9e28ea6aa6f5dcd33c7034f1797"

	"pymedusa": "docker.io/pymedusa/medusa:master@sha256:0caf2991d15030b99864158144903c1d2b5f4f9ff019ec4450c4f1cb33569857"

	"radarr": "ghcr.io/linuxserver/radarr:latest@sha256:ff4430fe2d6159b4dbaac9903acfecee5aa68dec8c929259e2f3114c63f7a09e"

	"samba": "ghcr.io/servercontainers/samba:smbd-only-latest@sha256:31b90ea7fe3258d30fccd971c85743b92694605f4b43dc8a4df23a202fced06a"

	"scrutiny": "ghcr.io/analogj/scrutiny:v0.9.5-omnibus@sha256:6ee271ee531458f134220ca8b2c5c8ccc2711a799c827fef953fa865d91e312f"

	"speedtest": "lscr.io/linuxserver/speedtest-tracker:1.15.0@sha256:1eeed2307699c083407bd4c1eb86f14d5179f9e1cd960f57d4cbab6f1f8b8a42"

	"syncthing": "docker.io/syncthing/syncthing:2.1.6@sha256:4d0281bdcb4ed9baf503d251d0544ddd856f49fce3f114056257ae172b7fb670"

	"timetagger": "ghcr.io/almarklein/timetagger:v26.1.3-nonroot@sha256:18a81afcb249142426fcff47bf9b54c343ca718a916f03d9722b84f8d7fafac6"

	"transmission": "ghcr.io/linuxserver/transmission:latest@sha256:d6caecad406774a18511be7bfa99ba5070c17a3bdd7a5d73091651841603273c"

	"trilium": "ghcr.io/triliumnext/trilium:v0.106.0@sha256:be93e82699b12950ac4e2e7b565ce092fe215b8dd6ddfc47921e37b49e6a0e8b"

	"wealthfolio": "ghcr.io/wealthfolio/wealthfolio:3.10.0@sha256:6dcf9019aee7ba0747344087365ea57846107943ff0e2718a9bee72a98e20f85"

	"wol": "ghcr.io/sameerdhoot/wolweb:latest@sha256:5cd2aa228bc68d9e52e71c92c2aa354cab15731838e3fee80796c5209b3783f7"
}
