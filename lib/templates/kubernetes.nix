# Mirrors the existing promotion model described in FOM-51's background:
# Helm charts -> ECR -> Kargo promotion -> platform config repo -> Renovate.
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

  valuesYaml = ''
    ${header}
    image:
      repository: <ECR_REGISTRY>/${name}
      tag: ""

    replicaCount: 1
  '';

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
