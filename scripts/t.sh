#!/bin/bash
# Build explicitement les tests puis les lance (affiche seulement les erreurs et le résumé).
cd "$(dirname "$0")/.."
swift build --build-tests 2>&1 | grep -E "error" | head -${ERRLINES:-8}
swift test "$@" 2>&1 | grep -E "error|✘|Test run" | tail -${ERRLINES:-8}
