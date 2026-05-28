# Infra POC Argo Pull Request Generator

Repositorio GitOps de la POC.

En esta version:

- Argo CD ya no lee manifests desde el repo `landing`
- GitHub Actions escribe manifests generados en `generated/...`
- GitHub Actions publica imagenes en Docker Hub y este repo solo referencia esos artefactos
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
- esa carpeta contiene solo manifests y referencia de imagen
- Argo sincroniza `landing-prod` desde esa ruta

### Preview

- GitHub Actions de `landing` actualiza `generated/previews/pr-<numero>`
- esas carpetas no deben contener codigo fuente de la aplicacion
- `ApplicationSet` usa Git generator para detectar nuevas carpetas
- cada carpeta genera una `Application`

## Como visualizar los ambientes

### Prod

```bash
kubectl port-forward -n landing-prod svc/landingpage 8081:80
```

Abre:

- [http://localhost:8081](http://localhost:8081)

### Preview por PR

Para un PR `N`, Argo genera:

- namespace: `preview-pr-N`
- servicio: `landingpage-pr-N`

Ejemplo para el PR 7:

```bash
kubectl port-forward -n preview-pr-7 svc/landingpage-pr-7 8082:80
```

Abre:

- [http://localhost:8082](http://localhost:8082)

Comandos utiles para descubrir previews activos:

```bash
kubectl get applications -n argocd
kubectl get svc --all-namespaces | grep landingpage
```

## Nota

El directorio `generated/` es parte del flujo deseado en esta POC. No se edita a mano en operacion normal; lo administra GitHub Actions.

## Configuracion requerida en GitHub

### Repo `landing`

#### Repository secret obligatorio

- `INFRA_REPO_TOKEN`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

Ubicacion:

- `landing repo > Settings > Secrets and variables > Actions > Repository secrets`

Permiso esperado:

- escritura sobre el repo `InfraPOCArgoPUllRequestGenerator`
- permiso para publicar en `juanmarulanda/landingpocargoprpreview`

#### Repository variable opcional

- `PREVIEW_AZURE_CLIENT_ID`

Ubicacion:

- `landing repo > Settings > Secrets and variables > Actions > Variables`

Uso:

- si existe, el workflow genera un `ServiceAccount` con anotacion de Azure Workload Identity para previews

## Runbook corto

### Cuando se abre o actualiza un PR con label `preview`

1. `landing/.github/workflows/sync-preview-gitops.yaml` construye y publica una imagen del PR
2. renderiza manifests con el digest publicado
3. hace commit en `infra/generated/previews/pr-<numero>`
4. el Git generator de Argo detecta esa carpeta
5. crea `landing-pr-<numero>` y el namespace efimero

### Cuando el PR se mergea o cierra

1. el mismo workflow elimina la carpeta `infra/generated/previews/pr-<numero>`
2. Argo detecta que ya no existe en Git
3. elimina la `Application` efimera y hace `prune` de sus recursos

### Cuando hay push a `main` en `landing`

1. `landing/.github/workflows/sync-prod-gitops.yaml` construye y publica una imagen productiva
2. actualiza `infra/generated/environments/prod/landing` con el digest exacto
3. Argo sincroniza `landing-prod`

## Nota operativa importante

Las imagenes se publican como multi-arquitectura:

- `linux/amd64`
- `linux/arm64`

Eso evita errores como:

- `no match for platform in manifest`

Y permite que la misma imagen funcione tanto en runners x86 como en tu cluster local `kind` sobre `arm64`.
