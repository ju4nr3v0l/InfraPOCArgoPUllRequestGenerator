# Infra POC Argo Pull Request Generator

Repositorio de infraestructura para la POC de Argo CD y Pull Request Generator.

## Contenido

- `argocd/applications/landing-prod.yaml`: app estable
- `argocd/applicationsets/landing-pr-previews.yaml`: previews por PR
- `scripts/bootstrap-argocd.sh`: crea cluster local e instala Argo CD
- `scripts/create-github-secret.sh`: crea el secret del token de GitHub
- `scripts/port-forward.sh`: expone la UI de Argo CD localmente

## Repos relacionados

- Landing: `https://github.com/ju4nr3v0l/landingPOCArgoPUllRequestGenerator`
- Infra: `https://github.com/ju4nr3v0l/InfraPOCArgoPUllRequestGenerator`
