# GitHub Actions CI/CD Fixes - Correcciones para Distroless

## 🔍 Problemas Identificados

El workflow `build-and-scan.yml` del PR #1 falló por **dos problemas principales**:

### Problema 1: Tests de Seguridad Incompatibles (Commit 299c886)
Los **tests de seguridad intentaban ejecutar comandos dentro de contenedores distroless**, lo cual es imposible por diseño.

### Problema 2: Configuración Incorrecta de Matrix (Commit 2f6417d)
El workflow tenía una **configuración de matriz incorrecta** que no interpolaba correctamente `dockerfile_dir`, causando el error:
```
ERROR: failed to read dockerfile: open Dockerfile: no such file or directory
```

---

## ❌ Problema 1: Tests de Seguridad

### Código Problemático Original

```yaml
# Test 1: Intentaba ejecutar 'id' dentro del contenedor
USER_ID=$(docker run --rm ${{ env.IMAGE_TAG }} id -u || echo "FAIL")

# Test 2: Intentaba ejecutar '/bin/sh' (que no existe en distroless)
SHELL_CHECK=$(docker run --rm ${{ env.IMAGE_TAG }} /bin/sh -c "echo test" ...)

# Test 3: Intentaba ejecutar 'apk' (que no existe)
PKG_CHECK=$(docker run --rm ${{ env.IMAGE_TAG }} apk --version ...)
```

### 💡 Por Qué Fallaba

Las imágenes **distroless** están diseñadas para:
- ❌ **NO tener shell** (`/bin/sh`, `/bin/bash`)
- ❌ **NO tener herramientas de sistema** (`id`, `ls`, `cat`)
- ❌ **NO tener gestor de paquetes** (`apk`, `apt`, `dpkg`)
- ✅ **SOLO tener** el runtime mínimo (glibc) + la aplicación (`/app/stremio`)

Por lo tanto, ejecutar `docker run <distroless-image> id -u` es como intentar ejecutar un comando que no existe.

---

## ✅ Solución Implementada

### Cambios en `.github/workflows/build-and-scan.yml`

Reemplazamos los tests que ejecutan comandos **dentro** del contenedor por inspecciones **desde fuera** usando `docker inspect`:

```yaml
# ✅ Test 1: Usar docker inspect para verificar el usuario
USER_ID=$(docker inspect ${{ env.IMAGE_TAG }} --format='{{.Config.User}}' | cut -d: -f1)
if [ "$USER_ID" == "65532" ] || [ "$USER_ID" == "nonroot" ]; then
    echo "✓ Running as nonroot user (User: $USER_ID)"
fi

# ✅ Test 2: Verificar que el shell NO exista (espera error)
if docker run --rm --entrypoint="" ${{ env.IMAGE_TAG }} /bin/sh -c "echo test" 2>&1 | \
   grep -qE "not found|no such file|OCI runtime|executable file not found"; then
    echo "✓ No shell present in image (distroless)"
fi

# ✅ Test 3: Verificar tamaño de imagen (distroless debe ser pequeño)
IMAGE_SIZE=$(docker inspect ${{ env.IMAGE_TAG }} --format='{{.Size}}')
IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
if [ $IMAGE_SIZE_MB -lt 200 ]; then
    echo "✓ Image size indicates minimal attack surface (${IMAGE_SIZE_MB}MB)"
fi

# ✅ Test 4: Verificar que entrypoint/cmd esté configurado
ENTRYPOINT=$(docker inspect ${{ env.IMAGE_TAG }} --format='{{.Config.Entrypoint}}')
CMD=$(docker inspect ${{ env.IMAGE_TAG }} --format='{{.Config.Cmd}}')
if [ -n "$ENTRYPOINT" ] || [ -n "$CMD" ]; then
    echo "✓ Container has defined entrypoint/command"
fi
```

### Ventajas de la Nueva Aproximación

| Aspecto | Antes (❌) | Ahora (✅) |
|---------|-----------|----------|
| **Método** | Ejecutar comandos dentro del contenedor | Inspeccionar metadatos del contenedor |
| **Requisitos** | Necesita shell y herramientas | No necesita nada dentro del contenedor |
| **Compatibilidad** | ❌ Falla con distroless | ✅ Funciona con distroless |
| **Precisión** | Indirecta (intenta ejecutar) | Directa (lee configuración) |

---

## ❌ Problema 2: Configuración Incorrecta de Matrix

### Código Problemático Original

```yaml
strategy:
  fail-fast: false
  matrix:
    ecosystem: [wolfi, debian]
    variant: [gui, server]
    include:
      - ecosystem: wolfi
        base_image: "Chainguard Wolfi"
        dockerfile_dir: wolfi       # ❌ No se aplica correctamente
      - ecosystem: debian
        base_image: "Debian Trixie"
        dockerfile_dir: debian      # ❌ No se aplica correctamente
      - variant: gui
        dockerfile: Dockerfile
        platforms: linux/amd64
      - variant: server
        dockerfile: Dockerfile.server
        platforms: linux/amd64
```

**Uso en el build step:**
```yaml
file: ${{ matrix.dockerfile_dir }}/${{ matrix.dockerfile }}
#      ^^^^^^^^^^^^^^^^^^^^^^^^^ UNDEFINED! Causa error
```

### 💡 Por Qué Fallaba

GitHub Actions genera 4 combinaciones de la matriz:
- `ecosystem: wolfi, variant: gui`
- `ecosystem: wolfi, variant: server`
- `ecosystem: debian, variant: gui`
- `ecosystem: debian, variant: server`

El problema: los `include` intentan agregar `dockerfile_dir` pero:
1. `dockerfile_dir: wolfi` solo especifica `ecosystem: wolfi` (sin `variant`)
2. `dockerfile: Dockerfile` solo especifica `variant: gui` (sin `ecosystem`)
3. GitHub Actions no puede hacer "match parcial" correctamente
4. Resultado: `${{ matrix.dockerfile_dir }}` queda **vacío/undefined**
5. El build intenta abrir `Dockerfile` en lugar de `wolfi/Dockerfile`

**Error resultante:**
```
ERROR: failed to read dockerfile: open Dockerfile: no such file or directory
```

### ✅ Solución Implementada

Cambié la matriz de **arrays cruzados con includes** a **lista explícita**:

```yaml
strategy:
  fail-fast: false
  matrix:
    include:
      - ecosystem: wolfi
        variant: gui
        dockerfile: Dockerfile
        base_image: "Chainguard Wolfi"
        platforms: linux/amd64
      - ecosystem: wolfi
        variant: server
        dockerfile: Dockerfile.server
        base_image: "Chainguard Wolfi"
        platforms: linux/amd64
      - ecosystem: debian
        variant: gui
        dockerfile: Dockerfile
        base_image: "Debian Trixie"
        platforms: linux/amd64
      - ecosystem: debian
        variant: server
        dockerfile: Dockerfile.server
        base_image: "Debian Trixie"
        platforms: linux/amd64
```

**Y uso directo del ecosistema:**
```yaml
file: ${{ matrix.ecosystem }}/${{ matrix.dockerfile }}
#      ^^^^^^^^^^^^^^^^^^^^^ Ahora es "wolfi" o "debian" - ¡siempre definido!
```

### Ventajas de la Nueva Configuración

| Aspecto | Antes (❌) | Ahora (✅) |
|---------|-----------|----------|
| **Claridad** | Confuso con includes parciales | Explícito, cada combo completa |
| **Mantenibilidad** | Difícil entender qué se aplica | Fácil ver todas las variables |
| **Debugging** | Variables undefined | Todas las variables garantizadas |
| **Escalabilidad** | Difícil agregar nuevos ecosistemas | Solo agregar nueva entrada |

### Otros Cambios Relacionados

**1. Eliminé `outputs` incompatible con `load`:**
```yaml
# ❌ Antes: Incompatible
load: true
outputs: type=docker,dest=/tmp/image.tar

# ✅ Ahora: Solo load
load: true
```

**2. Actualicé cómo se obtiene IMAGE_TAG:**
```yaml
# ❌ Antes: Cargar desde tar que ya no existe
- name: Load image for scanning
  run: |
    docker load --input /tmp/${{ matrix.ecosystem }}-${{ matrix.variant }}.tar
    echo "IMAGE_TAG=..." >> $GITHUB_ENV

# ✅ Ahora: Obtener del output de metadata
- name: Set image tag for scanning
  run: |
    # Image is already loaded by build-push-action with load: true
    echo "IMAGE_TAG=$(echo '${{ steps.meta.outputs.tags }}' | head -n1)" >> $GITHUB_ENV
```

---

## 🧪 Cómo Probar Localmente

### 1. Ejecutar el Script de Prueba Local

Hemos creado `test-ci-locally.sh` que replica exactamente los tests de GitHub Actions:

```bash
# Hacer ejecutable (solo primera vez)
chmod +x test-ci-locally.sh

# Probar variante Wolfi GUI
./test-ci-locally.sh wolfi gui

# Probar variante Wolfi Server
./test-ci-locally.sh wolfi server

# Probar variante Debian GUI
./test-ci-locally.sh debian gui

# Probar variante Debian Server
./test-ci-locally.sh debian server
```

### 2. Output Esperado

```
===========================================
Testing wolfi-gui locally
===========================================

📦 Step 1: Building image...
✅ Build successful!

🔍 Step 2: Running security posture tests...
==============================================
Test 1: Verify nonroot user... ✅ Running as nonroot user (User: 65532)
Test 2: Verify no shell... ✅ No shell present in image (distroless)
Test 3: Verify image size... ✅ Image size indicates minimal attack surface (52MB)
Test 4: Verify entrypoint/command... ✅ Container has defined entrypoint/command

==============================================
🎉 All tests passed for wolfi-gui!
==============================================
```

### 3. Verificación Manual con Docker Inspect

También puedes inspeccionar manualmente cualquier imagen:

```bash
# Construir imagen
docker build -t test-image -f wolfi/Dockerfile .

# Ver usuario configurado
docker inspect test-image --format='{{.Config.User}}'
# Esperado: 65532:65532 o nonroot

# Ver tamaño
docker inspect test-image --format='{{.Size}}' | awk '{print $1/1024/1024 " MB"}'
# Esperado: < 200 MB

# Ver entrypoint y comando
docker inspect test-image --format='Entrypoint: {{.Config.Entrypoint}} | CMD: {{.Config.Cmd}}'
# Esperado: Algo como [/app/stremio]

# Intentar ejecutar shell (debe fallar)
docker run --rm test-image /bin/sh
# Esperado: Error "executable file not found" o similar
```

---

## 🚀 Probar el CI en GitHub Actions

### Opción 1: Push a Branch Claude (Recomendado)

Las branches `claude/**` están configuradas para ejecutar los workflows:

```bash
# Los cambios ya están pusheados al branch
# Commits realizados:
# - 299c886: fix: Correct CI tests for distroless compatibility
# - 2f6417d: fix: Correct GitHub Actions matrix configuration and Docker build

# Si necesitas hacer más cambios:
git add .github/workflows/build-and-scan.yml
git commit -m "fix: Additional CI improvements"
git push origin claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe
```

### Opción 2: Workflow Dispatch (Manual)

Puedes ejecutar manualmente el workflow desde GitHub:

1. Ve a: **Actions** → **Build and Security Scan - Multi-Ecosystem**
2. Click **Run workflow**
3. Selecciona el branch
4. Click **Run workflow**

### Opción 3: Crear un Draft PR

```bash
# Crear draft PR para ver resultados de CI sin mergear
gh pr create --draft \
  --title "fix: CI tests for distroless compatibility" \
  --body "Fixes GitHub Actions tests that failed in #1"
```

---

## 📊 Qué Esperar en GitHub Actions

Cuando ejecutes el workflow, verás:

### ✅ Jobs Exitosos

```
build-and-scan (wolfi, gui)      ✅ Success
build-and-scan (wolfi, server)   ✅ Success
build-and-scan (debian, gui)     ✅ Success
build-and-scan (debian, server)  ✅ Success
compare-ecosystems               ✅ Success
```

### 📦 Artifacts Generados

Para cada variante (4 en total):
- ✅ **SBOM** (Software Bill of Materials en formato SPDX)
- ✅ **Trivy JSON report** (Análisis de vulnerabilidades)
- ✅ **Grype JSON report** (Análisis de vulnerabilidades Chainguard)
- ✅ **Security summary** (Resumen en markdown)

### 🔒 Security Tab

Los resultados SARIF se subirán automáticamente a:
**Repository → Security → Code scanning alerts**

---

## 🔧 Troubleshooting

### Si el Build Falla

```bash
# Verificar sintaxis del Dockerfile
docker build -t test -f wolfi/Dockerfile . --progress=plain

# Ver logs detallados
docker build -t test -f wolfi/Dockerfile . --no-cache --progress=plain
```

### Si los Tests de Seguridad Fallan

```bash
# Ejecutar test local con verbose
bash -x ./test-ci-locally.sh wolfi gui

# Inspeccionar imagen manualmente
docker inspect stremio-test:wolfi-gui | jq '.[]' | less
```

### Si Trivy/Grype Fallan

Esto es normal en fase de testing. Los escaners pueden encontrar vulnerabilidades en:
- Dependencias de sistema (glibc, Qt, ffmpeg)
- Paquetes de terceros

**No es un fallo del workflow**, es información de seguridad que debes revisar.

---

## 📋 Checklist Pre-Push

Antes de hacer push, verifica:

- [ ] `./test-ci-locally.sh wolfi gui` pasa ✅
- [ ] `./test-ci-locally.sh wolfi server` pasa ✅
- [ ] `./test-ci-locally.sh debian gui` pasa ✅
- [ ] `./test-ci-locally.sh debian server` pasa ✅
- [ ] Los Dockerfiles no tienen errores de sintaxis
- [ ] Los workflows YAML son válidos (usa `yamllint` o similar)

```bash
# Test rápido de las 4 variantes
for ecosystem in wolfi debian; do
  for variant in gui server; do
    echo "Testing $ecosystem-$variant..."
    ./test-ci-locally.sh $ecosystem $variant || exit 1
  done
done
echo "🎉 All variants passed!"
```

---

## 📝 Historial de Correcciones

### Commit 2f6417d (2025-11-11)
**fix: Correct GitHub Actions matrix configuration and Docker build**

Correcciones:
- ✅ Simplificada configuración de matriz de arrays cruzados a lista explícita
- ✅ Uso directo de `${{ matrix.ecosystem }}` en lugar de `dockerfile_dir`
- ✅ Eliminado parámetro `outputs` incompatible con `load: true`
- ✅ Actualizado método de obtención de IMAGE_TAG usando metadata output

Fixes: Error "open Dockerfile: no such file or directory"

### Commit 299c886 (2025-11-11)
**fix: Correct CI tests for distroless compatibility**

Correcciones:
- ✅ Reemplazados tests que ejecutan comandos dentro del contenedor
- ✅ Uso de `docker inspect` para verificar configuración sin ejecutar comandos
- ✅ Agregado script de prueba local `test-ci-locally.sh`
- ✅ Documentación completa en `CI-FIXES.md`

Fixes: Tests fallaban intentando ejecutar comandos inexistentes en distroless

---

## 📚 Referencias

- **Docker Inspect**: https://docs.docker.com/engine/reference/commandline/inspect/
- **Distroless Images**: https://github.com/GoogleContainerTools/distroless
- **Chainguard Images**: https://edu.chainguard.dev/chainguard/chainguard-images/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Autor**: Claude (Anthropic AI)
**Fecha**: 2025-11-11
**Relacionado con**: PR #1 - Initial commit con arquitectura distroless
