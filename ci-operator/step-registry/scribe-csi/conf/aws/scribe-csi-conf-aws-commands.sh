#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# 'oc' , 'kubectl', and 'helm' must be installed in the container running this script

helm upgrade --install --create-namespace -n scribe-system \
    --set image.repository=${SCRIBE_OPERATOR} \
    --set image.tag=latest \
    --set rclone.repository=${MOVER_RCLONE} \
    --set rclone.tag=latest \
    --set restic.repository=${MOVER_RESTIC} \
    --set restic.tag=latest \
    --set rsync.repository=${MOVER_RSYNC} \
    --set rsync.tag=latest \
    --set metrics.disableAuth=true \
    scribe ./helm/scribe

oc annotate sc/gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite
oc annotate sc/gp2-csi storageclass.kubernetes.io/is-default-class="true" --overwrite

oc create -f - << SNAPCLASS
---
apiVersion: snapshot.storage.k8s.io/v1beta1
kind: VolumeSnapshotClass
metadata:
  name: gp2-csi
driver: ebs.csi.aws.com
deletionPolicy: Delete
SNAPCLASS

oc annotate volumesnapshotclass/gp2-csi snapshot.storage.kubernetes.io/is-default-class="true"
oc wait --for=condition=Ready pods --all -n scribe-system --timeout=240s
