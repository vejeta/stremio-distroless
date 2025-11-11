# Análisis de Posibles Errores en GitHub Actions

**Fecha**: 2025-11-11
**Branch**: claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe

---

## ✅ Verificaciones Locales Pasadas

| Verificación | Estado | Detalles |
|--------------|--------|----------|
| YAML Syntax | ✅ Válido | Parsea correctamente con PyYAML |
| Matrix Config | ✅ OK | 4 combinaciones definidas |
| Dockerfiles | ✅ Todos presentes | wolfi/debian × gui/server |
| Usuario nonroot | ✅ Configurado | UID 65532 en Dockerfiles |
| Scripts | ✅ Ejecutables | test-ci-locally.sh, CREATE-PR.sh |

---

## 🔍 Posibles Errores que Podrían Ocurrir

### 1. Error en Build Step

#### Síntoma:
```
ERROR: failed to solve: failed to fetch ...
ERROR: failed to solve: pull access denied
```

#### Causas Posibles:
1. **Paquetes no disponibles**: Los repositorios de Wolfi o Debian podrían estar caídos
   - Wolfi: `https://sourceforge.net/projects/wolfi/files/x86_64/`
   - Debian: `https://debian.vejeta.com`

2. **Imágenes base no disponibles**:
   - `cgr.dev/chainguard/wolfi-base:latest`
   - `cgr.dev/chainguard/glibc-dynamic:latest`
   - `debian:trixie-slim`
   - `gcr.io/distroless/base-debian12:nonroot`

3. **Rate limiting**: GitHub Actions puede tener límite de pulls de imágenes

#### Solución:
- Verificar que los repositorios estén accesibles
- Agregar retry logic al build
- Usar cache de GitHub Actions (ya configurado)

---

### 2. Error en IMAGE_TAG Step

#### Síntoma:
```
IMAGE_TAG is empty
No such image:
```

#### Causa:
El `steps.meta.outputs.tags` podría no tener el formato esperado

#### Verificación:
```yaml
# En el workflow (línea 108):
echo "IMAGE_TAG=$(echo '${{ steps.meta.outputs.tags }}' | head -n1)" >> $GITHUB_ENV
```

#### Solución si falla:
```yaml
# Alternativa más robusta:
- name: Set image tag for scanning
  run: |
    IMAGE_ID=$(docker images --format '{{.ID}}' | head -n1)
    IMAGE_TAG=$(docker images --format '{{.Repository}}:{{.Tag}}' $IMAGE_ID | head -n1)
    echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV
    echo "Using image tag: $IMAGE_TAG"
```

---

### 3. Error en Security Tests

#### Síntoma:
```
USER_ID is not 65532 or nonroot
✗ NOT running as nonroot user
```

#### Causa:
El Dockerfile podría tener un USER diferente o no estar configurado

#### Verificación:
```bash
# Verificar en Dockerfiles:
grep "^USER" wolfi/Dockerfile
grep "^USER" debian/Dockerfile
```

#### Solución:
Asegurarse que ambos Dockerfiles tengan:
```dockerfile
USER 65532:65532
# o
USER nonroot:nonroot
```

---

### 4. Error en SBOM Generation

#### Síntoma:
```
Error: failed to generate SBOM
Error: image not found
```

#### Causa:
La imagen no está cargada correctamente o IMAGE_TAG está mal

#### Solución:
```yaml
# Verificar que la imagen existe antes de SBOM:
- name: Verify image loaded
  run: |
    docker images
    docker inspect ${{ env.IMAGE_TAG }} || exit 1
```

---

### 5. Error en Trivy/Grype Scan

#### Síntoma:
```
Error: failed to scan image
Error: timeout exceeded
```

#### Causa:
- Timeout por imagen muy grande
- Scanner no puede acceder a la imagen
- Demasiadas vulnerabilidades encontradas

#### Notas:
- **Esto NO es un fallo del workflow**
- Es normal encontrar vulnerabilidades en fase de testing
- Los escaneos no deberían hacer fallar el build (tienen `fail-build: false`)

---

### 6. Error en Shell Test

#### Síntoma:
```
⚠ Shell may be present - manual verification recommended
```

#### Causa:
El test espera que intentar ejecutar `/bin/sh` falle, pero podría no fallar como esperamos

#### Test actual (línea 214):
```bash
if docker run --rm --entrypoint="" ${{ env.IMAGE_TAG }} /bin/sh -c "echo test" 2>&1 | \
   grep -qE "not found|no such file|OCI runtime|executable file not found"; then
    echo "✓ No shell present in image (distroless)"
else
    echo "⚠ Shell may be present - manual verification recommended"
fi
```

#### Solución si da falso positivo:
```bash
# Test más específico:
if docker run --rm --entrypoint="" ${{ env.IMAGE_TAG }} test -f /bin/sh 2>&1 | \
   grep -qE "OCI runtime create failed|executable file not found"; then
    echo "✓ No shell present (distroless confirmed)"
fi
```

---

### 7. Error de Permisos

#### Síntoma:
```
Error: permission denied
Error: cannot create directory
```

#### Causa:
GitHub Actions runner no tiene permisos para escribir artifacts

#### Solución:
Ya está configurado con:
```yaml
permissions:
  contents: read
  packages: write
  security-events: write
```

---

## 🎯 Errores Más Probables (Ranking)

### 🔴 Alta Probabilidad

1. **Repositorios de paquetes inaccesibles** (50%)
   - Solución: Verificar conectividad, agregar fallbacks

2. **IMAGE_TAG malformado** (30%)
   - Solución: Usar alternativa más robusta

### 🟡 Media Probabilidad

3. **Imágenes base no disponibles** (15%)
   - Solución: Pre-pull o usar cache

4. **Timeout en builds grandes** (10%)
   - Solución: Aumentar timeout, optimizar Dockerfiles

### 🟢 Baja Probabilidad

5. **Falsos positivos en tests de seguridad** (5%)
   - Nota: No bloquea, solo warning

---

## 📋 Checklist de Diagnóstico

Cuando veas un error, sigue este orden:

1. **Identifica el step que falló**
   - [ ] ¿Es el build?
   - [ ] ¿Es el set image tag?
   - [ ] ¿Son los security tests?
   - [ ] ¿Es SBOM/scanning?

2. **Busca el error exacto**
   - [ ] Copia las últimas 30-50 líneas
   - [ ] Identifica el comando que falló
   - [ ] Busca el mensaje de error específico

3. **Verifica el commit SHA**
   - [ ] ¿Qué commit estaba ejecutando?
   - [ ] ¿Es 2f6417d (con correcciones) o anterior?

4. **Comparte información**
   - [ ] Workflow name
   - [ ] Job name
   - [ ] Step name
   - [ ] Error completo
   - [ ] Commit SHA

---

## 🔧 Comandos de Debug

Si necesitas información adicional del workflow:

```bash
# Ver matriz expandida
cat .github/workflows/build-and-scan.yml | \
  python3 -c "import sys,yaml; y=yaml.safe_load(sys.stdin); \
  [print(f'{i}: {c}') for i,c in enumerate(y['jobs']['build-and-scan']['strategy']['matrix']['include'])]"

# Verificar paths que el workflow usará
for ecosystem in wolfi debian; do
  for dockerfile in Dockerfile Dockerfile.server; do
    echo "Testing: $ecosystem/$dockerfile"
    [ -f "$ecosystem/$dockerfile" ] && echo "  ✅ Exists" || echo "  ❌ Missing"
  done
done

# Simular el comando de build
echo "El workflow ejecutará:"
for eco in wolfi debian; do
  for df in Dockerfile Dockerfile.server; do
    [ -f "$eco/$df" ] && echo "docker build -f $eco/$df ."
  done
done
```

---

## 🆘 Qué Compartir para Obtener Ayuda

Para diagnóstico efectivo, necesito:

### Información Mínima
```
Workflow: Build and Security Scan - Multi-Ecosystem
Job: build-and-scan (wolfi, gui)
Step: Build Docker image
Commit: 2f6417d
Error: [copiar aquí las últimas 30 líneas]
```

### Información Completa (Ideal)
- Screenshot del error en GitHub Actions
- URL del workflow run
- Logs completos del job que falló
- Contexto: ¿primera vez que falla o falla consistentemente?

---

## 📚 Referencias Útiles

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Docker Build Push Action**: https://github.com/docker/build-push-action
- **Metadata Action**: https://github.com/docker/metadata-action
- **Trivy Action**: https://github.com/aquasecurity/trivy-action
- **Grype/Anchore**: https://github.com/anchore/scan-action

---

**Última actualización**: 2025-11-11
**Mantener actualizado**: Agregar nuevos errores según se descubran
