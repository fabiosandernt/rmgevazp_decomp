# =============================================================================
# SANDER GEVAZP - Funções de Geração de Cenários
# =============================================================================
# Correlação espacial e geração Monte Carlo
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. CORRELAÇÃO ESPACIAL
# -----------------------------------------------------------------------------

#' Calcula matriz de correlação espacial dos resíduos
#' @param historico Array de vazões históricas
#' @param modelo Modelo PAR(p) ajustado
#' @param mes Mês para calcular correlação
#' @return Matriz de correlação [n_postos x n_postos]
calcular_correlacao_espacial <- function(historico, modelo, mes) {
  n_postos <- dim(historico)[1]
  n_anos <- dim(historico)[3]
  
  # Calcular resíduos padronizados para cada posto
  residuos <- matrix(0, nrow = n_postos, ncol = n_anos)
  
  for (p in 1:n_postos) {
    mu <- modelo$media[p, mes]
    sigma <- modelo$desvio[p, mes]
    
    if (sigma > 0) {
      # Resíduo = (Z - previsto) / sigma_a
      for (ano in 1:n_anos) {
        z <- (historico[p, mes, ano] - mu) / sigma
        
        # Subtrair componente AR se ordem > 0
        ord <- modelo$ordem[p, mes]
        if (ord > 0) {
          ar_comp <- 0
          for (k in 1:ord) {
            m_lag <- ((mes - k - 1) %% 12) + 1
            ano_lag <- if (mes - k <= 0) ano - 1 else ano
            
            if (ano_lag >= 1) {
              z_lag <- (historico[p, m_lag, ano_lag] - modelo$media[p, m_lag]) / 
                       modelo$desvio[p, m_lag]
              ar_comp <- ar_comp + modelo$phi[p, mes, k] * z_lag
            }
          }
          z <- z - ar_comp
        }
        
        residuos[p, ano] <- z
      }
    }
  }
  
  # Calcular matriz de correlação
  # Usar apenas postos com variância > 0
  postos_validos <- which(apply(residuos, 1, var, na.rm = TRUE) > 0.01)
  
  if (length(postos_validos) < 2) {
    return(diag(n_postos))
  }
  
  corr <- diag(n_postos)
  
  for (i in postos_validos) {
    for (j in postos_validos) {
      if (i != j) {
        r_i <- residuos[i, ]
        r_j <- residuos[j, ]
        valid <- is.finite(r_i) & is.finite(r_j)
        
        if (sum(valid) > 2) {
          corr[i, j] <- cor(r_i[valid], r_j[valid])
        }
      }
    }
  }
  
  # Garantir matriz simétrica e positiva definida
  corr <- (corr + t(corr)) / 2
  corr[is.na(corr)] <- 0
  diag(corr) <- 1
  
  # Tornar positiva definida se necessário
  eigenvalues <- eigen(corr, symmetric = TRUE, only.values = TRUE)$values
  if (any(eigenvalues <= 0)) {
    corr <- corr + diag(n_postos) * (abs(min(eigenvalues)) + 0.01)
    corr <- cov2cor(corr)
  }
  
  corr
}

# -----------------------------------------------------------------------------
# 2. DECOMPOSIÇÃO DE CHOLESKY
# -----------------------------------------------------------------------------

#' Calcula decomposição de Cholesky da matriz de correlação
#' @param corr Matriz de correlação
#' @return Matriz triangular inferior L tal que corr = L %*% t(L)
cholesky_decomp <- function(corr) {
  n <- nrow(corr)
  
  tryCatch({
    L <- chol(corr)
    t(L)  # Retorna triangular inferior
  }, error = function(e) {
    # Se falhar, usar aproximação diagonal
    diag(sqrt(diag(corr)))
  })
}

# -----------------------------------------------------------------------------
# 3. GERAÇÃO DE CENÁRIOS
# -----------------------------------------------------------------------------

#' Gera cenários sintéticos usando modelo PAR(p)
#' @param modelo Modelo PAR(p) ajustado
#' @param historico Histórico para condição inicial
#' @param mes_inicio Mês de início
#' @param n_semanas Número de semanas a gerar
#' @param n_cenarios Número de cenários
#' @param seed Semente aleatória
#' @return Array [n_postos, n_semanas, n_cenarios]
gerar_cenarios <- function(modelo, historico, mes_inicio, n_semanas, 
                           n_cenarios, seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  n_postos <- nrow(modelo$media)
  n_anos <- dim(historico)[3]
  
  # Matriz de correlação espacial para o mês
  cat("    Calculando correlação espacial...\n")
  corr <- calcular_correlacao_espacial(historico, modelo, mes_inicio)
  L <- cholesky_decomp(corr)
  
  # Array de cenários
  cenarios <- array(0, dim = c(n_postos, n_semanas, n_cenarios))
  
  # Condição inicial: último ano do histórico
  z_prev <- matrix(0, nrow = n_postos, ncol = 6)  # Últimos 6 meses normalizados
  for (p in 1:n_postos) {
    for (lag in 1:6) {
      m <- ((mes_inicio - lag - 1) %% 12) + 1
      if (modelo$desvio[p, m] > 0) {
        z_prev[p, lag] <- (historico[p, m, n_anos] - modelo$media[p, m]) / 
                          modelo$desvio[p, m]
      }
    }
  }
  
  cat("    Gerando", n_cenarios, "cenários...\n")
  
  for (cen in 1:n_cenarios) {
    # Copiar condição inicial
    z_atual <- z_prev
    
    for (sem in 1:n_semanas) {
      # Mês correspondente à semana
      mes <- ((mes_inicio + sem - 2) %% 12) + 1
      
      # Gerar ruído correlacionado espacialmente
      epsilon <- rnorm(n_postos)
      epsilon_corr <- L %*% epsilon
      
      for (p in 1:n_postos) {
        # Componente AR
        ar_comp <- 0
        ord <- modelo$ordem[p, mes]
        
        if (ord > 0) {
          for (k in 1:ord) {
            if (k <= ncol(z_atual)) {
              ar_comp <- ar_comp + modelo$phi[p, mes, k] * z_atual[p, k]
            }
          }
        }
        
        # Gerar valor normalizado
        sigma_a <- modelo$sigma_a[p, mes]
        if (sigma_a <= 0) sigma_a <- 1
        
        z_novo <- ar_comp + epsilon_corr[p] * sigma_a / max(modelo$desvio[p, mes], 1)
        
        # Desnormalizar
        mu <- modelo$media[p, mes]
        sigma <- modelo$desvio[p, mes]
        
        vazao <- mu + z_novo * sigma
        vazao <- max(vazao, 0)  # Vazão não-negativa
        
        cenarios[p, sem, cen] <- round(vazao)
        
        # Atualizar histórico para próxima iteração
        z_atual[p, ] <- c(z_novo, z_atual[p, 1:5])
      }
    }
  }
  
  cenarios
}

# -----------------------------------------------------------------------------
# 4. AGREGAÇÃO DE CENÁRIOS (K-MEANS)
# -----------------------------------------------------------------------------

#' Agrega cenários usando K-means
#' @param cenarios Array [n_postos, n_semanas, n_cenarios]
#' @param n_clusters Número de clusters desejado
#' @return Lista com cenarios_agregados e probabilidades
agregar_cenarios <- function(cenarios, n_clusters) {
  n_postos <- dim(cenarios)[1]
  n_semanas <- dim(cenarios)[2]
  n_cenarios <- dim(cenarios)[3]
  
  cat("    Agregando", n_cenarios, "cenários em", n_clusters, "clusters...\n")
  
  # Transformar em matriz [n_cenarios x features]
  features <- matrix(0, nrow = n_cenarios, ncol = n_postos * n_semanas)
  for (cen in 1:n_cenarios) {
    features[cen, ] <- as.vector(cenarios[, , cen])
  }
  
  # Normalizar features
  features_scaled <- scale(features)
  features_scaled[is.na(features_scaled)] <- 0
  
  # K-means
  set.seed(42)
  km <- kmeans(features_scaled, centers = n_clusters, nstart = 10, iter.max = 100)
  
  # Calcular cenários representativos (centróides)
  cenarios_agregados <- array(0, dim = c(n_postos, n_semanas, n_clusters))
  probabilidades <- rep(0, n_clusters)
  
  for (k in 1:n_clusters) {
    membros <- which(km$cluster == k)
    probabilidades[k] <- length(membros) / n_cenarios
    
    # Média dos membros do cluster
    if (length(membros) == 1) {
      cenarios_agregados[, , k] <- cenarios[, , membros]
    } else {
      for (p in 1:n_postos) {
        for (sem in 1:n_semanas) {
          cenarios_agregados[p, sem, k] <- round(mean(cenarios[p, sem, membros]))
        }
      }
    }
  }
  
  list(
    cenarios = cenarios_agregados,
    probabilidades = probabilidades
  )
}

cat("[OK] Funções de geração de cenários carregadas\n")
