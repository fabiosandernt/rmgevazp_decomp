#!/bin/bash
# ==============================================================================
# docker-entrypoint.sh - Ponto de entrada do container SANDER GEVAZP DECOMP
# ==============================================================================
# Developed by Sander
# ==============================================================================

set -e

# Diretório de dados (montado via volume)
DATA_DIR="${GEVAZP_DATA_DIR:-/data}"

# Banner
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        SANDER GEVAZP - DECOMP v3.0                            ║"
echo "║                           Developed by Sander                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se diretório de dados existe e tem arquivos
if [ ! -d "$DATA_DIR" ]; then
    echo "ERRO: Diretório de dados não encontrado: $DATA_DIR"
    echo "Monte o volume com: docker run -v /caminho/deck:/data ..."
    exit 1
fi

# Verificar arquivo essencial
if [ ! -f "$DATA_DIR/caso.dat" ] && [ ! -f "$DATA_DIR/CASO.DAT" ]; then
    echo "ERRO: caso.dat não encontrado em $DATA_DIR"
    echo "Arquivos disponíveis:"
    ls -la "$DATA_DIR"
    exit 1
fi

# Determinar modo de execução
MODE="${1:-validacao}"

case "$MODE" in
    validacao|completo)
        echo "Modo: $MODE"
        echo "Dados: $DATA_DIR"
        echo ""
        exec stdbuf -oL Rscript /app/R/main.r "$DATA_DIR" "$MODE"
        ;;
    test)
        echo "Executando testes..."
        exec Rscript -e "testthat::test_dir('/app/tests')"
        ;;
    shell|bash)
        exec /bin/bash
        ;;
    help|--help|-h)
        echo "Uso: docker run -v /caminho/deck:/data sander-gevazp-decomp [MODO]"
        echo ""
        echo "Modos disponíveis:"
        echo "  validacao  - Gera vazoes.rv0 100% idêntico ao CEPEL (padrão)"
        echo "  completo   - Gera vazoes.rv0 com cenários próprios PAR(p)"
        echo "  shell      - Abre terminal bash no container"
        echo "  help       - Mostra esta ajuda"
        echo ""
        echo "Exemplo:"
        echo "  docker run -v D:\\GEVAZP_TESTE:/data sander-gevazp-decomp validacao"
        echo ""
        exit 0
        ;;
    *)
        # Passar comando diretamente
        exec "$@"
        ;;
esac
