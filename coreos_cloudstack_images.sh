#!/bin/bash

TMPDIR=$(mktemp -d coreos.XXXX)
SIZE=$1
S3BUCKET=$2

echo "Template size: $SIZE"
echo "S3 Bucket: $S3BUCKET"

for version in alpha beta stable; do
    echo "Download CoreOS"
    echo "Downloading image: $version"
    wget http://"$version".release.core-os.net/amd64-usr/current/coreos_production_cloudstack_image.bin.bz2 -O - | bzcat > "$TMPDIR"/coreos_"$version"_qemu_image.img
    if [ "$?" -ne 0 ]; then
        echo "Failed to download $version"
        continue
    fi
    echo "Formatting $version image"
    qemu-img convert -f raw -O qcow2 "$TMPDIR"/coreos_"$version"_qemu_image.img "$TMPDIR"/coreos_"$version".qcow2
    rm "$TMPDIR"/coreos_"$version"_qemu_image.img

    wget -O "$TMPDIR"/coreos."$version".version -q http://"$version".release.core-os.net/amd64-usr/current/version.txt
    if [ "$?" -ne 0 ]; then
       echo "Failed to fetch CoreOS version"
       exit 1
    fi
    CORE_OS_VERSION=$(cat "$TMPDIR"/coreos."$version".version|grep COREOS_VERSION_ID|cut -d '=' -f 2)

    qemu-img convert -c -f qcow2 -O qcow2 "$TMPDIR"/coreos_"$version".qcow2 "$TMPDIR"/coreos_"$version"_"$CORE_OS_VERSION".qcow2
    qemu-img resize "$TMPDIR"/coreos_"$version"_"$CORE_OS_VERSION".qcow2 $SIZE
    rm "$TMPDIR"/coreos_"$version".qcow2

    echo "Uploading $version image"
    s3cmd put "$TMPDIR"/coreos_"$version"_"$CORE_OS_VERSION".qcow2 s3://$S3BUCKET/"$version".qcow2 --acl-public
    rm "$TMPDIR"/coreos_"$version"_"$CORE_OS_VERSION".qcow2
    rm "$TMPDIR"/coreos."$version".version
done

rm -r "$TMPDIR"
