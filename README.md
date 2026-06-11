# homelab k8 (work-in-progress)

Powered by Flux, Kubernetes, Cilium, Talos, OpenBSD and Linux.
---

## Overview

This is the monorepo for all the k8s infrastructure I currently manage. Currently, I have two clusters (comet and nebula). Comet is the homelab cluster, not exposed to the internet. Nebula is the mixture of dedicated servers and vps I rent and is exposed to the internet. 

The goal is to automate pretty much everything, requiring as less manual intervention as possible. There is also strict focus on security by using networkpolicies, running modsec waf for first proxy servers, plan to host auth DNS in the near future, host hardening (strict selinux policies, linux-hardened kernel, disabling most of the kernel modules, etc), encrypted traffic everywhere, gvisor sandbox for most of the containers and lots of other minor tweaks.  

The network flow for comet:

GPON -> OpenWRT (acts as fw and does normal traffic filtering) -> Managed switch (TP-link-108GE) -> Multiple dumb APs (for wifi) -> k8s in it's own VLAN, untrusted devices in their own

The network flow for nebula (tailscale mesh with headscale coordination server):

HTTP client -> DNS round robin -> Two OpenBSD VPS act as a firewall ([pf](https://www.openbsd.org/faq/pf/)) + DNS resolver for all servers + nginx proxy with modsec WAF + anubis for PoW captcha (not deployed yet) -> nginx forwards the traffic to envoy-gateway inside the cluster which hits the appropriate HTTPRoute

---

## Hardware

| Cluster  | Spec | Network  | Distro | Use case
|---|--|---|---|---|
| comet | (i7-8550U - 32GiB DDR4 - 500GiB SATA SSD) x 3 | 300Mbps up/down (home ISP) | Archlinux with incus hypervisor | Compute - k3s, docker, etc
| standalone | i5-7500 - 8GiB DDR4 - 2x4 TiB HDD | 300Mbps up/down (home ISP) | Archlinux | Storage - NFS store, backups
| nebula | Intel(R) Xeon(R) E3-1270 v6 - 32GiB DDR4 - 2x450GiB SSD | 500 Mbps up/down | Archlinux with incus hypervisor | Compute - k3s, docker, etc
| nebula | Intel(R) Xeon(R) E5-1650 v3 - 64GiB DDR4 - 2x450GiB NVMe | 500 Mbps up/down | Archlinux with incus hypervisor | Compute - k3s, docker, etc
| standalone (vps) | AMD EPYC 9554 (4 virtual cores) - 16GiB DDR4 - 200GiB NVMe | 1 Gigabit up/down | OpenBSD | Compute - nginx, docker, firewall, etc
| standalone (vps) | AMD EPYC 9554 (6 virtual cores) - 24GiB DDR4 - 200GiB NVMe | 1 Gigabit up/down | OpenBSD | Compute - nginx, docker, firewall, etc

---

## Kubernetes

### Comet

This is my production home Kubernetes cluster. It is powered by k3s on ubuntu 24.04. I plan to expand the compute capacity in the near future. Every deployment runs in HA but since I use NFS for PVCs, there is still a single point of failure. Future plans are to setup ceph or other distributed storage. Backups are in 3-2-1 fashion using VolSync. Network routing and security is handled by Cilium, which provides powerful NetworkPolicy capabilities while having relatively low maintenance burden.

### Nebula

This cluster serves everything exposed on \*.ext4.xyz domain. All of the external facing deployments run on gvisor sandbox. The requests route through multiple security layers before hitting envoy-gateway. Some routes are behind oidc auth, protected by pocket-id OIDC provider. 

### GitOps

Flux does all the heavy lifting of syncing the resources from git repo and runs reconcilation loop on every commit. It's a fantastic way to have declaritive infrastructure. Renovate bot handles all the dependency updates and oens up a PR when it detects new versions. 

## Core Components

Any top dir has two subdirs which specify the cluster name. Kustomization helps avoid duplication for deploying the same component across two clusters. 

- **Cilium**: Provides network routing, network security, exposing apps via LoadBalancers and other networking functionality.
- **nfs-csi**: Provides storage by provisioning PVCs with an NFS server.
- **VolSync**: Provides and manages automated backups and restores of persistent storage.
- **Flux**: Provides GitOps automation for syncing desired state of resources.
- **external-dns**: Syncs DNS records against upstream resolvers' records, such as Cloudflare DNS.
- **cert-manager**: Automated TLS management for generating and rotating signed and trusted TLS certificates stored as Kubernetes secrets.
- **envoy-gateway**: Envoy gateway is the envoy's implementation of k8s Gateway API. It's mainly used for serving and exposing deployments to external clients.
- **VictoriaMetrics**: Currently, using it's log stack for viewing and scraping cluster-wide logs.
- **kube-prometheus-stack + prometheus-operator**: Automated configuration and service discovery for Prometheus (and thus VictoriaMetrics), with shipped defaults for Kubernetes-focused monitoring and alerting.
- **system-upgrade-controller**: Auto-update of cluster k3s version.
