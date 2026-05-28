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
