# Infra POC Argo Pull Request Generator

Repositorio de infraestructura GitOps para una POC de Argo CD con previews por Pull Request.

Este repo contiene la parte operativa:

- instalacion local de Argo CD
- bootstrap del cluster `kind`
- `Application` de ambiente estable
- `ApplicationSet` de ambientes efimeros por PR
- configuracion del token de GitHub

## Objetivo de la POC

Demostrar un flujo donde:

1. el repo `landing` contiene la app
2. este repo contiene la declaracion de despliegue
3. Argo CD sincroniza `main` a `landing-prod`
4. `ApplicationSet` crea un ambiente efimero por PR etiquetado con `preview`
5. al mergear o cerrar el PR, el preview se elimina automaticamente

## Repos relacionados

- Landing: [landingPOCArgoPUllRequestGenerator](https://github.com/ju4nr3v0l/landingPOCArgoPUllRequestGenerator)
- Infra: [InfraPOCArgoPUllRequestGenerator](https://github.com/ju4nr3v0l/InfraPOCArgoPUllRequestGenerator)

## Estructura

```text
.
├── README.md
├── argocd
│   ├── applications
│   │   └── landing-prod.yaml
│   └── applicationsets
│       └── landing-pr-previews.yaml
└── scripts
    ├── bootstrap-argocd.sh
    ├── create-github-secret.sh
    └── port-forward.sh
```

## Archivos clave

- [argocd/applications/landing-prod.yaml](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/argocd/applications/landing-prod.yaml): `Application` estable
- [argocd/applicationsets/landing-pr-previews.yaml](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/argocd/applicationsets/landing-pr-previews.yaml): `ApplicationSet` de previews
- [scripts/bootstrap-argocd.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/bootstrap-argocd.sh): crea cluster e instala Argo CD
- [scripts/create-github-secret.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/create-github-secret.sh): crea el secret `github-token`
- [scripts/port-forward.sh](/Users/juanmarulanda/Documents/POCArgoPull%20Request%20Generator/infra/scripts/port-forward.sh): expone la UI de Argo CD

## Prerrequisitos

### Locales

- macOS o Linux
- Docker Desktop o runtime Docker compatible
- `kubectl`
- `kind`
- `argocd` CLI opcional
- conectividad a GitHub

### GitHub

- repo de `landing`
- repo de `infra`
- token con permisos de lectura al repo y PRs
- label `preview` creado en el repo de `landing`

### Kubernetes

- cluster local accesible por `kubectl`
- permisos para instalar Argo CD en el namespace `argocd`

## Configuracion actual de la POC

### Ambiente estable

La app estable esta definida en:

- `argocd/applications/landing-prod.yaml`

Caracteristicas:

- `repoURL` apunta al repo de `landing`
- `targetRevision: main`
- `path: k8s/prod`
- `prune: true`
- `selfHeal: true`
- `CreateNamespace=true`

### Ambientes efimeros por PR

El generador esta definido en:

- `argocd/applicationsets/landing-pr-previews.yaml`

Caracteristicas:

- `pullRequest.github.owner: ju4nr3v0l`
- `pullRequest.github.repo: landingPOCArgoPUllRequestGenerator`
- filtra por label `preview`
- hace polling cada `180` segundos
- usa `targetRevision: {{.head_sha}}`
- crea namespaces `preview-pr-{{.number}}`
- usa `nameSuffix: -pr-{{.number}}`

## Pasos de instalacion y uso

### 1. Crear cluster e instalar Argo CD

```bash
./scripts/bootstrap-argocd.sh
```

Esto hace:

- crea el cluster `kind` llamado `argocd-poc` si no existe
- crea namespace `argocd`
- instala Argo CD desde el manifest oficial
- espera `argocd-server` y `argocd-applicationset-controller`

### 2. Exponer la UI

```bash
./scripts/port-forward.sh
```

UI:

- [https://localhost:8080](https://localhost:8080)

### 3. Obtener password inicial

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode && echo
```

### 4. Crear secret del token GitHub

```bash
export GITHUB_TOKEN="<tu-token>"
./scripts/create-github-secret.sh
```

### 5. Aplicar manifests GitOps

```bash
kubectl apply -f argocd/applications/landing-prod.yaml
kubectl apply -f argocd/applicationsets/landing-pr-previews.yaml
```

### 6. Validar estado

```bash
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
kubectl get ns
```

## Flujo operativo esperado

### Flujo estable

1. se hace merge a `main` en el repo `landing`
2. Argo detecta cambios en Git
3. sincroniza `landing-prod`
4. actualiza `ConfigMap`, `Service` y `Deployment` en `landing-prod`

### Flujo por PR

1. se abre un PR en `landing`
2. se agrega label `preview`
3. el `ApplicationSet` detecta el PR
4. crea `landing-pr-<numero>`
5. crea namespace `preview-pr-<numero>`
6. despliega el commit exacto del PR
7. al cerrar o mergear el PR, elimina la app efimera

## Validaciones utiles

### Estado de Argo CD

```bash
kubectl get pods -n argocd
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

### Ambiente estable

```bash
kubectl port-forward -n landing-prod svc/landingpage 8081:80
```

- [http://localhost:8081](http://localhost:8081)

### Ambiente efimero

Ejemplo para PR 2:

```bash
kubectl port-forward -n preview-pr-2 svc/landingpage-pr-2 8082:80
```

- [http://localhost:8082](http://localhost:8082)

## Configuraciones importantes a conocer

### Polling del Pull Request Generator

La deteccion del PR no es instantanea hoy.

En esta POC:

- `requeueAfterSeconds: 180`

Eso significa que el `ApplicationSet` revisa GitHub cada 3 minutos.

### Deteccion inmediata

Para evitar la espera de polling, la recomendacion oficial es configurar webhook hacia:

- `/api/webhook`

Pero en local eso requiere exponer Argo al exterior con:

- `ngrok`
- `cloudflared`
- ingress publico

### Prune y self-heal

La POC deja activos:

- `prune: true`
- `selfHeal: true`

Eso ayuda a que:

- recursos obsoletos se eliminen automaticamente
- drift manual en cluster se corrija

## Beneficios esperados para Sistecredito

En un contexto como Sistecredito, esta POC puede aportar valor especialmente en frentes donde varias areas necesitan revisar cambios antes de liberar:

- producto puede validar copy, layout o microcambios sin esperar despliegues manuales
- QA puede revisar una rama exacta, no una mezcla de cambios en ambiente compartido
- arquitectura y seguridad pueden inspeccionar manifests y trazabilidad GitOps
- desarrollo reduce friccion al demostrar cambios con una URL por PR
- liderazgo tecnico gana visibilidad sobre que commit llego a cada ambiente

## Ahorro potencial para Sistecredito

### Ahorro de tiempo

Si hoy un equipo necesita coordinar manualmente un ambiente temporal por cambio, el ahorro potencial esta en:

- menos tiempo de espera entre dev y QA
- menos reproceso por validar una version incorrecta
- menos uso de ambientes compartidos para demos pequenos

Escenarios de referencia:

- 50 PRs/mes x 15 min de ahorro = 12.5 horas/mes
- 80 PRs/mes x 20 min de ahorro = 26.7 horas/mes
- 120 PRs/mes x 30 min de ahorro = 60 horas/mes

### Ahorro de infraestructura

En esta POC local el costo incremental es casi nulo porque los previews viven en un cluster local.

En una evolucion real en nube, el ahorro vendria de:

- no mantener ambientes permanentes por rama o por desarrollador
- crear previews solo cuando un PR lo necesita
- destruirlos automaticamente despues de merge o cierre

### Como llevarlo a numeros internos

Formula recomendada:

`cantidad de PRs x minutos ahorrados x costo blended por hora`

Y, por separado:

`costo de ambientes permanentes evitados - costo de ambientes efimeros reales`

## Riesgos de la POC

### Riesgos tecnicos

- hoy el token GitHub se carga manualmente
- no hay webhook, asi que el tiempo de reaccion depende del polling
- la app usa `ConfigMap` como contenido web, patron valido para demo pero no ideal para escala
- la deteccion por label depende de disciplina operativa del equipo

### Riesgos de seguridad

- el PR generator tiene implicaciones de seguridad y debe ser administrado con cuidado
- no conviene templar `project` libremente para PRs
- no conviene usar tokens amplios si basta un alcance minimo
- no conviene dejar secretos fuera de un gestor de secretos

### Riesgos operativos

- sin quotas, muchos previews concurrentes pueden consumir recursos innecesarios
- sin politicas de limpieza adicionales, un namespace podria tardar en desaparecer aunque los recursos ya se hayan borrado

## Mejores practicas recomendadas

### GitOps y Argo CD

- separar claramente repo de app y repo de infraestructura
- usar `AppProject` dedicado en vez de `default`
- limitar destinos, namespaces y repos permitidos por proyecto
- mantener `prune` y `selfHeal` donde el riesgo sea aceptable
- exponer webhook para eliminar latencia de polling

### Seguridad

- migrar el token manual a un secreto gestionado
- preferir token fine-grained o GitHub App sobre PAT amplio
- restringir quien puede crear o modificar `ApplicationSet`
- agregar `NetworkPolicy`, `ResourceQuota` y `LimitRange` para previews

### Operacion

- definir convencion de labels como `preview`, `demo`, `qa`
- agregar observabilidad minima para saber cuantos previews estan vivos
- definir TTL operativo o rutina de auditoria para namespaces de preview

### Plataforma

- mover el contenido de demo a imagen versionada en una siguiente fase
- usar un registry corporativo
- fijar imagenes por digest
- agregar CI para validar manifests, lint y smoke tests

## Roadmap recomendado

### Fase 1. Estabilizar la POC actual

- probar multiples PRs concurrentes
- documentar tiempos reales de deteccion
- verificar limpieza automatica tras merge y cierre
- estandarizar el uso del label `preview`

### Fase 2. Hardening minimo

- crear `AppProject` dedicado
- mover el token a secreto gestionado
- agregar quotas y limites por namespace preview
- documentar runbooks de troubleshooting

### Fase 3. Deteccion inmediata

- exponer `/api/webhook`
- configurar webhook GitHub para eventos de PR
- medir diferencia entre polling y webhook

### Fase 4. Camino a produccion

- sustituir `ConfigMap` por imagen construida en CI
- integrar escaneo de dependencias y seguridad
- agregar ingress por hostname para previews
- integrar comentario automatico en PR con URL del preview

### Fase 5. Estandar corporativo

- convertir este patron en plantilla reusable para otros equipos
- incluir guias de naming, ownership y costos
- conectar con controles de seguridad y aprobacion de cambios

## Runbook de troubleshooting

### El PR no crea preview

Revisar:

- que el PR tenga label `preview`
- que el token GitHub exista en `argocd`
- que el repo y owner en el `ApplicationSet` sean correctos
- que hayan pasado al menos 3 minutos si no hay webhook

Comandos utiles:

```bash
kubectl get applications -n argocd
kubectl get applicationset landing-pr-previews -n argocd -o yaml
kubectl get ns | grep preview-pr || true
```

### El preview existe pero no carga

Revisar:

- pods en `preview-pr-<numero>`
- service generado con sufijo del PR
- contenido del `ConfigMap`

### Prod no refleja el merge

Revisar:

- estado de `landing-prod`
- ultimo `revision` sincronizado en Argo
- contenido del `ConfigMap` `landingpage-content`

## Referencias oficiales

- [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/release-3.4/getting_started/)
- [Argo CD ApplicationSet Introduction](https://argo-cd.readthedocs.io/en/release-3.4/operator-manual/applicationset/)
- [Argo CD Pull Request Generator](https://argo-cd.readthedocs.io/en/release-3.4/operator-manual/applicationset/Generators-Pull-Request/)
- [Argo CD Git Generator and Webhooks](https://argo-cd.readthedocs.io/en/release-3.4/operator-manual/applicationset/Generators-Git/)
- [Argo CD Sync Options](https://argo-cd.readthedocs.io/en/release-3.4/user-guide/sync-options/)
- [Argo CD Automated Sync](https://argo-cd.readthedocs.io/en/release-3.2/user-guide/auto_sync/)
