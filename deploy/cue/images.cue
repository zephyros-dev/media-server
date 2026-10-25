package main

// Pinned images, one per entry with a blank line in between so renovate bumps of
// neighbouring entries merge cleanly. Kept up to date by the regex manager in
// renovate.json; images with real build steps stay as Containerfiles instead
_image: {
	"actual": "docker.io/actualbudget/actual-server:26.10.0-alpine@sha256:67b1b5e9584e3e143b4f5c41e52b4506ed9cdd1072392d5ab5369f2d4fd0bffd"

	"audiobookshelf": "ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa"

	"bazarr": "ghcr.io/linuxserver/bazarr:latest@sha256:946dc8c5bb5331418eac60050cf40a63cb8f66ac039841dda493870e3559799c"

	"beszel": "docker.io/henrygd/beszel:0.21.1@sha256:8514a69d9bbbcb74f371a3205561ee231fc0289739cea64e8131f341d695b770"

	"beszel-agent": "docker.io/henrygd/beszel-agent:0.21.1@sha256:cb6868012964d7a68debaa2c84bb72285e5f08531e81f506bd4c493bf052e41c"

	"calibre": "ghcr.io/linuxserver/calibre:9.16.0@sha256:2b931709295ca59808520428b05e0a2aec8695268e96f8baf76359da0e9c0f5c"

	"calibre-dl": "ghcr.io/calibrain/calibre-web-automated-book-downloader:v1.4.0@sha256:4ef757349c3c7a7d90ba95b1e2a46ce4dd460a4776efbcf2aa1b1c476e7d5de5"

	"dashy": "ghcr.io/lissy93/dashy:4.8.7@sha256:689a9a88b2368cfb7646458d176edf7fa378ad02218ef0cc8ccb53e1a8a3edbf"

	"filebrowser": "ghcr.io/gtsteffaniak/filebrowser:2.1.3-beta@sha256:c91fbf4b442ba14f5d45f8687b74cf71477e36a1a8118b5d0643522dcf78f73c"

	"flaresolverr": "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"

	"immich-machine-learning": "ghcr.io/immich-app/immich-machine-learning:v3.3.5@sha256:5b28c9352c8374b8a1ed96fbdd8d6755fea6e43510ec43fdf6538aa02ea40f56"

	"immich-postgres": "ghcr.io/immich-app/postgres:18-vectorchord1.1.1@sha256:a20e21841b21b9c009daf572c844ffedfaef75fce51287bbf080edf171ef0834"

	"immich-redis": "docker.io/redis:8-alpine@sha256:0bf6577d7774e592b29d093e3ac9390eb91e13d72c21e506afce736de5e0eeb0"

	"immich-server": "ghcr.io/immich-app/immich-server:v3.3.5@sha256:485d546a2e31d6a8b4db8423fcba5c109de8c218d93410af115fd1ccfc4352a6"

	"jdownloader": "docker.io/jlesage/jdownloader-2:v26.09.1@sha256:bd6cd2fdc72818f30207e677b33cd7f1b425048c4e7132624e541e99f992be4c"

	"jellyfin": "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112"

	"kavita": "ghcr.io/linuxserver/kavita:0.9.1@sha256:ded5717da004779e52bf51c1acd5ce345c9fe007a22fe97953235ec8072bc2ac"

	"koreader": "ghcr.io/zephyros-dev/koreader:v2026.03@sha256:ba11862fa8f76a6e796fb42bc077f1d4660f8733467be5a68978b8912c0f74d9"

	"librespeed": "ghcr.io/linuxserver/librespeed:latest@sha256:0f85aac620b60a2566049f95d085fd2b044c720abfe88d1f1e14496ea0496833"

	"lidarr": "ghcr.io/linuxserver/lidarr:latest@sha256:d8549ff9ea29b4015c32257360652c1000c31ea471a2b3f0835ae77292faf35b"

	"miniflux": "ghcr.io/miniflux/miniflux:2.3.4-distroless@sha256:4a457e73b6c298bd44f42b38d744afb8a08d3b94318f0c636162d0b35ce0f217"

	"miniflux-postgres": "docker.io/postgres:18-alpine@sha256:898c60cb390d1085bc97bdd6a1ae968757421df394b071848b52b1c09c89d6a5"

	"musicgrabber": "docker.io/g33kphr33k/musicgrabber:4.3.1@sha256:94e99d5c8aad9a876912db2f6d2f5e17dcf2bb04c0b2b7a13811e005b828ba86"

	"navidrome": "ghcr.io/navidrome/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52"

	"nextcloud": "docker.io/nextcloud:35.0.2@sha256:89af7ee7a96ff5e9668280566209268ae6b2d02327f6ef6d56f6d68228cf9431"

	"nextcloud-office": "docker.io/collabora/code:26.04.5.2.1@sha256:c7415b963e32eb0986a562583f154d36d3d7a461e1ddfb660a95e87094328acb"

	"nextcloud-postgres": "docker.io/postgres:18-alpine@sha256:898c60cb390d1085bc97bdd6a1ae968757421df394b071848b52b1c09c89d6a5"

	"nextcloud-redis": "docker.io/redis:8-alpine@sha256:0bf6577d7774e592b29d093e3ac9390eb91e13d72c21e506afce736de5e0eeb0"

	"paperless-gotenberg": "docker.io/gotenberg/gotenberg:8.38@sha256:aa552cc115db488e0f0bcb07446aac13071ad51505b642c84bb894500907b42b"

	"paperless-postgres": "docker.io/postgres:18-alpine@sha256:898c60cb390d1085bc97bdd6a1ae968757421df394b071848b52b1c09c89d6a5"

	"paperless-redis": "docker.io/redis:8-alpine@sha256:0bf6577d7774e592b29d093e3ac9390eb91e13d72c21e506afce736de5e0eeb0"

	"paperless-tika": "docker.io/apache/tika:3.3.3.0@sha256:326b238b37904c94ff61fed87afe0af72e6a29fa715933b10af97b7d56f1d4cb"

	"prowlarr": "ghcr.io/linuxserver/prowlarr:latest@sha256:b3b00047ed20f6ce2b16780145cb6a0acb51c9e28ea6aa6f5dcd33c7034f1797"

	"pymedusa": "docker.io/pymedusa/medusa:master@sha256:0caf2991d15030b99864158144903c1d2b5f4f9ff019ec4450c4f1cb33569857"

	"radarr": "ghcr.io/linuxserver/radarr:latest@sha256:fc0ae3c50f8128b97e84381903ec8d6845c3a569641cb7117c124376cccb57c1"

	"samba": "ghcr.io/servercontainers/samba:smbd-only-latest@sha256:31b90ea7fe3258d30fccd971c85743b92694605f4b43dc8a4df23a202fced06a"

	"scrutiny": "ghcr.io/analogj/scrutiny:v0.9.5-omnibus@sha256:6ee271ee531458f134220ca8b2c5c8ccc2711a799c827fef953fa865d91e312f"

	"speedtest": "lscr.io/linuxserver/speedtest-tracker:1.15.1@sha256:8d3c2826b708c18be7fb46c1afebc6bb3b1ab7c519473df1be89f5ecaa8bb31f"

	"syncthing": "docker.io/syncthing/syncthing:2.1.7@sha256:2b71da7c0d0a91a6ae5285ad079226fecc0a365d08b27720e1f7037b018f7546"

	"timetagger": "ghcr.io/almarklein/timetagger:v26.1.3-nonroot@sha256:18a81afcb249142426fcff47bf9b54c343ca718a916f03d9722b84f8d7fafac6"

	"transmission": "ghcr.io/linuxserver/transmission:latest@sha256:55aaeedf9fc354d34136387e15ee0ba4679096f20398dd2875867e5cd5cf8be5"

	"trilium": "ghcr.io/triliumnext/trilium:v0.106.1@sha256:d87d810fdcb549db65710a40933acaa16bc75c9426a9164c547f7ba95592941b"

	"wealthfolio": "ghcr.io/wealthfolio/wealthfolio:3.10.0@sha256:6dcf9019aee7ba0747344087365ea57846107943ff0e2718a9bee72a98e20f85"

	"wol": "ghcr.io/sameerdhoot/wolweb:latest@sha256:5cd2aa228bc68d9e52e71c92c2aa354cab15731838e3fee80796c5209b3783f7"
}
