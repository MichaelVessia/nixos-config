{pkgs, ...}: let
  gcloud = pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ];
in {
  # Work hosts read FloSports GKE workloads and Cloud Build logs.
  # kubectl authenticates to GKE through gke-gcloud-auth-plugin.
  home.packages = [
    gcloud
    pkgs.kubectl
  ];
}
