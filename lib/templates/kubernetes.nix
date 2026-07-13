# Mirrors the existing promotion model described in FOM-51's background:
# Helm charts -> ECR -> Kargo promotion -> platform config repo -> Renovate.
#
# Two independent toggles (repoConfig.kubernetes.helm / .argocd), each
# contributing its own file set — a repo can have a Helm chart without an
# ArgoCD Application (not yet deployed via GitOps) or vice versa. The
# go-service example has both on; rust-service has only helm, which is why
# rust-service has no deploy/ directory.
{ repoConfig, header }:
let
  k8s = repoConfig.kubernetes or {};
  name = repoConfig.name;

  chartYaml = ''
    ${header}
    apiVersion: v2
    name: ${name}
    version: 0.1.0
    appVersion: "1.0.0"
  '';

  # <ECR_REGISTRY> is intentionally left as a literal placeholder — the
  # real registry URL is environment-specific and belongs in whatever
  # values overlay/Helm --set the deploy pipeline applies, not baked into
  # a platform-generated file that's identical across environments.
  valuesYaml = ''
    ${header}
    image:
      repository: <ECR_REGISTRY>/${name}
      tag: ""

    replicaCount: 1
  '';

  # Same idea: <PLATFORM_CONFIG_REPO_URL> is a stand-in for wherever the
  # org's actual platform-config repo (the one Kargo promotes into, per
  # the ticket's background) ends up living.
  argocdApplicationYaml = ''
    ${header}
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ${name}
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: <PLATFORM_CONFIG_REPO_URL>
        path: apps/${name}
        targetRevision: main
      destination:
        server: https://kubernetes.default.svc
        namespace: ${name}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  '';
in
  (if k8s.helm or false then {
    "charts/${name}/Chart.yaml" = chartYaml;
    "charts/${name}/values.yaml" = valuesYaml;
  } else {})
  // (if k8s.argocd or false then {
    "deploy/argocd-application.yaml" = argocdApplicationYaml;
  } else {})
