package main

// Pinned images, one per entry with a blank line in between so renovate bumps of
// neighbouring entries merge cleanly. Kept up to date by the regex manager in
// renovate.json; images with real build steps stay as Containerfiles instead
_image: {
	"actual": "docker.io/actualbudget/actual-server:26.11.0-alpine@sha256:01ac24a51c6f585aba287c1bf1e96fcda46ab16a05952817c637415213251aa3"

	"audiobookshelf": "ghcr.io/advplyr/audiobookshelf:2.37.2@sha256:b897c33f05972fb1bf484f7487bc878fa91ec8691335c1db6e2929c3a7658efa"

	"bazarr": "ghcr.io/linuxserver/bazarr:latest@sha256:832820dec70bce9e912c6eee7a95baf6551e03dbc63325a7208daaa455423752"

	"beszel": "docker.io/henrygd/beszel:0.21.1@sha256:8514a69d9bbbcb74f371a3205561ee231fc0289739cea64e8131f341d695b770"

	"beszel-agent": "docker.io/henrygd/beszel-agent:0.21.1@sha256:cb6868012964d7a68debaa2c84bb72285e5f08531e81f506bd4c493bf052e41c"

	"calibre": "ghcr.io/linuxserver/calibre:9.18.0@sha256:5b5c0cba9fa70d65b5d92da73b8d486d4acf0d03ea648062586c4e3789700d89"

	"calibre-dl": "ghcr.io/calibrain/calibre-web-automated-book-downloader:v1.6.2@sha256:0b400a5d58951b35bfede3d9943b632551259c31e130316fe56c5cc0e2e4faea"

	"dashy": "ghcr.io/lissy93/dashy:4.9.17@sha256:c3b70180ab12286c8127437431da04fa60586d78b77e68a67bc2d081c6dce03f"

	"filebrowser": "ghcr.io/gtsteffaniak/filebrowser:2.1.4-beta@sha256:d7ae18aa7e8ff81695a35a2c1af399f0c437339241ad90be446c5e71314c0c31"

	"flaresolverr": "ghcr.io/flaresolverr/flaresolverr:latest@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767"

	"immich-machine-learning": "ghcr.io/immich-app/immich-machine-learning:v3.3.6@sha256:14367bfb374b8576ddf49abd67c5ca0190a4c7fcf6303cdad65d7f7bf1a50bc2"

	"immich-postgres": "ghcr.io/immich-app/postgres:18-vectorchord1.1.1@sha256:b427de4534e09120dd32cba873a2e88f9d026db7a0d813b226c5421c30669546"

	"immich-redis": "docker.io/redis:8-alpine@sha256:71885d8cc6e42f2bc0aa2eb853bfc4be200b5108a46ac50e117ae1df0531fb80"

	"immich-server": "ghcr.io/immich-app/immich-server:v3.3.6@sha256:e1981983b1c13f6024b57d72e7ecae3342eed1581201ab09fb248932d86c593a"

	"jdownloader": "docker.io/jlesage/jdownloader-2:v26.09.1@sha256:bd6cd2fdc72818f30207e677b33cd7f1b425048c4e7132624e541e99f992be4c"

	"jellyfin": "ghcr.io/jellyfin/jellyfin:10.11.11@sha256:45f648c382a0c8b552582fcea40e95cb17c5d475473a891cba0eb7523fb92112"

	"kavita": "ghcr.io/linuxserver/kavita:0.9.1@sha256:f75ad02b1de486ad8eaedd28e6f83e9d93929aa15aaba264fdacf070bf7194d5"

	"koreader": "ghcr.io/zephyros-dev/koreader:v2026.07.1@sha256:a7c37cd2c5453b1642d6588ccdf89ff630d64b6918f17d6b896be608e5918fdb"

	"librespeed": "ghcr.io/linuxserver/librespeed:latest@sha256:98ddd2a1357f961392789e078d5511dd09cb7461f87a26e6fc9cfb6e69ba96a4"

	"lidarr": "ghcr.io/linuxserver/lidarr:latest@sha256:d5707cfe084da21a3864c7ef0edd9c0543b5e26c79c551f84dad5ef8683af8c7"

	"miniflux": "ghcr.io/miniflux/miniflux:2.3.5-distroless@sha256:c826edc9c2284a8181e297d22a5ade1482bd9a8a4beabb2b6356bd22ce731310"

	"miniflux-postgres": "docker.io/postgres:18-alpine@sha256:123b17998ccaf47e53b502e8c6a1e79afd8f579c6f3eec83c563da026f957395"

	"mood-analyzer": "ghcr.io/rflundgren/navidrome-mood-plugin:v0.10.1@sha256:fce6a9b890aec30adaa86e3c7dfa246ced58cef711f590a6c636ea88b14db118"

	"musicgrabber": "docker.io/g33kphr33k/musicgrabber:4.5.3@sha256:fb9e2e45f37e14904d238af42035f44635d92eb270b0fd967cd3ab79b674a188"

	"navidrome": "ghcr.io/navidrome/navidrome:0.64.2@sha256:38dc2727bfcfd5ede290f8ada114fc90368146f265ae4701ddddbcbe2a44ee52"

	"nextcloud": "docker.io/nextcloud:35.0.2@sha256:786c102155d2717ba0f53a62b3fdd7a1354edc48e800b94dbe32294d9a5752a2"

	"nextcloud-office": "docker.io/collabora/code:26.04.6.1.1@sha256:95f29f1c0a1778999125f53f058d968fe0afb37c95e32ebfb9f3444140faebd2"

	"nextcloud-postgres": "docker.io/postgres:18-alpine@sha256:123b17998ccaf47e53b502e8c6a1e79afd8f579c6f3eec83c563da026f957395"

	"nextcloud-redis": "docker.io/redis:8-alpine@sha256:71885d8cc6e42f2bc0aa2eb853bfc4be200b5108a46ac50e117ae1df0531fb80"

	"paperless-gotenberg": "docker.io/gotenberg/gotenberg:8.40@sha256:53073e798c8ef39ea2187e44cb67bab77894ea2509100b94c4fe3b461f7b2996"

	"paperless-postgres": "docker.io/postgres:18-alpine@sha256:123b17998ccaf47e53b502e8c6a1e79afd8f579c6f3eec83c563da026f957395"

	"paperless-redis": "docker.io/redis:8-alpine@sha256:71885d8cc6e42f2bc0aa2eb853bfc4be200b5108a46ac50e117ae1df0531fb80"

	"paperless-tika": "docker.io/apache/tika:3.3.3.0@sha256:326b238b37904c94ff61fed87afe0af72e6a29fa715933b10af97b7d56f1d4cb"

	"prowlarr": "ghcr.io/linuxserver/prowlarr:latest@sha256:431d7efebcef466e56adaa40a7a2fa2b0e85159a037b8bf465eaadbf0cf5bedf"

	"pymedusa": "docker.io/pymedusa/medusa:master@sha256:0caf2991d15030b99864158144903c1d2b5f4f9ff019ec4450c4f1cb33569857"

	"radarr": "ghcr.io/linuxserver/radarr:latest@sha256:51a9ac2a9eb47afc833541e5fd6c11b86eb9f810694c22fa2429e3078e9194b2"

	"samba": "ghcr.io/servercontainers/samba:smbd-only-latest@sha256:31b90ea7fe3258d30fccd971c85743b92694605f4b43dc8a4df23a202fced06a"

	"scrutiny": "ghcr.io/analogj/scrutiny:v0.10.0-omnibus@sha256:90062edac57a2bd891d641344184f5f730f19394b1124f6fc53904a3d8cb21c2"

	"slskd": "docker.io/slskd/slskd:0.26.2@sha256:d0963a3e5b16facd295bf4f2156dad0182f246b1b21a032cae12f5494c694843"

	"speedtest": "lscr.io/linuxserver/speedtest-tracker:1.15.1@sha256:3851956ddff5b230a096c5414bfdf005e91aff3af48da9bcb4327dc41eff49e4"

	"syncthing": "docker.io/syncthing/syncthing:2.1.7@sha256:2b71da7c0d0a91a6ae5285ad079226fecc0a365d08b27720e1f7037b018f7546"

	"timetagger": "ghcr.io/almarklein/timetagger:v26.1.3-nonroot@sha256:18a81afcb249142426fcff47bf9b54c343ca718a916f03d9722b84f8d7fafac6"

	"transmission": "ghcr.io/linuxserver/transmission:latest@sha256:aaf349cd859ca9d5f34f394c56b8097c267a513283698adc4d07ee61d7cb1a85"

	"trilium": "ghcr.io/triliumnext/trilium:v0.107.0@sha256:739ba0f0488f506549f7c21dc9e792decd99382cc759f01d5ec1abba32e87da8"

	"wealthfolio": "ghcr.io/wealthfolio/wealthfolio:3.12.0@sha256:5790528fcd9795b571176cad78bcca09e3fa5875ec20968356586939e154c3cb"

	"wol": "ghcr.io/sameerdhoot/wolweb:latest@sha256:5cd2aa228bc68d9e52e71c92c2aa354cab15731838e3fee80796c5209b3783f7"
}
