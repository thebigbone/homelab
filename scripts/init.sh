ansible -i ../ansible/inventory cluster -m shell -a "timedatectl set-ntp yes" -b --limit masters,workers
ansible -i ../ansible/inventory cluster -m reboot -b --limit masters,workers
ansible -i ../ansible/inventory storage-master -m shell -a "sudo mv /var/lib/mfs/metadata.mfs.back /var/lib/mfs/metadata.mfs" -b
ansible -i ../ansible/inventory storage-master -m shell -a "mfsmaster start" -b
ansible -i ../ansible/inventory storage-chunk -m shell -a "mfschunkserver start" -b
kubectl rollout restart statefulset csi-moosefs-controller -n kube-system
kubectl rollout restart daemonset csi-moosefs-node -n kube-system
