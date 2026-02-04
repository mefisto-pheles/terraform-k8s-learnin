terraform {
  required_providers {
    kind = {
      source = "tehcyx/kind"
      version = "0.4.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

provider "kind" {}

# Konfiguracja klastra
resource "kind_cluster" "moj_lab" {
  name = "terraform-k8s-lab"
  wait_for_ready = true
  
  kind_config {
      kind = "Cluster"
      api_version = "kind.x-k8s.io/v1alpha4"
      node {
          role = "control-plane"
      }
  }
}

# Konfiguracja providera K8s (zeby mogl gadac z klastrem wyzej)
provider "kubernetes" {
  host = kind_cluster.moj_lab.endpoint
  client_certificate = kind_cluster.moj_lab.client_certificate
  client_key = kind_cluster.moj_lab.client_key
  cluster_ca_certificate = kind_cluster.moj_lab.cluster_ca_certificate
}

# Testowy namespace
resource "kubernetes_namespace" "test" {
  metadata {
    name = "nauka-terraform"
  }
  depends_on = [kind_cluster.moj_lab]
}

# 1. Deployment - czyli "Utrzymuj 2 kopie aplikacji Nginx przy życiu"
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-deployment"
    # Wrzucamy to do naszego namespace'a
    namespace = kubernetes_namespace.test.metadata[0].name 
  }

  spec {
    replicas = 5 # Chcemy dwie instancje (Pod'y)

    selector {
      match_labels = {
        app = "MojNginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "MojNginx"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
          
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

# 2. Service - czyli "Wystaw ten Nginx na świat (lub wewnątrz klastra)"
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.test.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment.nginx.spec[0].selector[0].match_labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP" # Dostępny wewnątrz klastra
  }
}