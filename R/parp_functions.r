# =============================================================================
# SANDER GEVAZP - Funções PAR(p)
# =============================================================================
# Funções para modelo Periodic AutoRegressive
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. ESTATÍSTICAS MENSAIS
# -----------------------------------------------------------------------------

#' Calcula estatísticas mensais para cada posto
#' @param historico Array [n_postos, 12, n_anos] de vazões históricas
#' @return Lista com media, desvio, cv (coef. variação)
calcular_estatisticas_mensais <- function(historico) {
  n_postos <- dim(historico)[1]
  n_meses <- 12
  n_anos <- dim(historico)[3]
  
  media <- matrix(0, nrow = n_postos, ncol = n_meses)
  desvio <- matrix(0, nrow = n_postos, ncol = n_meses)
  
  for (p in 1:n_postos) {
    for (m in 1:n_meses) {
      serie <- historico[p, m, ]
      serie_valida <- serie[serie > 0]
      
      if (length(serie_valida) > 1) {
        media[p, m] <- mean(serie_valida)
        desvio[p, m] <- sd(serie_valida)
      }
    }
  }
  
  # Coeficiente de variação
  cv <- desvio / (media + 1e-10)
  
  list(media = media, desvio = desvio, cv = cv)
}

# -----------------------------------------------------------------------------
# 2. AUTOCORRELAÇÃO
# -----------------------------------------------------------------------------

#' Calcula autocorrelações mensais lag 1 a p_max
#' @param historico Array de vazões históricas
#' @param p_max Ordem máxima do modelo
#' @return Array [n_postos, 12, p_max] de autocorrelações
calcular_autocorrelacoes <- function(historico, p_max = 6) {
  n_postos <- dim(historico)[1]
  n_meses <- 12
  n_anos <- dim(historico)[3]
  
  # Normalizar séries (Z-score mensal)
  hist_norm <- array(0, dim = dim(historico))
  for (p in 1:n_postos) {
    for (m in 1:n_meses) {
      serie <- historico[p, m, ]
      serie_pos <- serie[serie > 0]
      if (length(serie_pos) > 1) {
        mu <- mean(serie_pos)
        sigma <- sd(serie_pos)
        if (!is.na(sigma) && sigma > 0) {
          hist_norm[p, m, ] <- (serie - mu) / sigma
        }
      }
    }
  }
  
  # Calcular autocorrelações
  rho <- array(0, dim = c(n_postos, n_meses, p_max))
  
  for (p in 1:n_postos) {
    for (m in 1:n_meses) {
      for (lag in 1:p_max) {
        # Mês anterior considerando periodicidade
        m_lag <- ((m - lag - 1) %% 12) + 1
        
        # Correlação entre mês m e mês m-lag
        z_atual <- hist_norm[p, m, ]
        
        # Ajustar índice do ano para lags que cruzam janeiro
        if (m - lag <= 0) {
          z_lag <- c(NA, hist_norm[p, m_lag, 1:(n_anos-1)])
        } else {
          z_lag <- hist_norm[p, m_lag, ]
        }
        
        # Remover NAs e valores não-finitos
        valid <- !is.na(z_atual) & !is.na(z_lag) & 
                 is.finite(z_atual) & is.finite(z_lag)
        
        if (sum(valid) > 2) {
          corr <- cor(z_atual[valid], z_lag[valid])
          if (!is.na(corr)) {
            rho[p, m, lag] <- corr
          }
        }
      }
    }
  }
  
  rho[is.na(rho)] <- 0
  rho
}

# -----------------------------------------------------------------------------
# 3. YULE-WALKER
# -----------------------------------------------------------------------------

#' Resolve equações de Yule-Walker para obter coeficientes phi
#' @param rho Vetor de autocorrelações [rho_1, rho_2, ..., rho_p]
#' @param p Ordem do modelo
#' @return Vetor de coeficientes phi
yule_walker <- function(rho, p) {
  if (p == 0 || length(rho) < p) {
    return(numeric(0))
  }
  
  # Montar matriz de Toeplitz
  R <- matrix(0, nrow = p, ncol = p)
  for (i in 1:p) {
    for (j in 1:p) {
      lag <- abs(i - j)
      R[i, j] <- if (lag == 0) 1 else rho[lag]
    }
  }
  
  # Vetor r
  r <- rho[1:p]
  
  # Resolver R * phi = r
  tryCatch({
    phi <- solve(R, r)
    phi
  }, error = function(e) {
    rep(0, p)
  })
}

# -----------------------------------------------------------------------------
# 4. SELEÇÃO DE ORDEM (AIC)
# -----------------------------------------------------------------------------

#' Seleciona ordem ótima do PAR usando AIC
#' @param rho Vetor de autocorrelações
#' @param n Número de observações
#' @param p_max Ordem máxima a testar
#' @return Ordem ótima
selecionar_ordem_aic <- function(rho, n, p_max = 6) {
  aic <- rep(Inf, p_max + 1)
  
  # p = 0
  aic[1] <- n * log(1)
  
  for (p in 1:p_max) {
    phi <- yule_walker(rho, p)
    
    # Variância residual aproximada
    sigma2 <- 1
    for (k in 1:p) {
      sigma2 <- sigma2 - phi[k] * rho[k]
    }
    sigma2 <- max(sigma2, 0.01)
    
    # AIC
    aic[p + 1] <- n * log(sigma2) + 2 * p
  }
  
  # Retorna ordem com menor AIC
  which.min(aic) - 1
}

# -----------------------------------------------------------------------------
# 5. AJUSTE COMPLETO PAR(p)
# -----------------------------------------------------------------------------

#' Ajusta modelo PAR(p) para todos os postos
#' @param historico Array de vazões históricas
#' @param p_max Ordem máxima
#' @return Lista com parâmetros do modelo
ajustar_parp <- function(historico, p_max = 6) {
  n_postos <- dim(historico)[1]
  n_meses <- 12
  n_anos <- dim(historico)[3]
  
  cat("  Calculando estatísticas mensais...\n")
  stats <- calcular_estatisticas_mensais(historico)
  
  cat("  Calculando autocorrelações...\n")
  rho <- calcular_autocorrelacoes(historico, p_max)
  
  cat("  Ajustando coeficientes PAR(p)...\n")
  
  # Matrizes de parâmetros
  ordem <- matrix(0L, nrow = n_postos, ncol = n_meses)
  phi <- array(0, dim = c(n_postos, n_meses, p_max))
  sigma_a <- matrix(0, nrow = n_postos, ncol = n_meses)
  
  for (p in 1:n_postos) {
    for (m in 1:n_meses) {
      rho_pm <- rho[p, m, ]
      
      # Selecionar ordem
      ord <- selecionar_ordem_aic(rho_pm, n_anos, p_max)
      ordem[p, m] <- ord
      
      if (ord > 0) {
        # Calcular coeficientes
        phi_pm <- yule_walker(rho_pm, ord)
        phi[p, m, 1:ord] <- phi_pm
        
        # Variância residual
        sigma2 <- 1
        for (k in 1:ord) {
          sigma2 <- sigma2 - phi_pm[k] * rho_pm[k]
        }
        sigma_a[p, m] <- sqrt(max(sigma2, 0.01)) * stats$desvio[p, m]
      } else {
        sigma_a[p, m] <- stats$desvio[p, m]
      }
    }
  }
  
  list(
    media = stats$media,
    desvio = stats$desvio,
    ordem = ordem,
    phi = phi,
    sigma_a = sigma_a,
    rho = rho
  )
}

cat("[OK] Funções PAR(p) carregadas\n")
