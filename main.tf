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

# 2. Konfiguracja Kubernetes Provider
provider "kubernetes" {
  host                   = kind_cluster.moj_lab.endpoint
  client_certificate     = kind_cluster.moj_lab.client_certificate
  client_key             = kind_cluster.moj_lab.client_key
  cluster_ca_certificate = kind_cluster.moj_lab.cluster_ca_certificate
}

# 3. Konfiguracja Helm Provider (To tutaj miałeś błąd - kubernetes musi być W ŚRODKU helm)
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

# 5. Instalacja Nginx przez Helm
resource "helm_release" "nginx" {
  name       = "moj-nginx-z-helma"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "nginx"
  version    = "15.4.2" # Możemy zostawić starą wersję Charta, ale podmienimy mu obraz

  namespace  = kubernetes_namespace.test.metadata[0].name

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "replicaCount"
    value = "3"
  }

  # --- NOWOŚĆ: Wymuszamy najnowszy obraz ---
  set {
    name  = "image.tag"
    value = "latest"
  }
  # -----------------------------------------

  depends_on = [kind_cluster.moj_lab]
}