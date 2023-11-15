terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.51.0"
    }
  }
}

locals {
  region              = "us-central1"
  image               = "gcr.io/${var.project_id}/ayyazzafar/youtube_videos_urls_extractor_by_channel_id"
  helloWorldImage     = "us-docker.pkg.dev/cloudrun/container/hello"
}


resource "google_project_service" "enabled_service" {
  project = var.project_id
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloudbuild_trigger" "trigger" {
  name       = "youtube-videos-urls-extractor-by-channel-id"
  depends_on = [
    google_project_service.enabled_service
  ]
  github {
    owner = "ayyazzafar"
    name  = "youtube_videos_urls_extractor_by_channel_id"
    push {
      branch = "main"
    }
  }
  build {

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build", "-t", local.image, ".", "-f", "Dockerfile"
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image]
    }
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", google_cloud_run_service.service.name, "--image", "${local.image}:latest",
        "--region",
        var.region, "--platform", "managed", "-q"
      ]
    }
  }
}
data "google_project" "project" {}


resource "google_project_iam_member" "cloudbuild_roles" {
  depends_on = [google_cloudbuild_trigger.trigger]
  for_each   = toset(["roles/run.admin", "roles/iam.serviceAccountUser"])
  project    = var.project_id
  role       = each.key
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

output "service_url" {
  value = google_cloud_run_service.service.status[0].url
}

resource "google_cloud_run_service" "service" {
  depends_on = [
    google_project_service.enabled_service
  ]
  name     = "youtube_videos_urls_extractor_by_channel_id"
  location = var.region

  autogenerate_revision_name = true

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "0",
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }
    spec {

      containers {
        ports {
          container_port = 80
        }
        image = local.helloWorldImage
      }
    }
  }
}
data "google_iam_policy" "admin" {
  binding {
    role    = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}
resource "google_cloud_run_service_iam_policy" "policy" {
  location    = var.region
  project     = var.project_id
  service     = google_cloud_run_service.service.name
  policy_data = data.google_iam_policy.admin.policy_data
}
