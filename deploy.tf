variable "cluster_name" {}
variable "image" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_region" {}
variable "branch" {}

terraform {

  required_providers {

    kubernetes-alpha = {

      source = "hashicorp/kubernetes-alpha"
      version = "0.2.1"

    }

    aws = {

        source = "hashicorp/aws"

    }

  }

}

locals {

    app = {
        name = "api-hello-world"
        port = 8888
        protocol = "TCP"
    }
    
    eks = {
        namespace = "default"
        node_selector_role = "services"
        replicas = 2
        resources = {
            requests = {
                cpu = "200m"
                memory = "100Mi"
            }
            limits = {
                cpu = "1000m"
                memory = "500Mi"
            }
        }
    }

}

terraform {

    backend "s3" {}

}

#
# Retrieve authentication for kubernetes from aws.
#
provider "aws" {

    access_key = var.aws_access_key_id
    secret_key = var.aws_secret_access_key
    region     = var.aws_region

}

#
# Get kubernetes cluster info.
#
data "aws_eks_cluster" "cluster" {

    #
    # mlfabric k8 cluster specifically for github action runners.
    #
    name  = var.cluster_name

}

#
# Retrieve authentication for kubernetes from aws.
#
data "aws_eks_cluster_auth" "cluster" {

    #
    # mlfabric k8 cluster specifically for github action runners.
    #
    name = var.cluster_name

}

provider "kubernetes" {

    alias = "this"

    host             = data.aws_eks_cluster.cluster.endpoint
    token            = data.aws_eks_cluster_auth.cluster.token
    insecure         = true

}

provider "kubernetes-alpha" {

    alias = "this"

    host     = data.aws_eks_cluster.cluster.endpoint
    token    = data.aws_eks_cluster_auth.cluster.token
    insecure = true

}

resource "kubernetes_manifest" "deployment" {

    provider = kubernetes-alpha.this

    manifest = {

        apiVersion = "apps/v1"
        kind       = "Deployment"

        metadata = {

            namespace = "default"
            name      = local.app.name

            labels = {

                app = local.app.name

            }

        }

        spec = {

            replicas = local.eks.replicas

            selector = {

                matchLabels = {

                    app = local.app.name

                }

            }

            template = {

                metadata = {

                    name = local.app.name

                    labels = {

                        app = local.app.name

                    }

                }

                spec = {

                    terminationGracePeriodSeconds = 0

                    nodeSelector = {

                        role = local.eks.node_selector_role

                    }

                    containers = [

                        {

                            name  = local.app.name
                            image = var.image

                            ports = [

                                {

                                    containerPort = local.app.port
                                    protocol      = local.app.protocol

                                }

                            ]

                            #env = []

                            resources = {

                                requests = {

                                    cpu    = local.eks.resources.requests.cpu
                                    memory = local.eks.resources.requests.memory

                                }

                                limits = {

                                    cpu    = local.eks.resources.limits.cpu
                                    memory = local.eks.resources.limits.memory

                                }

                            }

                        }

                    ]

                }

            }

        }

    }

}

resource "kubernetes_service" "service" {

    provider = kubernetes.this

    metadata {

        name      = local.app.name
        namespace = "default"

        labels = {

            app = local.app.name

        }

    }

    spec {

        selector = {

            app = local.app.name

        }

        port {

            port        = 80
            target_port = local.app.port
            protocol    = local.app.protocol

        }

        type = "ClusterIP"

    }

}

/* resource "kubernetes_ingress" "ingress" {

    provider = kubernetes.this

    metadata {

        name      = local.app.name
        namespace = "default"

    }

    spec {

        tls {

            hosts       = [ local.API_URL ]
            secret_name = "tls-ml.moodysanalytics.com"

        }

        rule {

            host = local.API_URL

            http {

                path {

                    path = "/"

                    backend {

                        service_name = local.app.name
                        service_port = 80

                    }

                }

            }

        }

    }

} */