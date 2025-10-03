# Hybrid Talos Cluster
Using Hetzner cloud and TalosOS to create a Secure Hybrid Kubernetes cluster through wireguard tunnel.

README Update TBD

## You can create a key for wstunnel using:
`openssl rand -base64 42 | tr -d '\n='`

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
https://github.com/piraeusdatastore/piraeus-operator/blob/v2/docs/how-to/talos.md  
https://github.com/hcloud-talos/terraform-hcloud-talos    
https://longhorn.io/kb/tip-only-use-storage-on-a-set-of-nodes/
https://devopscube.com/create-a-new-account-in-argo-cd/
https://medium.com/@vdboor/using-nginx-ingress-as-a-static-cache-91bc27be04a1
https://stackoverflow.com/questions/62245119/ingress-nginx-cache