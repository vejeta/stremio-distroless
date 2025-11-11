# GitHub Actions CI/CD Fixes - Correcciones para Distroless

## 🔍 Problema Identificado

El workflow `build-and-scan.yml` del PR #1 falló porque los **tests de seguridad intentaban ejecutar comandos dentro de contenedores distroless**, lo cual es imposible por diseño.

### ❌ Código Problemático Original

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
# Los cambios ya están en el branch actual
git add .github/workflows/build-and-scan.yml test-ci-locally.sh CI-FIXES.md
git commit -m "fix: Correct CI tests for distroless compatibility

- Replace docker run commands with docker inspect
- Tests now work with distroless images (no shell required)
- Add local testing script (test-ci-locally.sh)
- Document fixes in CI-FIXES.md

Fixes compatibility issues from PR #1 where tests attempted to
execute commands inside distroless containers."

git push -u origin claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe
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

## 📚 Referencias

- **Docker Inspect**: https://docs.docker.com/engine/reference/commandline/inspect/
- **Distroless Images**: https://github.com/GoogleContainerTools/distroless
- **Chainguard Images**: https://edu.chainguard.dev/chainguard/chainguard-images/
- **GitHub Actions**: https://docs.github.com/en/actions

---

**Autor**: Claude (Anthropic AI)
**Fecha**: 2025-11-11
**Relacionado con**: PR #1 - Initial commit con arquitectura distroless
