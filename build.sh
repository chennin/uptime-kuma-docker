#!/bin/bash
export CONT_LATEST="${REGISTRY}/${IMAGE}"
echo $CONT_LATEST
exit
export DEBIAN_FRONTEND=noninteractive
export STORAGE_DRIVER=vfs
export BUILDAH_ISOLATION=chroot
cd $(dirname "$0")
sudo apt-get update && sudo apt-get -y --no-install-recommends install git ca-certificates curl buildah netavark jq && \
VERS=$(curl -fsm4 https://raw.githubusercontent.com/louislam/uptime-kuma-website/refs/heads/master/version.json | jq -r .latest) && \
git clone --depth=1  -c advice.detachedHead=false --single-branch --branch $VERS https://github.com/louislam/uptime-kuma.git && cd uptime-kuma && \
npm config set min-release-age=7 && \
sed -i -e 's@louislam/uptime-kuma:@@' -e 's/node:.*slim /node:24-trixie-slim / ' docker/debian-base.dockerfile && \
npm ci --omit dev --no-audit && npm run download-dist && \
buildah --storage-driver "$STORAGE_DRIVER" --isolation "$BUILDAH_ISOLATION" bud -t louislam/uptime-kuma:builder-go --pull=missing -f docker/builder-go.dockerfile && \
buildah --storage-driver "$STORAGE_DRIVER" --isolation "$BUILDAH_ISOLATION" bud -t louislam/uptime-kuma:base2-slim --pull=missing --target base2-slim -f docker/debian-base.dockerfile && \
buildah --storage-driver "$STORAGE_DRIVER" --isolation "$BUILDAH_ISOLATION" bud -t louislam/uptime-kuma:base2 --pull=missing --target base2 -f docker/debian-base.dockerfile && \
buildah --storage-driver "$STORAGE_DRIVER" --isolation "$BUILDAH_ISOLATION" bud -t "$CONT_LATEST" --pull=never --target rootless \
        --build-arg BASE_IMAGE=localhost/louislam/uptime-kuma:base2-slim -f docker/dockerfile && \
buildah --storage-driver "$STORAGE_DRIVER" from --pull=never --name version-checker "$CONT_LATEST" && \
NODE_VER=$(buildah --storage-driver "$STORAGE_DRIVER" --isolation "$BUILDAH_ISOLATION" run version-checker node -v) && \
CONT_VER="${VERS}_${NODE_VER}" && \
CONT_WITH_VER="${CONT_LATEST%%:*}:${CONT_VER//[+~]/_}" && \
echo "Container version: ${CONT_WITH_VER}" && \
buildah --storage-driver "$STORAGE_DRIVER" tag "$CONT_LATEST" "$CONT_WITH_VER" && \
buildah --storage-driver "$STORAGE_DRIVER" images && \
echo "${REGISTRY_PACKAGE_RW}" | buildah login --password-stdin -u "${ACTOR}" "${REGISTRY}" && \
buildah --storage-driver $STORAGE_DRIVER push "${CONT_LATEST}" && \
buildah --storage-driver $STORAGE_DRIVER push "${CONT_WITH_VER}"
