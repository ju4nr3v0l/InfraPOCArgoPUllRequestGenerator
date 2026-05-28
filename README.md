# Infra POC Argo Pull Request Generator

Repositorio GitOps de la POC.

En esta version:

- Argo CD ya no lee manifests desde el repo `landing`
- GitHub Actions escribe manifests generados en `generated/...`
- Argo CD sincroniza exclusivamente este repo

## Estructura

```text
.
├── argocd
│   ├── applications
│   │   └── landing-prod.yaml
│   └── applicationsets
│       └── landing-pr-previews.yaml
├── generated
│   ├── environments
│   │   └── prod
│   │       └── landing
│   └── previews
└── scripts
```

## Flujo

### Prod

- GitHub Actions de `landing` actualiza `generated/environments/prod/landing`
- Argo sincroniza `landing-prod` desde esa ruta

### Preview

- GitHub Actions de `landing` actualiza `generated/previews/pr-<numero>`
- `ApplicationSet` usa Git generator para detectar nuevas carpetas
- cada carpeta genera una `Application`

## Nota

El directorio `generated/` es parte del flujo deseado en esta POC. No se edita a mano en operacion normal; lo administra GitHub Actions.

## Configuracion requerida en GitHub

### Repo `landing`

#### Repository secret obligatorio

- `INFRA_REPO_TOKEN`

Ubicacion:

- `landing repo > Settings > Secrets and variables > Actions > Repository secrets`

Permiso esperado:

- escritura sobre el repo `InfraPOCArgoPUllRequestGenerator`

#### Repository variable opcional

- `PREVIEW_AZURE_CLIENT_ID`

Ubicacion:

- `landing repo > Settings > Secrets and variables > Actions > Variables`

Uso:

- si existe, el workflow genera un `ServiceAccount` con anotacion de Azure Workload Identity para previews

## Runbook corto

### Cuando se abre o actualiza un PR con label `preview`

1. `landing/.github/workflows/sync-preview-gitops.yaml` renderiza manifests
2. hace commit en `infra/generated/previews/pr-<numero>`
3. el Git generator de Argo detecta esa carpeta
4. crea `landing-pr-<numero>` y el namespace efimero

### Cuando el PR se mergea o cierra

1. el mismo workflow elimina la carpeta `infra/generated/previews/pr-<numero>`
2. Argo detecta que ya no existe en Git
3. elimina la `Application` efimera y hace `prune` de sus recursos

### Cuando hay push a `main` en `landing`

1. `landing/.github/workflows/sync-prod-gitops.yaml` actualiza `infra/generated/environments/prod/landing`
2. Argo sincroniza `landing-prod`
