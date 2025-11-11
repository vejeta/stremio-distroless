#!/bin/bash
# Script para crear Pull Request para las correcciones de CI/CD

echo "=============================================="
echo "   Crear Pull Request - CI/CD Fixes"
echo "=============================================="
echo ""

# Verificar que estamos en el branch correcto
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe" ]; then
    echo "❌ Error: No estás en el branch correcto"
    echo "   Branch actual: $CURRENT_BRANCH"
    echo "   Branch esperado: claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe"
    exit 1
fi

echo "✅ Branch correcto: $CURRENT_BRANCH"
echo ""

# Verificar que todos los commits están pusheados
if git status | grep -q "Your branch is ahead"; then
    echo "❌ Error: Hay commits sin pushear"
    echo "   Ejecuta: git push origin $CURRENT_BRANCH"
    exit 1
fi

echo "✅ Todos los commits están en remote"
echo ""

# Mostrar commits que serán incluidos en el PR
echo "📝 Commits que se incluirán en el PR:"
echo "======================================"
git log a043f5e..HEAD --oneline --graph
echo ""

# Mostrar archivos modificados
echo "📁 Archivos modificados:"
echo "======================================"
git diff --name-status a043f5e..HEAD
echo ""

# URL para crear el PR
PR_URL="https://github.com/vejeta/stremio-distroless/compare/main...claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe"

echo "🚀 Siguiente paso: Crear el Pull Request"
echo "======================================"
echo ""
echo "Opción 1: Crear PR desde la Web (Recomendado)"
echo "   URL: $PR_URL"
echo ""
echo "Opción 2: Usar gh CLI (si está disponible)"
echo "   gh pr create --base main \\"
echo "     --head claude/stremio-distroless-context-011CV1LQ3sR4RtSh93JorpEe \\"
echo "     --title \"fix: GitHub Actions CI/CD for distroless containers\" \\"
echo "     --body-file PR-TEMPLATE.md"
echo ""
echo "Opción 3: GitHub te sugerirá crear PR automáticamente"
echo "   Ve a: https://github.com/vejeta/stremio-distroless"
echo "   Verás un banner amarillo con botón 'Compare & pull request'"
echo ""

# Intentar abrir el navegador (opcional)
read -p "¿Quieres abrir la URL del PR en el navegador? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v xdg-open > /dev/null; then
        xdg-open "$PR_URL"
    elif command -v open > /dev/null; then
        open "$PR_URL"
    else
        echo "⚠️  No se pudo abrir el navegador automáticamente"
        echo "   Abre manualmente: $PR_URL"
    fi
fi

echo ""
echo "=============================================="
echo "   Contenido sugerido para el PR"
echo "=============================================="
echo ""
echo "Título:"
echo "   fix: GitHub Actions CI/CD for distroless containers"
echo ""
echo "Descripción:"
echo "   Ver archivo: PR-TEMPLATE.md"
echo ""
echo "Labels sugeridos:"
echo "   - bug"
echo "   - ci/cd"
echo "   - documentation"
echo ""
