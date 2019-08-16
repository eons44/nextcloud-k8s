# nextcloud-k8s
Nextcloud service made highly available and redundant through kubernetes and associated software

THIS PROJECT IS CURRENTLY UNDER DEVELOPMENT.

The files in this repo have been compiled from a lot of various sources. For more information on how to use these files, please visit my website: [https://eons.dev/project/cloud-storage-over-wan/](https://eons.dev/project/cloud-storage-over-wan/) (sorry, I may update this readme once the project is finished).

## What you need to change:
1. Network name, host, and port at the top of tinc/quick_setup_linux.sh
2. secrets in the nextcloud.yaml (see line ~56)
3. nextcloud domain name in nextcloud.yaml (line 48 AND 249)
3. email in the cluster-issuer.yaml (line 10)
4. Nodes list in ceph.yaml (line ~850)

# Known Bugs
The service created by k8s/master_startup.sh does not work with systemctl enable.