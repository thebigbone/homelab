### pf firewall

- two openbsd boxes act as firewall and (wireguard) gateway to linux servers running the applications.
- round robin DNS load balancing b/w them, very simple architecture.
- linux servers aren't exposed at all, only communicate through wireguard.
