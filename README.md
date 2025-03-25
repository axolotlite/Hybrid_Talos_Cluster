# Hybrid Talos Cluster
Using Oracle always-free vms to create a k8s controlplane, plus two vms behind a NAT using TalosOS.

Talos has built-in wireguard, which under normal circumstances would be enough to bypass the NAT wall between the nodes and the controlplane, however, I opted to add a tunnel between the nodes to avoid VPN blocking.

This is the initial commit, I plan to refactor everything and clean it up. Then further document this project.

bandwidth for each vm:
VM.Standard.E2.1.Micro
Always Free-eligible
Virtual machine, 1 core OCPU, 1 GB memory, 0.48 Gbps network bandwidth

VM.Standard.A1.Flex
Always Free-eligible
Virtual machine, 4 core OCPU, 24 GB memory, 4 Gbps network bandwidth
1gbps per core

## Special Thanks to the writers of these Repos and Articles that I've read through / used code from!
https://www.talos.dev/  
https://github.com/sergelogvinov/terraform-talos  
https://github.com/erebe/wstunnel  
https://community.hetzner.com/tutorials/obfuscating-wireguard-using-wstunnel  
https://github.com/jonlabelle/docker-network-tools  
https://github.com/anotherglitchinthematrix/oci-free-tier-terraform-module  
https://shadynagy.com/setting-up-vpn-using-wiresock-with-ubuntu-windows/  
https://techoverflow.net/2021/07/09/what-does-wireguard-allowedips-actually-do/  
https://dev.to/netikras/kubernetes-on-vpn-wireguard-152l  
https://github.com/OJFord/terraform-provider-wireguard  
https://metallb.universe.tf/installation/  
https://blogs.oracle.com/ateam/post/oci-networking-best-practices-recommendations-and-tips---part-one---general-oci-networking  