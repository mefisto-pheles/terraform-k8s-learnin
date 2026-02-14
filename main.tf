terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "kind" {}

# 1. Tworzenie klastra
resource "kind_cluster" "moj_lab" {
  name           = "terraform-k8s-lab"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    node {
      role = "control-plane"
    }
  }
}

# 2. Konfiguracja Kubernetes
provider "kubernetes" {
  host                   = kind_cluster.moj_lab.endpoint
  client_certificate     = kind_cluster.moj_lab.client_certificate
  client_key             = kind_cluster.moj_lab.client_key
  cluster_ca_certificate = kind_cluster.moj_lab.cluster_ca_certificate
}

# 3. Konfiguracja Helm
provider "helm" {
  kubernetes {
    host                   = kind_cluster.moj_lab.endpoint
    client_certificate     = kind_cluster.moj_lab.client_certificate
    client_key             = kind_cluster.moj_lab.client_key
    cluster_ca_certificate = kind_cluster.moj_lab.cluster_ca_certificate
  }
}

# 4. Namespace
resource "kubernetes_namespace" "test" {
  metadata {
    name = "nauka-terraform"
  }
  depends_on = [kind_cluster.moj_lab]
}

# Instalacja ArgoCD (Serce GitOpsa)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.46.7"
  namespace        = "argocd"
  create_namespace = true

  # Wyłączamy SSL wewnątrz klastra (dla uproszczenia laba)
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  depends_on = [kind_cluster.moj_lab]
}