# ==============================================================================
# SANDER GEVAZP DECOMP - Gerador de Vazões Sintéticas para DECOMP
# ==============================================================================
# Developed by Sander
# Repositório: https://github.com/fabiosandernt/rmgevazp_decomp
# ==============================================================================

FROM rocker/r-ver:4.3.2

LABEL maintainer="Sander <fabio.sander@ons.org.br>"
LABEL description="SANDER GEVAZP - Gerador de vazoes.rv0 para DECOMP"
LABEL version="3.0"

# Desabilitar buffer para streaming em tempo real
ENV R_INTERACTIVE_DEVICE=1

WORKDIR /app

# Copiar código R
COPY R/ /app/R/

# Copiar dados (topologia de cascata)
COPY data/ /app/data/

# Criar diretório de dados (será montado pelo volume)
RUN mkdir -p /data

# Copiar entrypoint
COPY docker-entrypoint.sh /app/
RUN chmod +x /app/docker-entrypoint.sh

# Usar entrypoint customizado
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["validacao"]
