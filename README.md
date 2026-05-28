# Infra POC Argo Pull Request Generator

Repositorio GitOps de la POC.

En esta version:

- Argo CD ya no lee manifests desde el repo `landing`
- GitHub Actions escribe manifests generados en `generated/...`
- GitHub Actions publica imagenes en Docker Hub y este repo solo referencia esos artefactos
- Argo CD sincroniza exclusivamente este repo
- Argo Rollouts controla promociones BlueGreen para `prod` y para cada preview por PR

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
    ├── bootstrap-argocd.sh
    ├── create-github-secret.sh
    ├── install-argo-rollouts-cli.sh
    ├── port-forward.sh
    └── promote-rollout.sh
```

## Stack instalado en la POC

### Componentes principales

- `kind`
  - cluster Kubernetes local
- `Argo CD`
  - sincronizacion GitOps
- `ApplicationSet`
  - generacion automatica de aplicaciones efimeras por PR
- `Argo Rollouts`
  - despliegues BlueGreen y promocion controlada
- `Docker Hub`
  - registro de imagenes OCI multi-arquitectura
- `GitHub Actions`
  - build, publish de imagen y render de manifests GitOps

### Beneficios del stack completo

- separa claramente codigo, artefactos y configuracion GitOps
- evita copiar codigo fuente al repo de infraestructura
- fija los despliegues por digest inmutable
- permite ambientes efimeros por PR con cleanup automatico
- agrega validacion visual previa a la promocion con BlueGreen
- reduce riesgo de despliegue directo sobre `prod`
- deja trazabilidad completa desde commit hasta imagen y rollout
- se acerca mucho mas a un patron enterprise reusable para Sistecredito

## Flujo

### Prod

- GitHub Actions de `landing` actualiza `generated/environments/prod/landing`
- esa carpeta contiene solo manifests y referencia de imagen
- Argo sincroniza `landing-prod` desde esa ruta
- Argo Rollouts publica la nueva revision por `landingpage-preview`
- la promocion hacia `landingpage-active` es manual

### Preview

- GitHub Actions de `landing` actualiza `generated/previews/pr-<numero>`
- esas carpetas no deben contener codigo fuente de la aplicacion
- `ApplicationSet` usa Git generator para detectar nuevas carpetas
- cada carpeta genera una `Application`
- cada namespace preview tambien usa Rollouts BlueGreen

## Como visualizar los ambientes

### Prod estable

```bash
kubectl port-forward -n landing-prod svc/landingpage-active 8081:80
```

Abre:

- [http://localhost:8081](http://localhost:8081)

### Prod preview

```bash
kubectl port-forward -n landing-prod svc/landingpage-preview 8082:80
```

Abre:

- [http://localhost:8082](http://localhost:8082)

### Preview por PR estable

Para un PR `N`, Argo genera:

- namespace: `preview-pr-N`
- servicio estable: `landingpage-active`
- servicio candidato: `landingpage-preview`

Ejemplo para el PR 7:

```bash
kubectl port-forward -n preview-pr-7 svc/landingpage-active 8083:80
```

Abre:

- [http://localhost:8083](http://localhost:8083)

### Preview por PR candidato

```bash
kubectl port-forward -n preview-pr-7 svc/landingpage-preview 8084:80
```

Abre:

- [http://localhost:8084](http://localhost:8084)

Comandos utiles para descubrir previews activos:

```bash
kubectl get applications -n argocd
kubectl get svc --all-namespaces | grep landingpage
kubectl argo rollouts get rollout landingpage -n landing-prod
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

## Scripts operativos

- [scripts/bootstrap-argocd.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/bootstrap-argocd.sh)
  - crea el cluster `kind` si no existe
  - instala Argo CD
  - instala Argo Rollouts
- [scripts/install-argo-rollouts-cli.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/install-argo-rollouts-cli.sh)
  - instala el plugin `kubectl-argo-rollouts` con Homebrew
- [scripts/promote-rollout.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/promote-rollout.sh)
  - promueve una revision BlueGreen
- [scripts/port-forward.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/port-forward.sh)
  - expone la UI de Argo CD

## Runbook corto

### Cuando se abre o actualiza un PR con label `preview`

1. `landing/.github/workflows/sync-preview-gitops.yaml` construye y publica una imagen del PR
2. renderiza manifests con el digest publicado
3. hace commit en `infra/generated/previews/pr-<numero>`
4. el Git generator de Argo detecta esa carpeta
5. crea `landing-pr-<numero>` y el namespace efimero
6. Argo Rollouts expone la nueva revision por `landingpage-preview`
7. la promocion dentro del namespace preview es manual

### Cuando el PR se mergea o cierra

1. el mismo workflow elimina la carpeta `infra/generated/previews/pr-<numero>`
2. Argo detecta que ya no existe en Git
3. elimina la `Application` efimera y hace `prune` de sus recursos

### Cuando hay push a `main` en `landing`

1. `landing/.github/workflows/sync-prod-gitops.yaml` construye y publica una imagen productiva
2. actualiza `infra/generated/environments/prod/landing` con el digest exacto
3. Argo sincroniza `landing-prod`
4. Argo Rollouts crea la nueva revision BlueGreen
5. la nueva revision queda en `landingpage-preview` hasta promocion manual

## Promocion y rollback

Promover `prod`:

```bash
kubectl argo rollouts promote landingpage -n landing-prod
```

Promover un preview:

```bash
kubectl argo rollouts promote landingpage -n preview-pr-7
```

Ver estado:

```bash
kubectl argo rollouts get rollout landingpage -n landing-prod
kubectl argo rollouts get rollout landingpage -n preview-pr-7
```

Abortar un rollout:

```bash
kubectl argo rollouts abort landingpage -n landing-prod
```

## Nota operativa importante

Las imagenes se publican como multi-arquitectura:

- `linux/amd64`
- `linux/arm64`

Eso evita errores como:

- `no match for platform in manifest`

Y permite que la misma imagen funcione tanto en runners x86 como en tu cluster local `kind` sobre `arm64`.

## Beneficios especificos de agregar Argo Rollouts

- introduces una capa de despliegue progresivo sin cambiar el modelo GitOps actual
- puedes validar visualmente una nueva revision antes de promoverla
- reduces riesgo de regresion en `prod`
- habilitas rollback operacional mas claro
- dejas una base lista para futura integracion con metricas y analysis templates
- el patron sirve igual para ambientes efimeros y para `prod`, lo que reduce dispersion operativa
