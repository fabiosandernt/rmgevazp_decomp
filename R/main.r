#!/usr/bin/env Rscript
# =============================================================================
# SANDER GEVAZP v3.0 - Versão Completa
# =============================================================================
# Gerador de Vazões Sintéticas para DECOMP
# Desenvolvido por Sander
# Metodologia: Periodic AutoRegressive com Yule-Walker
# =============================================================================

cat("
╔═══════════════════════════════════════════════════════════════════════════════╗
║                              SANDER GEVAZP v3.0                               ║
║                   Gerador de Vazões Sintéticas para DECOMP                    ║
║                           Developed by Sander                                 ║
║                  Periodic AutoRegressive com Yule-Walker                      ║
╚═══════════════════════════════════════════════════════════════════════════════╝
")

# =============================================================================
# CONFIGURAÇÃO INICIAL
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Uso: Rscript sander_gevazp_v3.r <diretorio_dados> [modo]
  modo: 'completo' (default) - gera cenários próprios
        'validacao' - usa cenários do oficial para validar")
}

dir_dados <- args[1]
modo <- if (length(args) > 1) args[2] else "completo"
setwd(dir_dados)

cat("\n[CONFIG] Diretório:", dir_dados, "\n")
cat("[CONFIG] Modo:", modo, "\n")

# Carregar funções
# Detectar diretório do script
script_dir <- tryCatch({
  # Quando executado via Rscript
  args <- commandArgs()
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    dirname(normalizePath(sub("--file=", "", file_arg)))
  } else {
    # Fallback para diretório atual
    getwd()
  }
}, error = function(e) getwd())

source_if_exists <- function(f) {
  paths <- c(
    file.path(script_dir, f),
    file.path("/home/sander/Projects/rmgevazp_decomp/R", f),
    f
  )
  for (p in paths) {
    if (file.exists(p)) {
      source(p)
      return(TRUE)
    }
  }
  cat("AVISO: Arquivo não encontrado:", f, "\n")
  FALSE
}

cat("\n[LOAD] Carregando funções...\n")
source_if_exists("io_arquivos.r")
source_if_exists("parp_functions.r")
source_if_exists("cenarios_functions.r")
source_if_exists("ena_topologia_functions.r")

# =============================================================================
# ETAPA 1: LEITURA DOS DADOS DE ENTRADA
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 1: LEITURA DOS DADOS DE ENTRADA\n")
cat(paste(rep("=", 79), collapse=""), "\n")

# Ler todos os arquivos de entrada
dados <- ler_todos_arquivos(dir_dados)

# Extrair variáveis principais para uso posterior
dadger <- dados$dadger
vaz_total_prevs <- dados$prevs
historico <- dados$historico
n_anos <- dim(historico)[3]

cat("\n[RESUMO]\n")
cat("  Usinas:", length(dadger$codigos), "\n")
cat("  Cenários:", dadger$n_cenarios, "\n")
cat("  Mês início:", dadger$mes_inicio, "/", dadger$ano_inicio, "\n")
cat("  Anos histórico:", n_anos, "(1931-", 1930 + n_anos, ")\n")
cat("  Postos com previsão:", sum(apply(vaz_total_prevs, 1, sum) > 0), "\n")

# 1.4 TOPOLOGIA
cat("\n[1.4] Extraindo topologia de cascata...\n")

# Função auxiliar para carregar topologia de arquivo texto
carregar_topologia_txt <- function(arquivo) {
  top_lines <- readLines(arquivo)
  topo <- list()
  for (linha in top_lines) {
    nums <- as.integer(strsplit(trimws(linha), "\\s+")[[1]])
    if (length(nums) >= 2) {
      posto <- nums[1]
      if (posto >= 1 && posto <= 320) {
        topo[[as.character(posto)]] <- list(
          jusante = nums[2],
          montantes = if (length(nums) > 2) nums[3:length(nums)] else integer(0)
        )
      }
    }
  }
  topo
}

# Locais onde procurar o arquivo de topologia (em ordem de prioridade)
topologia_paths <- c(
  file.path(script_dir, "..", "data", "topologia_cascata.txt"),  # Projeto local
  "/app/data/topologia_cascata.txt",                              # Docker
  "/tmp/topologia_final3.txt",                                    # Temp local
  "topologia_cascata.txt"                                         # Diretório atual
)

topologia <- NULL
for (topo_path in topologia_paths) {
  if (file.exists(topo_path)) {
    cat("  Usando arquivo de topologia:", topo_path, "\n")
    topologia <- carregar_topologia_txt(topo_path)
    break
  }
}

# Se não achou arquivo pré-extraído, tentar extrair do relatório
if (is.null(topologia) && file.exists("gevazp.rel")) {
  cat("  Extraindo do relatório GEVAZP...\n")
  topologia <- extrair_topologia("gevazp.rel")
}

if (is.null(topologia) || length(topologia) == 0) {
  stop("Não foi possível obter topologia. Execute GEVAZP primeiro para gerar gevazp.rel")
}
cat("  Postos na topologia:", length(topologia), "\n")

# =============================================================================
# ETAPA 2: CONVERSÃO TOTAL → INCREMENTAL
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 2: CONVERSÃO TOTAL → INCREMENTAL\n")
cat(paste(rep("=", 79), collapse=""), "\n")

vaz_incr_prevs <- converter_para_incremental(vaz_total_prevs, topologia)

cat("\n  Verificação (semana 1):\n")
cat("    Posto 1 (CAMARGOS): total=", vaz_total_prevs[1,1], 
    ", incr=", vaz_incr_prevs[1,1], "\n")
cat("    Posto 6 (FURNAS):   total=", vaz_total_prevs[6,1], 
    ", incr=", vaz_incr_prevs[6,1], "\n")

# =============================================================================
# ETAPA 3: AJUSTE DO MODELO PAR(p)
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 3: AJUSTE DO MODELO PAR(p)\n")
cat(paste(rep("=", 79), collapse=""), "\n")

cat("\n[3.1] Ajustando modelo PAR(p) ao histórico...\n")
modelo_parp <- ajustar_parp(historico, p_max = 6)

# Estatísticas do modelo
ordens <- modelo_parp$ordem[modelo_parp$ordem > 0]
cat("\n  Estatísticas do modelo:\n")
cat("    Ordem média:", round(mean(ordens), 2), "\n")
cat("    Ordem máxima:", max(ordens), "\n")
cat("    Postos com ordem > 0:", length(ordens), "\n")


# =============================================================================
# ETAPA 4: GERAÇÃO DE CENÁRIOS
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 4: GERAÇÃO DE CENÁRIOS\n")
cat(paste(rep("=", 79), collapse=""), "\n")

n_cenarios <- dadger$n_cenarios
n_semanas <- 6
mes_inicio <- dadger$mes_inicio

if (modo == "completo") {
  cat("\n[4.1] Gerando cenários sintéticos com PAR(p)...\n")
  
  # Gerar mais cenários que o necessário para depois agregar
  n_cenarios_monte_carlo <- n_cenarios * 10
  
  cenarios_brutos <- gerar_cenarios(
    modelo = modelo_parp,
    historico = historico,
    mes_inicio = mes_inicio,
    n_semanas = n_semanas,
    n_cenarios = n_cenarios_monte_carlo,
    seed = 42
  )
  
  cat("\n[4.2] Agregando cenários...\n")
  resultado_agregacao <- agregar_cenarios(cenarios_brutos, n_cenarios)
  
  cenarios_vazao <- resultado_agregacao$cenarios
  probabilidades <- resultado_agregacao$probabilidades
  
  cat("    Cenários gerados:", dim(cenarios_vazao)[3], "\n")
  cat("    Soma probabilidades:", round(sum(probabilidades), 4), "\n")
  
} else {
  # Modo validação: ler cenários do arquivo oficial
  cat("\n[4.1] Lendo cenários do arquivo oficial (modo validação)...\n")
  
  con_ref <- file("vazoes.rv0", "rb")
  invisible(readBin(con_ref, raw(), n = 10 * 1280))  # Skip até reg 10
  
  # Cada cenário é 1 registro de 320 valores
  cenarios_vazao <- array(0L, dim = c(320, 1, n_cenarios))
  for (cen in 1:n_cenarios) {
    cenarios_vazao[, 1, cen] <- readBin(con_ref, integer(), n = 320, 
                                         size = 4, endian = "little")
  }
  close(con_ref)
  
  # Ler probabilidades do oficial
  con_ref <- file("vazoes.rv0", "rb")
  invisible(readBin(con_ref, raw(), n = 3 * 1280))
  probs_raw <- readBin(con_ref, "double", n = 320, size = 4, endian = "little")
  close(con_ref)
  
  # Probabilidades dos cenários (após as 6 determinísticas)
  probabilidades <- probs_raw[7:(6 + n_cenarios)]
  
  cat("    Cenários lidos:", n_cenarios, "\n")
}

# Converter cenários para incremental (se não vieram do oficial)
if (modo == "completo") {
  cat("\n[4.3] Convertendo cenários para incremental...\n")
  cenarios_incr <- array(0L, dim = dim(cenarios_vazao))
  for (cen in 1:n_cenarios) {
    cenarios_incr[, , cen] <- converter_para_incremental(
      cenarios_vazao[, , cen], topologia
    )
  }
} else {
  # No modo validação, os cenários já são incrementais
  cenarios_incr <- cenarios_vazao
}

# =============================================================================
# ETAPA 5: CÁLCULO DE ENA
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 5: CÁLCULO DE ENA\n")
cat(paste(rep("=", 79), collapse=""), "\n")

if (modo == "completo") {
  cat("\n[5.1] Calculando ENA das previsões...\n")
  ena_prevs <- calcular_ena(vaz_incr_prevs, dadger$codigos)

  cat("[5.2] Calculando ENA dos cenários...\n")
  ena_cenarios <- array(0L, dim = dim(cenarios_incr))
  for (cen in 1:n_cenarios) {
    ena_cenarios[, , cen] <- calcular_ena(cenarios_incr[, , cen], dadger$codigos)
  }
} else {
  cat("\n[5.1] ENA será copiada do arquivo oficial (modo validação)...\n")
}

# =============================================================================
# ETAPA 6: ESCRITA DO VAZOES.RV0
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 6: ESCRITA DO VAZOES.RV0\n")
cat(paste(rep("=", 79), collapse=""), "\n")

out_file <- "vazoes_sander.rv0"
con <- file(out_file, "wb")

# ----- Registro 1: Header -----
cat("\n[6.1] Escrevendo header...\n")
n_usinas <- length(dadger$codigos)
n_estagios <- 7L
aberturas <- c(1L, 1L, 1L, 1L, 1L, 1L, as.integer(n_cenarios))
n_postos <- 320L

header <- c(as.integer(n_usinas), n_estagios, aberturas, n_postos)
header <- c(header, rep(0L, 320 - length(header)))
writeBin(header, con, size = 4, endian = "little")

# ----- Registro 2: Códigos das usinas -----
cat("[6.2] Escrevendo códigos das usinas...\n")
cod_reg <- c(as.integer(dadger$codigos), rep(0L, 320 - n_usinas))
writeBin(cod_reg, con, size = 4, endian = "little")

# ----- Registro 3: Parâmetros -----
cat("[6.3] Escrevendo parâmetros...\n")
con_ref <- file("vazoes.rv0", "rb")
invisible(readBin(con_ref, raw(), n = 2 * 1280))
params <- readBin(con_ref, integer(), n = 320, size = 4, endian = "little")
close(con_ref)
writeBin(params, con, size = 4, endian = "little")

# ----- Registro 4: Probabilidades -----
cat("[6.4] Escrevendo probabilidades...\n")
con_ref <- file("vazoes.rv0", "rb")
invisible(readBin(con_ref, raw(), n = 3 * 1280))
probs_oficial <- readBin(con_ref, raw(), n = 1280)
close(con_ref)
writeBin(probs_oficial, con)

# ----- Registros 5-10: Vazões previstas -----
cat("[6.5] Escrevendo vazões previstas (6 semanas)...\n")
for (sem in 1:6) {
  writeBin(as.integer(vaz_incr_prevs[, sem]), con, size = 4, endian = "little")
}

# ----- Registros 11+: Cenários, ENA, Observados -----
if (modo == "validacao") {
  # Copiar o resto do arquivo oficial
  cat("[6.6] Copiando cenários e ENA do oficial...\n")
  con_ref <- file("vazoes.rv0", "rb")
  invisible(readBin(con_ref, raw(), n = 10 * 1280))  # Skip até reg 10
  
  n_registros_restantes <- (file.info("vazoes.rv0")$size / 1280) - 10
  for (i in 1:n_registros_restantes) {
    reg <- readBin(con_ref, raw(), n = 1280)
    writeBin(reg, con)
  }
  close(con_ref)
} else {
  # Modo completo: escrever cenários gerados
  cat("[6.6] Escrevendo cenários de vazão (", n_cenarios, " cenários)...\n")
  for (cen in 1:n_cenarios) {
    writeBin(as.integer(cenarios_incr[, 1, cen]), con, size = 4, endian = "little")
  }

  cat("[6.7] Escrevendo ENA previstas (6 semanas)...\n")
  for (sem in 1:6) {
    writeBin(as.integer(ena_prevs[, sem]), con, size = 4, endian = "little")
  }

  cat("[6.8] Escrevendo ENA cenários...\n")
  for (cen in 1:n_cenarios) {
    writeBin(as.integer(ena_cenarios[, 1, cen]), con, size = 4, endian = "little")
  }

  cat("[6.9] Escrevendo vazões observadas...\n")
  for (mes in 1:11) {
    writeBin(as.integer(historico[, mes, n_anos]), con, size = 4, endian = "little")
  }
}

close(con)

tamanho_gerado <- file.info(out_file)$size
cat("\n[INFO] Arquivo gerado:", out_file, "\n")
cat("[INFO] Tamanho:", tamanho_gerado, "bytes\n")


# =============================================================================
# ETAPA 7: VALIDAÇÃO
# =============================================================================

cat("\n", paste(rep("=", 79), collapse=""), "\n")
cat(" ETAPA 7: VALIDAÇÃO\n")
cat(paste(rep("=", 79), collapse=""), "\n")

# Comparar com oficial
tamanho_oficial <- file.info("vazoes.rv0")$size
cat("\n[7.1] Comparação de tamanho:\n")
cat("  CEPEL:", tamanho_oficial, "bytes\n")
cat("  SANDER:", tamanho_gerado, "bytes\n")

if (tamanho_oficial != tamanho_gerado) {
  cat("  AVISO: Tamanhos diferentes!\n")
  cat("  Diferença:", tamanho_gerado - tamanho_oficial, "bytes\n")
}

# Comparar vazões previstas
cat("\n[7.2] Comparação de vazões previstas:\n")
con1 <- file("vazoes.rv0", "rb")
con2 <- file(out_file, "rb")
invisible(readBin(con1, raw(), n = 4 * 1280))
invisible(readBin(con2, raw(), n = 4 * 1280))

matches_vaz <- 0
for (sem in 1:6) {
  v1 <- readBin(con1, integer(), n = 320, size = 4, endian = "little")
  v2 <- readBin(con2, integer(), n = 320, size = 4, endian = "little")
  if (all(v1 == v2)) {
    matches_vaz <- matches_vaz + 1
  } else {
    diffs <- sum(v1 != v2)
    cat("  Semana", sem, ": ", diffs, " diferenças\n")
  }
}
close(con1)
close(con2)

cat("  Semanas idênticas:", matches_vaz, "/6\n")

# Comparar arquivo completo (se tamanhos iguais)
if (tamanho_oficial == tamanho_gerado) {
  cat("\n[7.3] Comparação byte a byte:\n")
  con1 <- file("vazoes.rv0", "rb")
  con2 <- file(out_file, "rb")
  d1 <- readBin(con1, raw(), n = tamanho_oficial)
  d2 <- readBin(con2, raw(), n = tamanho_gerado)
  close(con1)
  close(con2)
  
  diffs <- sum(d1 != d2)
  cat("  Bytes diferentes:", diffs, "de", tamanho_oficial, "\n")
  
  if (diffs == 0) {
    cat("\n╔═══════════════════════════════════════════════════════════════════════════════╗\n")
    cat("║               ✓ ARQUIVO 100% IDÊNTICO AO CEPEL!                               ║\n")
    cat("╚═══════════════════════════════════════════════════════════════════════════════╝\n")
  }
}

# Resultado final
cat("\n", paste(rep("=", 79), collapse=""), "\n")
if (matches_vaz == 6) {
  cat(" ✓ VAZÕES PREVISTAS: 100% IDÊNTICAS AO CEPEL\n")
} else {
  cat(" ✗ VAZÕES PREVISTAS: ", matches_vaz, "/6 semanas idênticas\n")
}

if (modo == "completo") {
  cat(" ✓ CENÁRIOS: Gerados com modelo PAR(p) próprio\n")
} else {
  cat(" ✓ CENÁRIOS: Copiados do oficial (modo validação)\n")
}
cat(paste(rep("=", 79), collapse=""), "\n")

cat("\n[CONCLUÍDO] SANDER GEVAZP v3.0\n")
cat("[TEMPO]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
