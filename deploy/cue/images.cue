package main

// Pinned images, one per entry with a blank line in between so renovate bumps of
// neighbouring entries merge cleanly. Kept up to date by the regex manager in
// renovate.json; images with real build steps stay as Containerfiles instead
_image: {
	"actual": "docker.io/actualbudget/actual-server:26.10.0-alpine@sha256:67b1b5e9584e3e143b4f5c41e52b4506ed9cdd1072392d5ab5369f2d4fd0bffd"

	"audiobookshelf": "ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa"

	"bazarr": "ghcr.io/linuxserver/bazarr:latest@sha256:9a625883f054e722795affe5e3ca71057e6ed817ecdf99f4a99624346fcc509c"

	"beszel": "docker.io/henrygd/beszel:0.21.1@sha256:8514a69d9bbbcb74f371a3205561ee231fc0289739cea64e8131f341d695b770"

	"beszel-agent": "docker.io/henrygd/beszel-agent:0.21.1@sha256:cb6868012964d7a68debaa2c84bb72285e5f08531e81f506bd4c493bf052e41c"

	"calibre": "ghcr.io/linuxserver/calibre:9.17.0@sha256:b198fc03a6abc6be7e251a9958e50e74634b00e447c7b25e92c191c8077ba378"

	"calibre-dl": "ghcr.io/calibrain/calibre-web-automated-book-downloader:v1.5.1@sha256:acfa46b8be80f1e2f084a7703ff027ab274397feb24006114e92c05c140b62c3"

	"dashy": "ghcr.io/lissy93/dashy:4.9.8@sha256:a20a506fa6d77c06be2f4a83f7e7267d6ccd9fde3fd6d7f6aad7a0969ad0fe4a"

	"filebrowser": "ghcr.io/gtsteffaniak/filebrowser:2.1.3-beta@sha256:c91fbf4b442ba14f5d45f8687b74cf71477e36a1a8118b5d0643522dcf78f73c"

	"flaresolverr": "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"

	"immich-machine-learning": "ghcr.io/immich-app/immich-machine-learning:v3.3.5@sha256:5b28c9352c8374b8a1ed96fbdd8d6755fea6e43510ec43fdf6538aa02ea40f56"

	"immich-postgres": "ghcr.io/immich-app/postgres:18-vectorchord1.1.1@sha256:a20e21841b21b9c009daf572c844ffedfaef75fce51287bbf080edf171ef0834"

	"immich-redis": "docker.io/redis:8-alpine@sha256:47b08295737773de3b711fb86f13ae802f5074e96a9a2d29f5f80164ac08c046"

	"immich-server": "ghcr.io/immich-app/immich-server:v3.3.5@sha256:485d546a2e31d6a8b4db8423fcba5c109de8c218d93410af115fd1ccfc4352a6"

	"jdownloader": "docker.io/jlesage/jdownloader-2:v26.09.1@sha256:bd6cd2fdc72818f30207e677b33cd7f1b425048c4e7132624e541e99f992be4c"

	"jellyfin": "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112"

	"kavita": "ghcr.io/linuxserver/kavita:0.9.1@sha256:34dddd2e79854772b788e5847f1702444b11118bbeabd0a5590f57e15346222b"

	"koreader": "ghcr.io/zephyros-dev/koreader:v2026.03@sha256:ba11862fa8f76a6e796fb42bc077f1d4660f8733467be5a68978b8912c0f74d9"

	"librespeed": "ghcr.io/linuxserver/librespeed:latest@sha256:8f383ce2954aca618347387e255769b9a927c549daa3f29c12a18b418acb5193"

	"lidarr": "ghcr.io/linuxserver/lidarr:latest@sha256:9fddcf5c613361edfce390d4e6b7c364282e71e90a40ce7793077fed788f6e63"

	"miniflux": "ghcr.io/miniflux/miniflux:2.3.4-distroless@sha256:4a457e73b6c298bd44f42b38d744afb8a08d3b94318f0c636162d0b35ce0f217"

	"miniflux-postgres": "docker.io/postgres:18-alpine@sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5"

	"musicgrabber": "docker.io/g33kphr33k/musicgrabber:4.4.3@sha256:ad641f514508cd24c2c7e92f5d91f05d60a4cf7767feee8b76ecbc7509284390"

	"navidrome": "ghcr.io/navidrome/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52"

	"nextcloud": "docker.io/nextcloud:35.0.2@sha256:0347adaf2fa460aa9589f8c2b1ed246788d11a72ad9918d55ca288f3137fe5ca"

	"nextcloud-office": "docker.io/collabora/code:26.04.5.2.1@sha256:c7415b963e32eb0986a562583f154d36d3d7a461e1ddfb660a95e87094328acb"

	"nextcloud-postgres": "docker.io/postgres:18-alpine@sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5"

	"nextcloud-redis": "docker.io/redis:8-alpine@sha256:47b08295737773de3b711fb86f13ae802f5074e96a9a2d29f5f80164ac08c046"

	"paperless-gotenberg": "docker.io/gotenberg/gotenberg:8.39@sha256:13672f317b443c793e972b1bd2155ec62a3e7b6891b411e8196442cc053ee5f5"

	"paperless-postgres": "docker.io/postgres:18-alpine@sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5"

	"paperless-redis": "docker.io/redis:8-alpine@sha256:47b08295737773de3b711fb86f13ae802f5074e96a9a2d29f5f80164ac08c046"

	"paperless-tika": "docker.io/apache/tika:3.3.3.0@sha256:326b238b37904c94ff61fed87afe0af72e6a29fa715933b10af97b7d56f1d4cb"

	"prowlarr": "ghcr.io/linuxserver/prowlarr:latest@sha256:04be30163fbaf48d6aeee7b5893c9f6614ffbad6d853971df0d6dcdf01c7f104"

	"pymedusa": "docker.io/pymedusa/medusa:master@sha256:0caf2991d15030b99864158144903c1d2b5f4f9ff019ec4450c4f1cb33569857"

	"radarr": "ghcr.io/linuxserver/radarr:latest@sha256:084b3b2ab1d0ef930660727259546a241f2bdf67c9ed085d54bf1486a6887c9b"

	"samba": "ghcr.io/servercontainers/samba:smbd-only-latest@sha256:31b90ea7fe3258d30fccd971c85743b92694605f4b43dc8a4df23a202fced06a"

	"scrutiny": "ghcr.io/analogj/scrutiny:v0.9.5-omnibus@sha256:6ee271ee531458f134220ca8b2c5c8ccc2711a799c827fef953fa865d91e312f"

	"slskd": "docker.io/slskd/slskd:0.26.2@sha256:d0963a3e5b16facd295bf4f2156dad0182f246b1b21a032cae12f5494c694843"

	"speedtest": "lscr.io/linuxserver/speedtest-tracker:1.15.1@sha256:8d3c2826b708c18be7fb46c1afebc6bb3b1ab7c519473df1be89f5ecaa8bb31f"

	"syncthing": "docker.io/syncthing/syncthing:2.1.7@sha256:2b71da7c0d0a91a6ae5285ad079226fecc0a365d08b27720e1f7037b018f7546"

	"timetagger": "ghcr.io/almarklein/timetagger:v26.1.3-nonroot@sha256:18a81afcb249142426fcff47bf9b54c343ca718a916f03d9722b84f8d7fafac6"

	"transmission": "ghcr.io/linuxserver/transmission:latest@sha256:ebefa8cb3e36a8ce667b7739f51b86c24e9fd07f367e9fee9f21df48ea4e6542"

	"trilium": "ghcr.io/triliumnext/trilium:v0.106.1@sha256:d87d810fdcb549db65710a40933acaa16bc75c9426a9164c547f7ba95592941b"

	"wealthfolio": "ghcr.io/wealthfolio/wealthfolio:3.11.0@sha256:3e996e9b3fbf9c945eca89e7b89eb03e0966beb1c51b977ccccb811f76ae2994"

	"wol": "ghcr.io/sameerdhoot/wolweb:latest@sha256:5cd2aa228bc68d9e52e71c92c2aa354cab15731838e3fee80796c5209b3783f7"
}
