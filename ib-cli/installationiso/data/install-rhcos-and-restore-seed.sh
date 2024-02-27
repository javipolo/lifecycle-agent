#!/bin/bash

set -e # Halt on error

seed_image=${1:-$SEED_IMAGE}
seed_version=${2:-$SEED_VERSION}
installation_disk=${3:-$INSTALLATION_DISK}
lca_image=${4:-$LCA_IMAGE}

authfile=${AUTH_FILE:-"/var/tmp/backup-secret.json"}
pull_secret=${PULL_SECRET_FILE:-"/var/tmp/pull-secret.json"}

coreos-installer install ${installation_disk}

# We need to grow the partition. Coreos-installer leaves a small partition
growpart ${installation_disk} 4
mount ${installation_disk}4 /mnt
mount ${installation_disk}3 /mnt/boot
xfs_growfs ${installation_disk}4

# Creating and mounting shared /var/lib/containers
if lsattr -d /mnt/ | cut -d ' ' -f 1 | grep i; then
    chattr -i /mnt/
    mkdir -p /mnt/containers
    chattr +i /mnt/
else
    mkdir -p /mnt/containers
fi
mount -o bind /mnt/containers /var/lib/containers

additional_flags=""
if [ -n "${PRECACHE_DISABLED}" ]; then
    additional_flags="${additional_flags} --precache-disabled"
fi

if [ -n "${PRECACHE_BEST_EFFORT}" ]; then
    additional_flags="${additional_flags} --precache-best-effort"
fi

podman run --privileged --rm --pid=host --authfile "${authfile}" -v /:/host --entrypoint /usr/local/bin/lca-cli "${lca_image}" ibi --seed-image "${seed_image}" --authfile "${authfile}" --seed-version "${seed_version}" --pullSecretFile "${pull_secret}" ${additional_flags}
