#!/bin/bash

# ==========================
# Configuração do Kubernetes
# ==========================
# Garante que kubectl use seu kubeconfig mesmo com sudo
export KUBECONFIG=$HOME/.kube/config

# ==========================
# Variáveis de teste
# ==========================
NAMESPACE="app"
CONCURRENCY=2
QPS_HTTP=500
QPS_SUBSET=300
TCP_PORT=3306
DURATION=10s   # duração de cada onda de tráfego

# ==========================
# Serviços a testar
# ==========================
GATEWAY_URL="http://app-service-mesh-gateway-istio.app.svc.cluster.local/healthz"
SERVICE_URL="http://app-service-mesh-svc.app.svc.cluster.local:80/healthz"
WAYPOINT_URL="http://waypoint.app.svc.cluster.local:8080/healthz"  # ajuste porta/path corretos

# Lista de serviços para loop
SERVICES=("$GATEWAY_URL" "$SERVICE_URL" "$WAYPOINT_URL")

# ==========================
# Funções
# ==========================

# Escolhe aleatoriamente subset V1 ou V2
random_subset() {
  if [ $((RANDOM % 2)) -eq 0 ]; then
    echo "V1"
  else
    echo "V2"
  fi
}

# Loop HTTP aleatório para múltiplos serviços
run_fortio_http_random() {
  local URL=$1
  local QPS=$2
  while true; do
    SUBSET=$(random_subset)
    POD_NAME="fortio-$(date +%s)"
    echo "HTTP $POD_NAME para $URL com subset $SUBSET"
    kubectl run -it $POD_NAME -n $NAMESPACE --rm --image=fortio/fortio -- \
      load -qps $QPS -t $DURATION -c $CONCURRENCY -H "end-user: $SUBSET" "$URL?testeab=true"
    sleep 1
  done
}

# Loop TCP contínuo (apenas para SERVICE_URL, ajuste se waypoint tiver TCP)
run_fortio_tcp_loop() {
  local HOST=$1
  local PORT=$2
  while true; do
    POD_NAME="fortio-tcp-$(date +%s)"
    echo "TCP $POD_NAME para $HOST:$PORT"
    kubectl run -it $POD_NAME -n $NAMESPACE --rm --image=fortio/fortio -- \
      tcp_ping $HOST:$PORT
    sleep 1
  done
}

# ==========================
# Execução do stress test
# ==========================
echo "=== Iniciando stress test completo na malha Istio ==="

# Loop HTTP para todos os serviços (Gateway, Service, Waypoint)
for URL in "${SERVICES[@]}"; do
  run_fortio_http_random "$URL" $QPS_HTTP &
done

# Subsets V1/V2 extra carga apenas para SERVICE_URL
run_fortio_http_random "$SERVICE_URL" $QPS_SUBSET &
run_fortio_http_random "$SERVICE_URL" $QPS_SUBSET &

# TCP loop opcional (Service ClusterIP)
run_fortio_tcp_loop "app-service-mesh-svc.app.svc.cluster.local" $TCP_PORT &

# Espera todos os processos em background
wait
