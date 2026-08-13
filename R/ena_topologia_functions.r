# =============================================================================
# SANDER GEVAZP - Funções de ENA e Topologia
# =============================================================================
# Cálculo de Energia Natural Afluente e extração de topologia
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. EXTRAÇÃO DE TOPOLOGIA DO RELATÓRIO
# -----------------------------------------------------------------------------

#' Extrai topologia de cascata do relatório GEVAZP
#' @param arquivo Caminho para o arquivo gevazp.rel
#' @return Lista com topologia por posto
extrair_topologia <- function(arquivo = "gevazp.rel") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  lines <- readLines(arquivo, encoding = "latin1")
  
  # Encontrar início da seção
  start <- grep("POSTOS A MONTANTE", lines)[1]
  if (is.na(start)) {
    stop("Seção 'POSTOS A MONTANTE' não encontrada no relatório")
  }
  
  topologia <- list()
  
  for (i in (start + 2):min(start + 200, length(lines))) {
    line <- lines[i]
    
    # Parar se linha vazia ou fim da tabela
    if (nchar(trimws(line)) < 10) break
    if (grepl("X----", line)) break
    if (grepl("\\.00", line)) break  # Outra tabela (MLT)
    
    # A linha tem formato: NINT NUM NOME POST JUS [MONTANTES]
    # Precisamos extrair os primeiros dois números (NINT, NUM) e depois
    # os números após o nome (POST, JUS, MONTANTES)
    
    # Verificar se começa com padrão de NINT NUM
    if (!grepl("^\\s*\\d+\\s+\\d+\\s+", line)) next
    
    # Extrair todos os números da linha
    all_nums <- as.integer(regmatches(line, gregexpr("\\d+", line))[[1]])
    
    if (length(all_nums) < 4) next  # Precisa de pelo menos NINT, NUM, POST, JUS
    
    nint <- all_nums[1]
    num <- all_nums[2]
    
    # Os números após o nome são a partir da posição onde POST começa
    # POST é geralmente o 3o número, mas nomes como "CAPIM BRANC1" têm números
    # Solução: POST e JUS são os números que aparecem na parte fixa da tabela
    # POST está aproximadamente na coluna 26-30, JUS na 31-35
    
    # Extrair substring após posição 25 e pegar seus números
    if (nchar(line) >= 26) {
      resto <- substr(line, 26, nchar(line))
      resto_nums <- as.integer(regmatches(resto, gregexpr("\\d+", resto))[[1]])
      
      if (length(resto_nums) >= 2) {
        posto <- resto_nums[1]
        jusante <- resto_nums[2]
        montantes <- if (length(resto_nums) > 2) resto_nums[3:length(resto_nums)] else integer(0)
        montantes <- montantes[montantes <= 320 & montantes > 0]
        
        if (posto >= 1 && posto <= 320) {
          topologia[[as.character(posto)]] <- list(
            jusante = jusante,
            montantes = montantes
          )
        }
      }
    }
  }
  
  topologia
}

# -----------------------------------------------------------------------------
# 2. CONVERSÃO TOTAL → INCREMENTAL
# -----------------------------------------------------------------------------

#' Converte vazões totais para incrementais usando topologia
#' @param vaz_total Matriz [320 x n_semanas] de vazões totais
#' @param topologia Lista com relações montante/jusante
#' @return Matriz de vazões incrementais
converter_para_incremental <- function(vaz_total, topologia) {
  n_postos <- nrow(vaz_total)
  n_semanas <- ncol(vaz_total)
  
  vaz_incr <- matrix(0L, nrow = n_postos, ncol = n_semanas)
  
  for (posto_str in names(topologia)) {
    posto <- as.integer(posto_str)
    t <- topologia[[posto_str]]
    
    for (sem in 1:n_semanas) {
      mont_validos <- t$montantes[t$montantes >= 1 & t$montantes <= 320]
      soma_mont <- if (length(mont_validos) > 0) {
        sum(vaz_total[mont_validos, sem])
      } else {
        0L
      }
      vaz_incr[posto, sem] <- as.integer(vaz_total[posto, sem] - soma_mont)
    }
  }
  
  vaz_incr
}

# -----------------------------------------------------------------------------
# 3. LEITURA DO HIDR.DAT PARA PRODUTIBILIDADE
# -----------------------------------------------------------------------------

#' Lê produtibilidade das usinas do HIDR.DAT
#' @param arquivo Caminho para hidr.dat
#' @return Data frame com código e produtibilidade
ler_produtibilidade <- function(arquivo = "hidr.dat") {
  if (!file.exists(arquivo)) {
    return(NULL)
  }
  
  # HIDR.DAT: formato binário, ~1920 bytes por usina
  # Estrutura aproximada (consultar manual NEWAVE para detalhes)
  file_size <- file.info(arquivo)$size
  bytes_per_usina <- 1920
  n_usinas <- file_size / bytes_per_usina
  
  # Para simplificar, retornar produtibilidade padrão
  # Em implementação completa, ler do arquivo
  
  NULL
}

# -----------------------------------------------------------------------------
# 4. CÁLCULO DE ENA
# -----------------------------------------------------------------------------

#' Calcula Energia Natural Afluente
#' @param vazoes Matriz de vazões incrementais [320 x n_semanas]
#' @param codigos Vetor de códigos das usinas
#' @param produtibilidade Data frame com produtibilidade (opcional)
#' @return Matriz de ENA [320 x n_semanas]
calcular_ena <- function(vazoes, codigos, produtibilidade = NULL) {
  n_postos <- nrow(vazoes)
  n_semanas <- ncol(vazoes)
  
  # Se não houver produtibilidade, usar fator padrão
  # ENA = vazão * produtibilidade * fator_conversão
  # Para usinas sem dados, ENA = vazão (fator 1)
  
  ena <- vazoes  # Por padrão, ENA = vazão
  
  # Se tiver produtibilidade, aplicar
  if (!is.null(produtibilidade)) {
    for (i in seq_along(codigos)) {
      cod <- codigos[i]
      idx <- which(produtibilidade$codigo == cod)
      if (length(idx) > 0) {
        fator <- produtibilidade$prod[idx]
        ena[cod, ] <- round(vazoes[cod, ] * fator)
      }
    }
  }
  
  ena
}

# -----------------------------------------------------------------------------
# 5. LEITURA DO VAZOES.DAT (HISTÓRICO)
# -----------------------------------------------------------------------------

#' Lê arquivo de vazões históricas
#' @param arquivo Caminho para vazoes.dat
#' @return Array [320, 12, n_anos]
ler_vazoes_historico <- function(arquivo = "vazoes.dat") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  file_size <- file.info(arquivo)$size
  n_postos <- 320
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
# 6. LEITURA DO PREVS.RV0
# -----------------------------------------------------------------------------

#' Lê previsões semanais de vazão
#' @param arquivo Caminho para prevs.rv0
#' @return Matriz [320, 6] de vazões totais previstas
ler_prevs <- function(arquivo = "prevs.rv0") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  prevs <- read.table(arquivo, header = FALSE)
  colnames(prevs) <- c("serie", "posto", "s1", "s2", "s3", "s4", "s5", "s6")
  
  # Criar matriz 320 x 6
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
# 7. LEITURA DO DADGER.RV0
# -----------------------------------------------------------------------------

#' Lê configuração do DADGER
#' @param arquivo Caminho para dadger.rv0
#' @return Lista com codigos e n_cenarios
ler_dadger <- function(arquivo = "dadger.rv0") {
  if (!file.exists(arquivo)) {
    stop("Arquivo ", arquivo, " não encontrado")
  }
  
  lines <- readLines(arquivo, warn = FALSE)
  
  # Extrair códigos das usinas
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
  n_cenarios <- 136  # Default
  for (linha in lines) {
    if (grepl("ESTRUTURA DA ARVORE", linha)) {
      nums <- as.integer(regmatches(linha, gregexpr("[0-9]+", linha))[[1]])
      if (length(nums) > 0) {
        n_cenarios <- nums[length(nums)]
      }
      break
    }
  }
  
  # Extrair mês/ano de início
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

cat("[OK] Funções de ENA e topologia carregadas\n")
