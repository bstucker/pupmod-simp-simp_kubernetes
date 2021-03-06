# Full description of SIMP module 'simp_kubernetes' here.
#
# @param is_master
#   Enable if the host is to be a Kubernetes Master. This host would have the
#   following services:
#     - `kube-apiserver`
#     - `kube-contoller-manager`
#     - `kube-scheduler`
#   If false (default), the module will configure these services:
#     - `kubelet`
#     - `kube-proxy`
#   All nodes have `flannel` by default, unless configured otherwise
#
# @param network_tech
#   Which networking backend to use. Currently only `flannel` is supported.
#
# @param manage_etcd
#   Install and manage etcd
#
# @param inject_network_config
#   Fill etcd with the network configuration required by flannel
#
# @param etcd_static_cluster
#   Use the 'static' method to bootstrap the etcd cluster. Other methods
#   require setup outside the scope of this module, but should still be
#   compatible using this toggle.
#
# @param etcd_prefix
#   The etcd prefix where the flannel's configuration can be found
#
# @param flannel_network_config
#   The actual configuration for flannel
#
# @param etcd_peers
#   Array of hostnames/IPs that are etcd peers
#
# @param etcd_client_port
#   Port that etcd uses for serving requests
#
# @param etcd_peer_port
#   Port that etcd uses for peering
#
# @param etcd_peer_listen_address
#   Address of interface that etcd will listen on for peer communication
#   `0.0.0.0` for all interfaces.
#
# @param etcd_client_listen_address
#   Address of interface that etcd will listen on for client communication
#   `0.0.0.0` for all interfaces.
#
# @param etcd_options
#   Hash of extra options to be passed along to cristifalcas/etcd
#
# @param kube_masters
#   Array of hostnames/IPs that are Kubernetes masters
#
# @param kube_api_port
#   Port that kube-apiserver will be listening on
#
# @param allow_priv
#   Allow priviliged containers to run on this cluster
#
# @param logtostderr
#  Log to stderr. If true, logs will get sent to the journal
#
# @param log_level
#   Set the level of log output to debug-level (0~4) or trace-level (5~10)
#
# @param api_args
#   Hash of extra arguments to be sent to any Kubernetes service
#
# @param service_addresses
#   Virtual IP range that will be used by Kubernetes services
#
# @param api_listen_address
#   Address of interface that `kube-apiserver` will listen on.
#   `0.0.0.0` for all interfaces.
#
# @param master_api_args
#   Hash of extra arguments to be sent to the `kube-apiserver` service
#
# @param scheduler_args
#   Hash of extra arguments to be sent to the `kube-scheduler` service
#
# @param controller_args
#   Hash of extra arguments to be sent to the `kube-controller-manager` service
#
# @param kubelet_listen_address
#   Address of interface that `kubelet` will listen on.
#   `0.0.0.0` for all interfaces.
#
# @param kubelet_hostname
#   Overwrite hostname the the kubelet will identify itself as.
#
# @param proxy_args
#   Hash of extra arguments to be sent to the `kube-proxy` service
#
# @param kubelet_args
#   Hash of extra arguments to be sent to the `kubelet` service
#
# @param flannel_args
#  Hash of extra arguments to be sent to the `flanneld` service
#
# @param package_ensure
# @param flannel_package_ensure
#
# @param trusted_nets
#   The address range(s) to allow connections from for host to host
#   communication.
#
# @author https://github.com/simp/pupmod-simp-simp_kubernetes/graphs/contributors
#
class simp_kubernetes (
# general settings
  Boolean $is_master,
  Optional[String] $network_tech,
  Boolean $manage_etcd,
  Boolean $inject_network_config,
  Boolean $etcd_static_cluster,
  String $etcd_prefix,
  Hash $flannel_network_config,

# etcd
  Array[Simplib::Host] $etcd_peers,
  Simplib::Port $etcd_client_port,
  Simplib::Port $etcd_peer_port,
  Simplib::IP $etcd_peer_listen_address,
  Simplib::IP $etcd_client_listen_address,
  Boolean $etcd_peer_tls,
  Boolean $etcd_client_tls,
  Hash $etcd_options,

# every-host
  Array[Simplib::Host] $kube_masters,
  Simplib::Port $kube_api_port,
  Boolean $allow_priv,
  Boolean $logtostderr,
  Integer[1,10] $log_level,
  Hash $api_args,

# master
  Simplib::IP::CIDR $service_addresses,
  Simplib::Host $api_listen_address,
  Hash $master_api_args,
  Hash $scheduler_args,
  Hash $controller_args,

# node
  Simplib::IP $kubelet_listen_address,
  Optional[Simplib::Hostname] $kubelet_hostname,
  Hash $proxy_args,
  Hash $kubelet_args,

# flannel
  Hash $flannel_args,

# SIMP Catalysts
  String $package_ensure         = simplib::lookup('simp_options::package_ensure', {'default_value' => 'installed' }),
  String $flannel_package_ensure = simplib::lookup('simp_options::package_ensure', {'default_value' => 'installed' }),
  Simplib::Netlist $trusted_nets = simplib::lookup('simp_options::trusted_nets', {'default_value' => ['127.0.0.1/32'] }),
) {

  $etcd_advertise_client_urls = $etcd_peers.map |$peer| {
    "http://${peer}:${etcd_client_port}"
  }

  $kube_master_urls = $kube_masters.map |$master| {
    "http://${master}:${kube_api_port}"
  }

  case $network_tech {
    'flannel': { include '::simp_kubernetes::flannel' }
    Undef:     { notify { 'simp_kubernetes: no network backend chosen':} }
    default:   { fail("simp_kubernetes: network_tech ${network_tech} not supported") }
  }

  # required on all hosts running kubernetes
  include '::simp_kubernetes::common_config'
  Class['simp_kubernetes::flannel'] -> Class['simp_kubernetes::common_config']

  if $is_master {
    include '::simp_kubernetes::master'
    Class['simp_kubernetes::common_config'] -> Class['simp_kubernetes::master']
  }
  else {
    include '::simp_kubernetes::node'
    Class['simp_kubernetes::common_config'] -> Class['simp_kubernetes::node']
  }

}
