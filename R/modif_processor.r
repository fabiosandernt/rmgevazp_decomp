# =============================================================================
# SANDER GEVAZP - Processamento de MODIF.DAT
# =============================================================================
# Aplica modificações PARTIF e VINCR na topologia de cascata
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. LEITURA DE MODIF.DAT
# -----------------------------------------------------------------------------

#' Lê MODIF.DAT completo
#' @param arquivo Caminho para modif.dat
#' @return Lista com PARTIF e VINCR
ler_modif_completo <- function(arquivo = "modif.dat") {
  if (!file.exists(arquivo)) {
    return(list(partif = list(), vincr = list()))
  }
  
  lines <- readLines(arquivo, warn = FALSE)
  
  partif <- list()
  vincr <- list()
  
  for (line in lines) {
    line <- trimws(line)
    
    # PARTIF NNN PPP JJJ
    # NNN = número da usina
    # PPP = posto associado
    # JJJ = usina a jusante
    if (grepl("^PARTIF", line, ignore.case = TRUE)) {
      nums <- as.integer(regmatches(line, gregexpr("[0-9]+", line))[[1]])
      if (length(nums) >= 3) {
        usina <- nums[1]
        posto <- nums[2]
        jusante <- nums[3]
        partif[[as.character(usina)]] <- list(
          usina = usina,
          posto = posto,
          jusante = jusante
        )
      }
    }
    
    # VINCR NNN PPP TTT
    # NNN = número da usina
    # PPP = posto com vazão incremental
    # TTT = posto com vazão total
    if (grepl("^VINCR", line, ignore.case = TRUE)) {
      nums <- as.integer(regmatches(line, gregexpr("[0-9]+", line))[[1]])
      if (length(nums) >= 3) {
        usina <- nums[1]
        posto_incr <- nums[2]
        posto_total <- nums[3]
        vincr[[as.character(usina)]] <- list(
          usina = usina,
          posto_incr = posto_incr,
          posto_total = posto_total
        )
      }
    }
    
    # Parar no 9999
    if (grepl("^9999", line)) break
  }
  
  list(partif = partif, vincr = vincr)
}

# -----------------------------------------------------------------------------
# 2. APLICAÇÃO DE MODIFICAÇÕES NA TOPOLOGIA
# -----------------------------------------------------------------------------

#' Aplica MODIF.DAT na topologia de cascata
#' @param topologia Lista de topologia original
#' @param modif Lista de modificações do ler_modif_completo()
#' @param hidr Dados de hidr.dat (para mapear usina->posto)
#' @return Topologia modificada
aplicar_modif_topologia <- function(topologia, modif, hidr = NULL) {
  topo_mod <- topologia
  
  # Aplicar PARTIF
  for (nome in names(modif$partif)) {
    p <- modif$partif[[nome]]
    posto <- p$posto
    jusante <- p$jusante
    
    if (posto > 0 && posto <= 320) {
      posto_str <- as.character(posto)
      
      # Se o posto não existe na topologia, criar
      if (is.null(topo_mod[[posto_str]])) {
        topo_mod[[posto_str]] <- list(jusante = jusante, montantes = integer(0))
      } else {
        # Atualizar jusante
        topo_mod[[posto_str]]$jusante <- jusante
      }
      
      # Se tem jusante válido, adicionar este posto como montante do jusante
      if (jusante > 0 && jusante <= 320) {
        jus_str <- as.character(jusante)
        if (!is.null(topo_mod[[jus_str]])) {
          if (!(posto %in% topo_mod[[jus_str]]$montantes)) {
            topo_mod[[jus_str]]$montantes <- c(topo_mod[[jus_str]]$montantes, posto)
          }
        }
      }
    }
  }
  
  # Aplicar VINCR
  for (nome in names(modif$vincr)) {
    v <- modif$vincr[[nome]]
    posto_incr <- v$posto_incr
    posto_total <- v$posto_total
    
    # VINCR indica que o posto tem vazão lateral
    # A vazão incremental é calculada diferente
    # Por enquanto, armazenar a informação
    if (posto_incr > 0 && posto_incr <= 320) {
      posto_str <- as.character(posto_incr)
      if (!is.null(topo_mod[[posto_str]])) {
        topo_mod[[posto_str]]$vincr_total <- posto_total
      }
    }
  }
  
  topo_mod
}

# -----------------------------------------------------------------------------
# 3. CONVERSÃO INCREMENTAL COM MODIF
# -----------------------------------------------------------------------------

#' Converte vazões totais para incrementais considerando MODIF
#' @param vaz_total Matriz [320 x n_semanas] de vazões totais
#' @param topologia Lista com relações montante/jusante (já modificada)
#' @param modif Lista de modificações do MODIF.DAT
#' @return Matriz de vazões incrementais
converter_para_incremental_com_modif <- function(vaz_total, topologia, modif = NULL) {
  n_postos <- nrow(vaz_total)
  n_semanas <- ncol(vaz_total)
  
  vaz_incr <- matrix(0L, nrow = n_postos, ncol = n_semanas)
  
  for (posto in 1:n_postos) {
    posto_str <- as.character(posto)
    
    # Verificar se é VINCR
    if (!is.null(modif) && !is.null(modif$vincr[[posto_str]])) {
      # Para VINCR, a vazão incremental vem do posto_incr
      # e a total do posto_total
      v <- modif$vincr[[posto_str]]
      for (sem in 1:n_semanas) {
        # Vazão incremental é a diferença entre total e montantes
        vaz_incr[posto, sem] <- vaz_total[posto, sem]
      }
    } else if (!is.null(topologia[[posto_str]])) {
      # Posto normal com topologia
      t <- topologia[[posto_str]]
      
      for (sem in 1:n_semanas) {
        total <- vaz_total[posto, sem]
        
        # Subtrair montantes
        soma_montantes <- 0L
        if (length(t$montantes) > 0) {
          for (mont in t$montantes) {
            if (mont >= 1 && mont <= n_postos) {
              soma_montantes <- soma_montantes + vaz_total[mont, sem]
            }
          }
        }
        
        vaz_incr[posto, sem] <- as.integer(total - soma_montantes)
      }
    } else {
      # Posto sem topologia - vazão incremental = total
      vaz_incr[posto, ] <- vaz_total[posto, ]
    }
  }
  
  vaz_incr
}

cat("[OK] Processamento de MODIF.DAT carregado\n")
