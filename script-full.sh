#!/bin/bash

set -e
set -x

# Atualiza o sistema e instala pacotes necessários
sudo apt update
sudo apt install -y vim curl htop apt-transport-https ca-certificates gnupg lsb-release

function baseLinux() {
  # Desativa o Swap
  sudo swapoff -a
  sudo sed -i '/ swap / s/^/#/' /etc/fstab
}

function kernelModule() {
  # Carrega os módulos do kernel necessários
  sudo modprobe overlay
  sudo modprobe br_netfilter

  cat <<eof | sudo tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
eof

  cat <<eof | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
eof

  sudo sysctl --system
}

# Instala e configura o containerd
function containerD() {
  sudo apt install -y containerd
  sudo mkdir -p /etc/containerd
  containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
  sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  sudo systemctl restart containerd
  sudo systemctl enable containerd
  sudo systemctl status containerd
}

# Instala o kubeadm, kubelet e kubectl
function installK8s() {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.asc
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.asc] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
  sudo apt update
  sudo apt install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
  echo "✅ Setup concluído! O sistema está pronto para iniciar o Kubernetes."
}

function configureK8s() {
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16
  # For Nodes with Public IP
  #sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-addrress=34.172.12.16

  sudo kubeadm reset -f

  export IP_RANGE=10.128.0.0/16
  export IP_NODE_1=10.128.0.12
  export IP_NODE_1_PUBLIC=34.66.232.255
  export IP_PODS_RANGE=192.168.0.0/16
  sudo kubeadm init \
    --apiserver-advertise-address=${IP_NODE_1} \
    --apiserver-cert-extra-sans=${IP_NODE_1_PUBLIC} \
    --pod-network-cidr=${IP_PODS_RANGE}


}

function configureK8skubectl() {
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

function configureK8sForRoot() {
  export KUBECONFIG=/etc/kubernetes/admin.conf
}


function installK8sCNI() {
  kubectl apply -f https://docs.projectcalico.org/manifests/crds.yaml
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  kubectl create sa calico-kube-controllers -n kube-system
  kubectl create clusterrolebinding calico-kube-controllers --clusterrole=calico-kube-controllers --serviceaccount=kube-system:calico-kube-controllers
}

#function joinK8sCluster() {
#  kubeadm join 172.26.8.101:6443 --token xxxx \
#	--discovery-token-ca-cert-hash sha256:yyyyy
#}

function InstallIngressNginx() {
    helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --set controller.publishService.enabled=true
}

function InstallIngressTraefik() {
}


function InstallHelm() {
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
}

function InstallIngressTraefik() {
  echo "🔧 Instalando o Ingress Controller Traefik..."

  local TRAEFIK_DIR="/tmp/traefik"
  local NAMESPACE="traefik"
  local RELEASE_NAME="traefik"

  # Cria diretório temporário
  mkdir -p "$TRAEFIK_DIR"
  cd "$TRAEFIK_DIR" || exit 1

  # Cria arquivo values.yaml
  cat <<EOF > values.yaml
ports:
  web:
    port: 80
    hostPort: 80
    expose:
      enabled: true
    exposedPort: 80
    protocol: TCP

  websecure:
    port: 443
    hostPort: 443
    expose:
      enabled: true
    exposedPort: 443
    protocol: TCP

service:
  enabled: false

hostNetwork: true
dnsPolicy: ClusterFirstWithHostNet

securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]
  readOnlyRootFilesystem: true
  runAsGroup: 0
  runAsNonRoot: false
  runAsUser: 0

additionalArguments:
  - "--entrypoints.web.address=:80"
  - "--entrypoints.websecure.address=:443"

affinity:
  podAntiAffinity: {}
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - k8s-node-1

tolerations:
  - key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

log:
  level: DEBUG

access:
  enabled: true
  format: json

api:
  dashboard: true
  insecure: true
EOF

  # Cria o namespace, se necessário
  kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE

  # Instala ou atualiza o Traefik com helm
  helm repo add traefik https://traefik.github.io/charts
  helm repo update

  helm upgrade --install $RELEASE_NAME traefik/traefik \
    --namespace $NAMESPACE \
    --values values.yaml \
    --wait

  echo "✅ Traefik instalado no namespace '$NAMESPACE'."

  # Verifica se o Pod está rodando
  kubectl get pods -n $NAMESPACE -o wide
}


function AllowSNAT() {

    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    # Redireciona tráfego de entrada da porta 80 para a porta 30080 (Ingress NodePort)
    iptables -t nat -A PREROUTING -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.128.0.14:30080
    iptables -t nat -A POSTROUTING -p tcp -d 10.128.0.13 --dport 30080 -j SNAT --to-source 10.128.0.14
    iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j DNAT --to-destination 10.128.0.14:30443
    iptables -t nat -A POSTROUTING -p tcp -d 10.128.0.13 --dport 30443 -j SNAT --to-source 10.128.0.14
}

baseLinux
kernelModule
containerD
installK8s
configureK8s
configureK8sForRoot
configureK8skubectl
installK9sCNI
