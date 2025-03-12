# Hybrid Talos Cluster
Using Oracle always-free vms to create a k8s controlplane, plus two vms behind a NAT using TalosOS.

Talos has built-in wireguard, which under normal circumstances would be enough to bypass the NAT wall between the nodes and the controlplane, however, I opted to add a tunnel between the nodes to avoid VPN blocking.

This is the initial commit, I plan to refactor everything and clean it up. Then further document this project.


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