# Fix GitHub Actions CI/CD for Distroless Containers

## 🎯 Objetivo

Corregir los fallos en GitHub Actions workflows que impedían el correcto build y testing de las imágenes distroless de Stremio.

## 🐛 Problemas Corregidos

### Problema 1: Tests de Seguridad Incompatibles con Distroless
**Error**: Los tests intentaban ejecutar comandos (`id`, `/bin/sh`, `apk`) dentro de contenedores distroless que no tienen shell ni herramientas.

**Solución**: Usar `docker inspect` para verificar configuración desde fuera del contenedor.

### Problema 2: Configuración Incorrecta de Matrix
**Error**:
```
ERROR: failed to read dockerfile: open Dockerfile: no such file or directory
```

**Causa**: La variable `${{ matrix.dockerfile_dir }}` quedaba `undefined` debido a matching incorrecto de GitHub Actions `include`.

**Solución**: Cambiar de matriz con arrays cruzados a lista explícita de 4 combinaciones.

## 📝 Cambios Realizados

### Commits Incluidos (3)

1. **299c886** - `fix: Correct CI tests for distroless compatibility`
   - Reemplazar tests que ejecutan comandos dentro del contenedor
   - Usar `docker inspect` para verificaciones
   - Agregar script de prueba local `test-ci-locally.sh`

2. **2f6417d** - `fix: Correct GitHub Actions matrix configuration and Docker build`
   - Simplificar matriz a lista explícita
   - Usar `${{ matrix.ecosystem }}` directamente
   - Eliminar parámetro `outputs` incompatible con `load: true`
   - Actualizar obtención de IMAGE_TAG

3. **34a4a84** - `docs: Update CI-FIXES.md with matrix configuration problem`
   - Documentación completa de ambos problemas
   - Guía de troubleshooting
   - Historial de correcciones

### Archivos Modificados

- ✏️ `.github/workflows/build-and-scan.yml` (correcciones críticas)
- 🆕 `test-ci-locally.sh` (script de prueba local)
- 🆕 `CI-FIXES.md` (documentación completa)

## ✅ Tests de Seguridad Corregidos

### Antes (❌)
```yaml
# Intentaba ejecutar comandos dentro del contenedor distroless
USER_ID=$(docker run --rm $IMAGE id -u)  # ❌ 'id' no existe
```

### Ahora (✅)
```yaml
# Usa docker inspect para verificar sin ejecutar comandos
USER_ID=$(docker inspect $IMAGE --format='{{.Config.User}}')  # ✅ Funciona
```

## 🔧 Configuración de Matrix Corregida

### Antes (❌)
```yaml
matrix:
  ecosystem: [wolfi, debian]
  variant: [gui, server]
  include:
    - ecosystem: wolfi
      dockerfile_dir: wolfi  # ❌ No se aplica correctamente
```

### Ahora (✅)
```yaml
matrix:
  include:
    - ecosystem: wolfi
      variant: gui
      dockerfile: Dockerfile  # ✅ Todo explícito
    # ... (3 combinaciones más)
```

## 🧪 Pruebas Realizadas

### Local
```bash
# Script de prueba creado y ejecutable
./test-ci-locally.sh wolfi gui    # ✅ Replica tests de CI
./test-ci-locally.sh wolfi server
./test-ci-locally.sh debian gui
./test-ci-locally.sh debian server
```

### Validaciones
- ✅ YAML syntax válido (`python3 -c "import yaml; yaml.safe_load(...)"`)
- ✅ Todos los Dockerfiles existen (wolfi/debian × gui/server)
- ✅ Path del Dockerfile correcto (`${{ matrix.ecosystem }}/${{ matrix.dockerfile }}`)
- ✅ Usuario nonroot configurado (UID 65532)

## 📊 Impacto Esperado

### Jobs que deberían pasar ahora:
- ✅ `build-and-scan (wolfi, gui)`
- ✅ `build-and-scan (wolfi, server)`
- ✅ `build-and-scan (debian, gui)`
- ✅ `build-and-scan (debian, server)`
- ✅ `compare-ecosystems`

### Artifacts generados:
- 📄 SBOM (4 archivos - SPDX format)
- 🔍 Trivy reports (4 archivos JSON)
- 🔍 Grype reports (4 archivos JSON)
- 📋 Security summaries (4 archivos MD)
- 📊 Ecosystem comparison report

## 📚 Documentación

Ver `CI-FIXES.md` para:
- Análisis detallado de cada problema
- Explicación de las soluciones
- Guía de pruebas locales
- Troubleshooting
- Referencias

## 🔗 Referencias

- **Problema Original**: #1 (Initial commit con arquitectura distroless)
- **Documentación**: [CI-FIXES.md](CI-FIXES.md)
- **Script de Prueba**: [test-ci-locally.sh](test-ci-locally.sh)

## ✅ Checklist Pre-Merge

- [x] YAML syntax válido
- [x] Todos los Dockerfiles existen
- [x] Matrix configuration correcta
- [x] Tests usan `docker inspect` (compatible con distroless)
- [x] Documentación completa agregada
- [x] Script de prueba local incluido
- [ ] GitHub Actions workflows pasan (verificar después del merge)

---

**Tipo**: 🐛 Bug Fix
**Prioridad**: 🔴 Alta (Bloquea CI/CD)
**Reviewed**: Correcciones verificadas localmente
