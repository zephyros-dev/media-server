package main

// Pinned images, one per entry with a blank line in between so renovate bumps of
// neighbouring entries merge cleanly. Kept up to date by the regex manager in
// renovate.json; images with real build steps stay as Containerfiles instead
_image: {
	"actual": "docker.io/actualbudget/actual-server:26.11.0-alpine@sha256:01ac24a51c6f585aba287c1bf1e96fcda46ab16a05952817c637415213251aa3"

	"audiobookshelf": "ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa"

	"bazarr": "ghcr.io/linuxserver/bazarr:latest@sha256:e0c5d45965242830c5eeddaafe9ae2b5e8ca3f6c01ecda9ee9364f550921dc50"

	"beszel": "docker.io/henrygd/beszel:0.21.2@sha256:b0be90bd4aee2993fde763032a5098ce4386fba43cfe5031ec017b8d9e8c97a2"

	"beszel-agent": "docker.io/henrygd/beszel-agent:0.21.2@sha256:343254226ae57a5cc6f8c23c755b1464730aba2abc7043116a2e222711ec6e1a"

	"calibre": "ghcr.io/linuxserver/calibre:9.18.0@sha256:dbaefbf648b2197bd25d783830b6fbe1be0da8a0cb5d837ddc9973ebc6e6e3d2"

	"calibre-dl": "ghcr.io/calibrain/calibre-web-automated-book-downloader:v1.7.0@sha256:6544e02595271b0267b9acda58fa7f3db6f14942bece51b7aadfe4000cf34f1c"

	"dashy": "ghcr.io/lissy93/dashy:4.9.18@sha256:4549ee87a34db28693062184589ca5e82277bed9025b3a0b542003608361023c"

	"filebrowser": "ghcr.io/gtsteffaniak/filebrowser:2.1.5-beta@sha256:ad68b009f69e66d65a66d5f83f67b9bb5cae588614ac415dc0b23132b939f177"

	"flaresolverr": "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"

	"immich-machine-learning": "ghcr.io/immich-app/immich-machine-learning:v3.4.1@sha256:8adebf414256f6e4f837bfbb66fa94f14f4da7260e3a1d65cbba49e4e35d8764"

	"immich-postgres": "ghcr.io/immich-app/postgres:18-vectorchord1.1.1@sha256:f7388adc1e3414800a71506528917f4f5615249f5fe7a872b1e1431e01b72ad7"

	"immich-redis": "docker.io/redis:8-alpine@sha256:5af80107c1eeecb484a2269b80a26d12bfa6521787da4663bd9f19f60a163483"

	"immich-server": "ghcr.io/immich-app/immich-server:v3.4.1@sha256:7c489add298fc2f92cda4c777de6462aa206877e04087b815f62c7664af0b53b"

	"jdownloader": "docker.io/jlesage/jdownloader-2:v26.09.1@sha256:bd6cd2fdc72818f30207e677b33cd7f1b425048c4e7132624e541e99f992be4c"

	"jellyfin": "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112"

	"kavita": "ghcr.io/linuxserver/kavita:0.9.1@sha256:f75ad02b1de486ad8eaedd28e6f83e9d93929aa15aaba264fdacf070bf7194d5"

	"knightloader": "ghcr.io/junkerderprovinz/knightloader:2.8.3@sha256:be048fddd8bf1541b22219935d9292a0146f2615cb8b5a7fece9c098c91e6886"

	"koreader": "ghcr.io/zephyros-dev/koreader:v2026.07.1@sha256:205b602a438888da504eddd54b5a8b640c28059016cf64de6adcb15403839d2b"

	"librespeed": "ghcr.io/linuxserver/librespeed:latest@sha256:fa0ce663af2ecef06c143db770c9f46c60738c64bd9cc98ea36018fff841012a"

	"lidarr": "ghcr.io/linuxserver/lidarr:latest@sha256:8fb40ada166dd1880cb1b166df5bcbb081107523f20ab60df05c313e2052a467"

	"miniflux": "ghcr.io/miniflux/miniflux:2.3.5-distroless@sha256:c826edc9c2284a8181e297d22a5ade1482bd9a8a4beabb2b6356bd22ce731310"

	"miniflux-postgres": "docker.io/postgres:18-alpine@sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71"

	"mood-analyzer": "ghcr.io/rflundgren/navidrome-mood-plugin:v0.10.1@sha256:fce6a9b890aec30adaa86e3c7dfa246ced58cef711f590a6c636ea88b14db118"

	"musicgrabber": "docker.io/g33kphr33k/musicgrabber:dev@sha256:07bb56020a0dddc30c52ac08b999f831189db5a6ac77d4a19f5516b40a6a541b"

	"navidrome": "ghcr.io/navidrome/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52"

	"nextcloud": "docker.io/nextcloud:35.0.3@sha256:f44180601f18e7664557232b4c5edb0eb4a82d649c05b93313f4e15909553d42"

	"nextcloud-office": "docker.io/collabora/code:26.04.6.1.1@sha256:95f29f1c0a1778999125f53f058d968fe0afb37c95e32ebfb9f3444140faebd2"

	"nextcloud-postgres": "docker.io/postgres:18-alpine@sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71"

	"nextcloud-redis": "docker.io/redis:8-alpine@sha256:5af80107c1eeecb484a2269b80a26d12bfa6521787da4663bd9f19f60a163483"

	"paperless-gotenberg": "docker.io/gotenberg/gotenberg:9.5@sha256:a0f596c2aeee6391c24ccf2953737971f13976b14d4240525a447f209185e2c8"

	"paperless-postgres": "docker.io/postgres:18-alpine@sha256:0115267ab5a509022df9319c77be365cef335adb71556c75f60f5360ee247e71"

	"paperless-redis": "docker.io/redis:8-alpine@sha256:5af80107c1eeecb484a2269b80a26d12bfa6521787da4663bd9f19f60a163483"

	"paperless-tika": "docker.io/apache/tika:3.3.3.0@sha256:326b238b37904c94ff61fed87afe0af72e6a29fa715933b10af97b7d56f1d4cb"

	"prowlarr": "ghcr.io/linuxserver/prowlarr:latest@sha256:45117ba8439e2337a92ffe38a451a4dafc0be771754d05d88cdf102419d09646"

	"pymedusa": "docker.io/pymedusa/medusa:master@sha256:0caf2991d15030b99864158144903c1d2b5f4f9ff019ec4450c4f1cb33569857"

	"radarr": "ghcr.io/linuxserver/radarr:latest@sha256:044788f5508b7f67a3e0368cdd142c77c4d4cd5aec2efaba53e1a68b6b6231e7"

	"samba": "ghcr.io/servercontainers/samba:smbd-only-latest@sha256:31b90ea7fe3258d30fccd971c85743b92694605f4b43dc8a4df23a202fced06a"

	"scrutiny": "ghcr.io/analogj/scrutiny:v0.10.0-omnibus@sha256:90062edac57a2bd891d641344184f5f730f19394b1124f6fc53904a3d8cb21c2"

	"slskd": "docker.io/slskd/slskd:0.26.2@sha256:d0963a3e5b16facd295bf4f2156dad0182f246b1b21a032cae12f5494c694843"

	"speedtest": "lscr.io/linuxserver/speedtest-tracker:1.15.1@sha256:b7833e43bcf53859efd08605a48740a5cfa741916019373e4dbe730fc59bedf0"

	"syncthing": "docker.io/syncthing/syncthing:2.1.7@sha256:2b71da7c0d0a91a6ae5285ad079226fecc0a365d08b27720e1f7037b018f7546"

	"timetagger": "ghcr.io/almarklein/timetagger:v26.1.3-nonroot@sha256:18a81afcb249142426fcff47bf9b54c343ca718a916f03d9722b84f8d7fafac6"

	"transmission": "ghcr.io/linuxserver/transmission:latest@sha256:5baf08cd73a566699f35baad3c4a84ba7d7057220566c5fb29969bf2292dc2ff"

	"trilium": "ghcr.io/triliumnext/trilium:v0.107.0@sha256:739ba0f0488f506549f7c21dc9e792decd99382cc759f01d5ec1abba32e87da8"

	"wealthfolio": "ghcr.io/wealthfolio/wealthfolio:3.13.0@sha256:6600feaa06910a35854bc07a4cdf943a29b4a7a443190912e3d3c02288533ed2"

	"wol": "ghcr.io/sameerdhoot/wolweb:latest@sha256:5cd2aa228bc68d9e52e71c92c2aa354cab15731838e3fee80796c5209b3783f7"
}
