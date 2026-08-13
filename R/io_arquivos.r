# =============================================================================
# SANDER GEVAZP - Módulo de Leitura de Arquivos
# =============================================================================
# Leitura de todos os arquivos de entrada do GEVAZP
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. CASO.DAT - Aponta para arquivos.dat
# -----------------------------------------------------------------------------

#' Lê CASO.DAT
#' @param arquivo Caminho para caso.dat
#' @return Nome do arquivo de configuração (arquivos.dat)
ler_caso <- function(arquivo = "caso.dat") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  trimws(readLines(arquivo, n = 1))
}

# -----------------------------------------------------------------------------
# 2. ARQUIVOS.DAT - Lista de arquivos do deck
# -----------------------------------------------------------------------------

#' Lê ARQUIVOS.DAT
#' @param arquivo Caminho para arquivos.dat
#' @return Lista com caminhos dos arquivos
ler_arquivos <- function(arquivo = "arquivos.dat") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  lines <- readLines(arquivo)
  arquivos <- list()
  
  for (line in lines) {
    if (grepl(":", line)) {
      parts <- strsplit(line, ":")[[1]]
      chave <- trimws(parts[1])
      valor <- trimws(parts[2])
      
      # Mapear chaves para nomes padronizados
      if (grepl("DADOS GERAIS", chave)) arquivos$gevazp_dat <- valor
      else if (grepl("CONFIGURACAO HIDRAULICA", chave)) arquivos$confhd <- valor
      else if (grepl("BACIAS", chave)) arquivos$bacias <- valor
      else if (grepl("TENDENCIA", chave)) arquivos$vazpast <- valor
      else if (grepl("HISTORICO", chave)) arquivos$vazoes <- valor
      else if (grepl("CADASTRO.*POSTOS", chave)) arquivos$postos <- valor
      else if (grepl("RELATORIO", chave)) arquivos$relatorio <- valor
      else if (grepl("VAZAO TOTAL", chave)) arquivos$vaztotgd <- valor
      else if (grepl("VAZAO INCR", chave)) arquivos$gevazp_out <- valor
      else if (grepl("DECOMP", chave)) arquivos$rv0 <- valor
      else if (grepl("REGRAS", chave)) arquivos$regras <- valor
      else if (grepl("SIMILARIDADE", chave)) arquivos$simsev <- valor
      else if (grepl("EOLICA", chave)) arquivos$indices_csv <- valor
    }
  }
  
  arquivos
}

# -----------------------------------------------------------------------------
# 3. GEVAZP.DAT - Configuração principal
# -----------------------------------------------------------------------------

#' Lê GEVAZP.DAT
#' @param arquivo Caminho para gevazp.dat
#' @return Lista com configurações
ler_gevazp_dat <- function(arquivo = "gevazp.dat") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  lines <- readLines(arquivo)
  config <- list()
  
  for (line in lines) {
    if (grepl(":", line)) {
      parts <- strsplit(line, ":")[[1]]
      chave <- trimws(parts[1])
      valor <- trimws(gsub("[^0-9.-]", "", parts[2]))
      
      if (grepl("TIPO DE EXECUCAO", chave)) config$tipo_execucao <- as.integer(valor)
      else if (grepl("TIPO AMOSTRAGEM", chave)) config$tipo_amostragem <- as.integer(valor)
      else if (grepl("APLICACAO AMOST", chave)) config$aplicacao_amost <- as.integer(valor)
      else if (grepl("CENARIOS DE VAZAO", chave)) config$cenarios_vazao <- as.integer(valor)
      else if (grepl("ANO INICIO DO ESTUDO", chave)) config$ano_inicio <- as.integer(valor)
      else if (grepl("No\\. DE ANOS", chave)) config$n_anos_estudo <- as.integer(valor)
      else if (grepl("MES INICIO", chave)) config$mes_inicio <- as.integer(valor)
      else if (grepl("MES FINAL", chave)) config$mes_final <- as.integer(valor)
      else if (grepl("SERIES SINT", chave)) config$n_series <- as.integer(valor)
      else if (grepl("ORDEM MAXIMA", chave)) config$ordem_maxima <- as.integer(valor)
      else if (grepl("ANO INICIAL HIST", chave)) config$ano_inicial_hist <- as.integer(valor)
      else if (grepl("ARQUIVO DE POSTOS", chave)) config$arquivo_postos <- as.integer(valor)
      else if (grepl("TENDENCIA", chave) && !grepl(":", parts[2])) config$tendencia <- as.integer(valor)
      else if (grepl("IMPRIME RELATORIO", chave)) config$imprime_relatorio <- as.integer(valor)
      else if (grepl("IMPRIME TESTES", chave)) config$imprime_testes <- as.integer(valor)
      else if (grepl("IMPRIME CENARIOS", chave)) config$imprime_cenarios <- as.integer(valor)
    }
  }
  
  config
}

# -----------------------------------------------------------------------------
# 4. POSTOS.DAT - Cadastro de postos (binário)
# -----------------------------------------------------------------------------

#' Lê POSTOS.DAT
#' @param arquivo Caminho para postos.dat
#' @return Data frame com informações dos postos
ler_postos <- function(arquivo = "postos.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  # Formato: 20 bytes por posto (nome 12 bytes + ano_ini 4 bytes + ano_fim 4 bytes)
  file_size <- file.info(arquivo)$size
  bytes_per_posto <- 20
  n_postos <- file_size / bytes_per_posto
  
  con <- file(arquivo, "rb")
  postos <- data.frame(
    codigo = integer(n_postos),
    nome = character(n_postos),
    ano_inicio = integer(n_postos),
    ano_fim = integer(n_postos),
    stringsAsFactors = FALSE
  )
  
  for (i in 1:n_postos) {
    nome_raw <- readBin(con, raw(), n = 12)
    # Converter para string removendo bytes nulos
    nome <- tryCatch({
      rawToChar(nome_raw[nome_raw != 0 & nome_raw < 128])
    }, error = function(e) "")
    
    ano_ini <- readBin(con, integer(), n = 1, size = 4, endian = "little")
    ano_fim <- readBin(con, integer(), n = 1, size = 4, endian = "little")
    
    postos$codigo[i] <- i
    postos$nome[i] <- trimws(nome)
    postos$ano_inicio[i] <- ano_ini
    postos$ano_fim[i] <- ano_fim
  }
  close(con)
  
  # Filtrar postos válidos (com nome)
  postos <- postos[nchar(postos$nome) > 0, ]
  postos
}

# -----------------------------------------------------------------------------
# 5. HIDR.DAT - Dados das hidrelétricas (binário)
# -----------------------------------------------------------------------------

#' Lê HIDR.DAT
#' @param arquivo Caminho para hidr.dat
#' @return Data frame com informações das usinas
ler_hidr <- function(arquivo = "hidr.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  # Formato NEWAVE: 1920 bytes por usina? Ou DECOMP usa formato diferente
  file_size <- file.info(arquivo)$size
  
  # Tentar detectar formato
  con <- file(arquivo, "rb")
  
  # Ler primeira usina para detectar estrutura
  nome_raw <- readBin(con, raw(), n = 12)
  nome <- rawToChar(nome_raw[nome_raw != 0])
  
  # Próximos campos
  campos <- readBin(con, integer(), n = 10, size = 4, endian = "little")
  
  close(con)
  
  # Retornar estrutura básica
  list(
    primeira_usina = trimws(nome),
    file_size = file_size
  )
}

# -----------------------------------------------------------------------------
# 6. VAZOES.DAT - Histórico de vazões (binário)
# -----------------------------------------------------------------------------

#' Lê VAZOES.DAT
#' @param arquivo Caminho para vazoes.dat
#' @param n_postos Número de postos (320 ou 600)
#' @return Array [n_postos, 12, n_anos]
ler_vazoes <- function(arquivo = "vazoes.dat", n_postos = 320) {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  file_size <- file.info(arquivo)$size
  bytes_per_year <- n_postos * 12 * 4
  n_anos <- file_size / bytes_per_year
  
  con <- file(arquivo, "rb")
  historico <- array(0L, dim = c(n_postos, 12, n_anos))
  
  for (ano in 1:n_anos) {
    for (mes in 1:12) {
      historico[, mes, ano] <- readBin(con, integer(), n = n_postos, 
                                        size = 4, endian = "little")
    }
  }
  close(con)
  
  historico
}

# -----------------------------------------------------------------------------
# 7. PREVS.RV0 - Previsões de vazão
# -----------------------------------------------------------------------------

#' Lê PREVS.RV0
#' @param arquivo Caminho para prevs.rv0
#' @return Matriz [320, 6] de vazões totais previstas
ler_prevs <- function(arquivo = "prevs.rv0") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  prevs <- read.table(arquivo, header = FALSE)
  colnames(prevs) <- c("serie", "posto", "s1", "s2", "s3", "s4", "s5", "s6")
  
  vaz_total <- matrix(0L, nrow = 320, ncol = 6)
  for (i in 1:nrow(prevs)) {
    p <- prevs$posto[i]
    if (p >= 1 && p <= 320) {
      vaz_total[p, ] <- as.integer(prevs[i, 3:8])
    }
  }
  
  vaz_total
}

# -----------------------------------------------------------------------------
# 8. DADGER.RV0 - Configuração DECOMP
# -----------------------------------------------------------------------------

#' Lê DADGER.RV0
#' @param arquivo Caminho para dadger.rv0
#' @return Lista com codigos, n_cenarios, mes_inicio, ano_inicio
ler_dadger <- function(arquivo = "dadger.rv0") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  lines <- readLines(arquivo, warn = FALSE)
  
  # Extrair códigos das usinas (registros UH)
  codigos <- c()
  for (linha in lines) {
    if (startsWith(linha, "UH")) {
      cod <- as.integer(trimws(substr(linha, 4, 7)))
      if (!is.na(cod) && cod > 0) {
        codigos <- c(codigos, cod)
      }
    }
  }
  
  # Extrair número de cenários
  n_cenarios <- 136
  for (linha in lines) {
    if (grepl("ESTRUTURA DA ARVORE", linha)) {
      nums <- as.integer(regmatches(linha, gregexpr("[0-9]+", linha))[[1]])
      if (length(nums) > 0) {
        n_cenarios <- nums[length(nums)]
      }
      break
    }
  }
  
  # Extrair mês/ano de início (registro DP)
  mes_inicio <- 12
  ano_inicio <- 2018
  for (linha in lines) {
    if (grepl("^DP", linha)) {
      nums <- as.integer(regmatches(linha, gregexpr("[0-9]+", linha))[[1]])
      if (length(nums) >= 2) {
        mes_inicio <- nums[1]
        ano_inicio <- nums[2]
      }
      break
    }
  }
  
  list(
    codigos = codigos,
    n_cenarios = n_cenarios,
    mes_inicio = mes_inicio,
    ano_inicio = ano_inicio
  )
}

# -----------------------------------------------------------------------------
# 9. REGRAS.DAT - Regras de postos artificiais
# -----------------------------------------------------------------------------

#' Lê REGRAS.DAT
#' @param arquivo Caminho para regras.dat
#' @return Data frame com regras
ler_regras <- function(arquivo = "regras.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  lines <- readLines(arquivo)
  regras <- list()
  
  for (line in lines) {
    if (grepl("^\\s*[0-9]+\\s+[0-9]+", line)) {
      parts <- strsplit(trimws(line), "\\s+")[[1]]
      if (length(parts) >= 3) {
        posto <- as.integer(parts[1])
        mes <- as.integer(parts[2])
        formula <- paste(parts[3:length(parts)], collapse = " ")
        
        if (!is.na(posto) && posto > 0) {
          regras[[length(regras) + 1]] <- list(
            posto = posto,
            mes = mes,
            formula = formula
          )
        }
      }
    }
  }
  
  regras
}

# -----------------------------------------------------------------------------
# 10. MODIF.DAT - Modificações
# -----------------------------------------------------------------------------

#' Lê MODIF.DAT
#' @param arquivo Caminho para modif.dat
#' @return Lista com modificações
ler_modif <- function(arquivo = "modif.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  lines <- readLines(arquivo)
  modifs <- list(partif = list(), vincr = list())
  
  for (line in lines) {
    line <- trimws(line)
    if (startsWith(line, "PARTIF")) {
      nums <- as.integer(regmatches(line, gregexpr("[0-9]+", line))[[1]])
      if (length(nums) >= 3) {
        modifs$partif[[length(modifs$partif) + 1]] <- nums
      }
    } else if (startsWith(line, "VINCR")) {
      nums <- as.integer(regmatches(line, gregexpr("[0-9]+", line))[[1]])
      if (length(nums) >= 3) {
        modifs$vincr[[length(modifs$vincr) + 1]] <- nums
      }
    }
  }
  
  modifs
}

# -----------------------------------------------------------------------------
# 11. LOSS.DAT - Fatores de perda
# -----------------------------------------------------------------------------

#' Lê LOSS.DAT
#' @param arquivo Caminho para loss.dat
#' @return Lista com fatores de perda
ler_loss <- function(arquivo = "loss.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  # Formato simplificado - retornar que foi lido
  list(arquivo = arquivo, lido = TRUE)
}

# -----------------------------------------------------------------------------
# 12. RV0/RV1/etc - Lista de arquivos DECOMP (detecta revisão automaticamente)
# -----------------------------------------------------------------------------

#' Detecta qual revisão está disponível (rv0, rv1, rv2, etc)
#' @param dir_dados Diretório com os arquivos
#' @return Lista com revisão detectada e nomes dos arquivos
detectar_revisao <- function(dir_dados = ".") {
  # Procurar por arquivos de revisão (case insensitive)
  arquivos <- list.files(dir_dados, pattern = "^rv[0-9]$", ignore.case = TRUE)
  
  if (length(arquivos) == 0) {
    return(list(revisao = NULL, rv_file = NULL, dadger = NULL, prevs = NULL))
  }
  
  # Pegar o primeiro encontrado (geralmente só tem um)
  rv_file <- arquivos[1]
  revisao <- gsub("rv", "", tolower(rv_file))
  
  # Construir nomes dos arquivos com a revisão detectada
  list(
    revisao = revisao,
    rv_file = rv_file,
    dadger = paste0("dadger.rv", revisao),
    prevs = paste0("prevs.rv", revisao),
    vazoes = paste0("vazoes.rv", revisao)
  )
}

#' Lê arquivo RV (lista de arquivos DECOMP)
#' @param arquivo Caminho para rv0/rv1/etc
#' @return Lista com caminhos dos arquivos
ler_rv <- function(arquivo) {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  lines <- readLines(arquivo)
  arquivos <- list()
  
  for (line in lines) {
    line <- trimws(line)
    if (nchar(line) > 0 && !startsWith(line, "&")) {
      arquivos[[length(arquivos) + 1]] <- line
    }
  }
  
  arquivos
}

# Manter compatibilidade com nome antigo
ler_rv0 <- ler_rv

# -----------------------------------------------------------------------------
# FUNÇÃO PRINCIPAL - Lê todos os arquivos
# -----------------------------------------------------------------------------

#' Lê todos os arquivos de entrada do GEVAZP
#' @param dir_dados Diretório com os arquivos
#' @return Lista com todos os dados lidos
ler_todos_arquivos <- function(dir_dados) {
  oldwd <- setwd(dir_dados)
  on.exit(setwd(oldwd))
  
  dados <- list()
  
  cat("[IO] Lendo arquivos de entrada...\n")
  
  # Detectar revisão (rv0, rv1, rv2, etc)
  rev_info <- detectar_revisao(".")
  if (!is.null(rev_info$revisao)) {
    dados$revisao <- rev_info$revisao
    cat("  [INFO] Revisão detectada: RV", toupper(rev_info$revisao), "\n", sep = "")
  }
  
  # Função auxiliar para encontrar arquivo (case insensitive)
  find_file <- function(nome) {
    arquivos <- list.files(".", pattern = paste0("^", nome, "$"), ignore.case = TRUE)
    if (length(arquivos) > 0) arquivos[1] else NULL
  }
  
  # CASO.DAT
  caso_file <- find_file("caso.dat")
  if (!is.null(caso_file)) {
    dados$caso <- ler_caso(caso_file)
    cat("  ✓ caso.dat\n")
  }
  
  # ARQUIVOS.DAT
  arq_file <- find_file("arquivos.dat")
  if (!is.null(arq_file)) {
    dados$arquivos <- ler_arquivos(arq_file)
    cat("  ✓ arquivos.dat\n")
  }
  
  # GEVAZP.DAT
  gevazp_file <- find_file("gevazp.dat")
  if (!is.null(gevazp_file)) {
    dados$gevazp_config <- ler_gevazp_dat(gevazp_file)
    cat("  ✓ gevazp.dat\n")
  }
  
  # POSTOS.DAT
  postos_file <- find_file("postos.dat")
  if (!is.null(postos_file)) {
    dados$postos <- ler_postos(postos_file)
    cat("  ✓ postos.dat (", nrow(dados$postos), " postos)\n", sep = "")
  }
  
  # HIDR.DAT
  hidr_file <- find_file("hidr.dat")
  if (!is.null(hidr_file)) {
    dados$hidr <- ler_hidr(hidr_file)
    cat("  ✓ hidr.dat\n")
  }
  
  # VAZOES.DAT
  vazoes_file <- find_file("vazoes.dat")
  if (!is.null(vazoes_file)) {
    n_postos <- if (!is.null(dados$gevazp_config$arquivo_postos) && 
                    dados$gevazp_config$arquivo_postos == 1) 600 else 320
    dados$historico <- ler_vazoes(vazoes_file, n_postos)
    cat("  ✓ vazoes.dat (", dim(dados$historico)[3], " anos)\n", sep = "")
  }
  
  # PREVS.RVx (usar revisão detectada)
  prevs_name <- if (!is.null(rev_info$prevs)) rev_info$prevs else "prevs.rv0"
  prevs_file <- find_file(prevs_name)
  if (!is.null(prevs_file)) {
    dados$prevs <- ler_prevs(prevs_file)
    cat("  ✓ ", prevs_file, "\n", sep = "")
  }
  
  # DADGER.RVx (usar revisão detectada)
  dadger_name <- if (!is.null(rev_info$dadger)) rev_info$dadger else "dadger.rv0"
  dadger_file <- find_file(dadger_name)
  if (!is.null(dadger_file)) {
    dados$dadger <- ler_dadger(dadger_file)
    cat("  ✓ ", dadger_file, " (", length(dados$dadger$codigos), " usinas)\n", sep = "")
  }
  
  # REGRAS.DAT
  regras_file <- find_file("regras.dat")
  if (!is.null(regras_file)) {
    dados$regras <- ler_regras(regras_file)
    cat("  ✓ regras.dat\n")
  }
  
  # MODIF.DAT
  modif_file <- find_file("modif.dat")
  if (!is.null(modif_file)) {
    dados$modif <- ler_modif(modif_file)
    cat("  ✓ modif.dat\n")
  }
  
  # LOSS.DAT
  loss_file <- find_file("loss.dat")
  if (!is.null(loss_file)) {
    dados$loss <- ler_loss(loss_file)
    cat("  ✓ loss.dat\n")
  }
  
  # RVx (lista de arquivos DECOMP)
  if (!is.null(rev_info$rv_file)) {
    dados$rv_lista <- ler_rv(rev_info$rv_file)
    cat("  ✓ ", rev_info$rv_file, "\n", sep = "")
  }
  
  # GEVAZP.LIC (licença - apenas verificar existência)
  lic_file <- find_file("gevazp.lic")
  if (!is.null(lic_file)) {
    dados$licenca <- TRUE
    cat("  ✓ gevazp.lic\n")
  }
  
  # Guardar info da revisão para uso posterior
  dados$rev_info <- rev_info
  
  cat("[IO] Leitura concluída\n")
  
  dados
}

cat("[OK] Módulo de leitura de arquivos carregado\n")
