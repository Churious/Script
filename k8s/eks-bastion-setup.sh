#!/usr/bin/env bash
curl -fsSL https://raw.githubusercontent.com/Churious/Script/refs/heads/main/k8s/install-eksctl.sh | bash && echo 'eksctl installed'
curl -fsSL https://raw.githubusercontent.com/Churious/Script/refs/heads/main/k8s/install-kubectl.sh | bash && echo 'kubectl installed'
curl -fsSL https://raw.githubusercontent.com/Churious/Script/refs/heads/main/k8s/install-k9s.sh | bash && echo 'k9s installed'
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && echo 'helm installed'
