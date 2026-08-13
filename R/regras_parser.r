# =============================================================================
# SANDER GEVAZP - Parser de REGRAS.DAT
# =============================================================================
# Implementa avaliação de fórmulas de postos artificiais
# Funções: VAZ(), SE(), MAX(), MIN()
# Operações: +, -, *, /
# Comparadores: <, <=, >, >=, =, <>
# Desenvolvido por Sander
# =============================================================================

# -----------------------------------------------------------------------------
# 1. LEITURA DE REGRAS.DAT
# -----------------------------------------------------------------------------

#' Lê e parseia REGRAS.DAT
#' @param arquivo Caminho para regras.dat
#' @return Lista com regras por posto e mês
ler_regras_completo <- function(arquivo = "regras.dat") {
  if (!file.exists(arquivo)) {
    return(list(regras = list(), postos_artificiais = integer(0)))
  }
  
  lines <- readLines(arquivo, warn = FALSE)
  
  regras <- list()
  postos_artificiais <- c()
  
  for (line in lines) {
    # Ignorar linhas de header, comentário ou vazias
    if (grepl("^\\s*POST|^\\s*XXXX|^\\s*$|^\\s*CONF|^\\s*9999", line)) next
    
    # Tentar extrair posto, mês e fórmula
    # Formato: POST MES [CONF] FORMULA
    # Colunas aproximadas: 1-5 posto, 6-10 mês, 11-15 conf, 16+ fórmula
    
    parts <- strsplit(trimws(line), "\\s+")[[1]]
    if (length(parts) < 3) next
    
    posto <- suppressWarnings(as.integer(parts[1]))
    mes <- suppressWarnings(as.integer(parts[2]))
    
    if (is.na(posto) || posto <= 0 || posto > 320) next
    if (is.na(mes)) next
    
    # Fórmula é o resto da linha após posto e mês
    # Encontrar posição da fórmula (após os números iniciais)
    # Tentar extrair a partir do terceiro campo
    if (length(parts) >= 3) {
      # Se o terceiro campo é um número (conf), fórmula começa no 4o
      if (!is.na(suppressWarnings(as.integer(parts[3]))) && length(parts) >= 4) {
        formula <- paste(parts[4:length(parts)], collapse = "")
      } else {
        formula <- paste(parts[3:length(parts)], collapse = "")
      }
    } else {
      next
    }
    
    # Limpar fórmula
    formula <- gsub("\\s+", "", formula)  # Remover espaços
    formula <- toupper(formula)           # Maiúsculas
    
    # Ignorar fórmulas "0" (posto normal)
    if (formula == "0") next
    
    # Criar chave posto_mes (mes=0 significa todos os meses)
    chave <- paste0(posto, "_", mes)
    regras[[chave]] <- list(
      posto = posto,
      mes = mes,
      formula = formula
    )
    
    postos_artificiais <- unique(c(postos_artificiais, posto))
  }
  
  list(
    regras = regras,
    postos_artificiais = sort(postos_artificiais)
  )
}

# -----------------------------------------------------------------------------
# 2. AVALIADOR DE FÓRMULAS
# -----------------------------------------------------------------------------

#' Avalia uma fórmula de posto artificial
#' @param formula String com a fórmula (ex: "VAZ(123)+VAZ(456)")
#' @param vazoes Vetor de vazões [320]
#' @return Valor calculado
avaliar_formula <- function(formula, vazoes) {
  if (is.null(formula) || formula == "" || formula == "0") {
    return(NA)
  }
  
  # Converter VAZ(nnn) para valores
  expr <- formula
  
  # Substituir VAZ(nnn) pelo valor correspondente
  vaz_matches <- gregexpr("VAZ\\(([0-9]+)\\)", expr)
  if (vaz_matches[[1]][1] != -1) {
    postos_ref <- as.integer(regmatches(expr, gregexpr("(?<=VAZ\\()([0-9]+)(?=\\))", expr, perl = TRUE))[[1]])
    for (p in postos_ref) {
      valor <- if (p >= 1 && p <= length(vazoes)) vazoes[p] else 0
      expr <- sub(paste0("VAZ\\(", p, "\\)"), as.character(valor), expr)
    }
  }
  
  # Avaliar funções SE, MAX, MIN
  expr <- avaliar_funcoes(expr)
  
  # Avaliar expressão matemática final
  resultado <- tryCatch({
    eval(parse(text = expr))
  }, error = function(e) {
    warning("Erro ao avaliar fórmula: ", formula, " -> ", expr)
    NA
  })
  
  # Garantir que não seja negativo
  if (!is.na(resultado) && resultado < 0) resultado <- 0
  
  as.integer(round(resultado))
}

#' Avalia funções SE, MAX, MIN recursivamente
#' @param expr Expressão com funções
#' @return Expressão avaliada
avaliar_funcoes <- function(expr) {
  max_iter <- 50  # Limite de iterações para evitar loop infinito
  iter <- 0
  
  while (iter < max_iter) {
    iter <- iter + 1
    expr_anterior <- expr
    
    # Avaliar MAX(a;b) - buscar mais simples primeiro
    while (grepl("MAX\\([^()]*;[^()]*\\)", expr)) {
      match <- regexpr("MAX\\([^()]*;[^()]*\\)", expr)
      if (match[1] != -1) {
        matched <- regmatches(expr, match)
        inner <- sub("^MAX\\(", "", sub("\\)$", "", matched))
        args <- strsplit(inner, ";")[[1]]
        if (length(args) >= 2) {
          a <- avaliar_expr_simples(args[1])
          b <- avaliar_expr_simples(args[2])
          resultado <- max(a, b, na.rm = TRUE)
          expr <- sub(matched, as.character(resultado), expr, fixed = TRUE)
        } else {
          break
        }
      } else {
        break
      }
    }
    
    # Avaliar MIN(a;b) - buscar mais simples primeiro
    while (grepl("MIN\\([^()]*;[^()]*\\)", expr)) {
      match <- regexpr("MIN\\([^()]*;[^()]*\\)", expr)
      if (match[1] != -1) {
        matched <- regmatches(expr, match)
        inner <- sub("^MIN\\(", "", sub("\\)$", "", matched))
        args <- strsplit(inner, ";")[[1]]
        if (length(args) >= 2) {
          a <- avaliar_expr_simples(args[1])
          b <- avaliar_expr_simples(args[2])
          resultado <- min(a, b, na.rm = TRUE)
          expr <- sub(matched, as.character(resultado), expr, fixed = TRUE)
        } else {
          break
        }
      } else {
        break
      }
    }
    
    # Avaliar SE(cond;true;false) - começar pelas mais internas
    while (grepl("SE\\([^()]*;[^()]*;[^()]*\\)", expr)) {
      match <- regexpr("SE\\([^()]*;[^()]*;[^()]*\\)", expr)
      if (match[1] != -1) {
        matched <- regmatches(expr, match)
        inner <- sub("^SE\\(", "", sub("\\)$", "", matched))
        args <- strsplit(inner, ";")[[1]]
        if (length(args) >= 3) {
          cond <- avaliar_condicao(args[1])
          resultado <- if (cond) avaliar_expr_simples(args[2]) else avaliar_expr_simples(args[3])
          expr <- sub(matched, as.character(resultado), expr, fixed = TRUE)
        } else {
          break
        }
      } else {
        break
      }
    }
    
    # Se não mudou, sair do loop
    if (expr == expr_anterior) break
  }
  
  expr
}

#' Avalia uma expressão simples (números e operações)
#' @param expr Expressão
#' @return Valor numérico
avaliar_expr_simples <- function(expr) {
  expr <- gsub("\\s+", "", expr)
  tryCatch({
    eval(parse(text = expr))
  }, error = function(e) {
    NA
  })
}

#' Avalia uma condição (comparações)
#' @param cond String com condição
#' @return TRUE ou FALSE
avaliar_condicao <- function(cond) {
  # Substituir operadores
  cond <- gsub("<>", "!=", cond)
  cond <- gsub("<=", "<=", cond)
  cond <- gsub(">=", ">=", cond)
  cond <- gsub("([^<>!])=([^=])", "\\1==\\2", cond)  # = para == (mas não <= >= !=)
  
  tryCatch({
    eval(parse(text = cond))
  }, error = function(e) {
    FALSE
  })
}

# -----------------------------------------------------------------------------
# 3. APLICAÇÃO DAS REGRAS
# -----------------------------------------------------------------------------

#' Aplica regras de postos artificiais às vazões
#' @param vazoes Matriz [320, n_semanas] de vazões
#' @param regras Lista de regras do ler_regras_completo()
#' @param mes_inicio Mês inicial do estudo
#' @return Matriz de vazões com postos artificiais calculados
aplicar_regras <- function(vazoes, regras, mes_inicio = 1) {
  if (length(regras$regras) == 0) {
    return(vazoes)
  }
  
  n_semanas <- ncol(vazoes)
  vazoes_calc <- vazoes
  
  # Identificar postos que tem previsão (soma > 0)
  postos_com_previsao <- which(rowSums(vazoes) > 0)
  
  # Para postos artificiais que NÃO tem previsão, manter como 0
  # (comportamento observado do CEPEL)
  # Só aplicar regras a postos que já tem algum valor ou são calculados
  # a partir de postos com valor
  
  # Por enquanto, não aplicar regras (manter comportamento CEPEL de zerar)
  # TODO: Implementar lógica completa de quando aplicar regras
  
  # Ordenar postos artificiais para resolver dependências
  # postos_ordenados <- ordenar_postos_dependencias(regras)
  
  # Por enquanto, zerar postos artificiais que não tem previsão
  for (posto in regras$postos_artificiais) {
    if (!(posto %in% postos_com_previsao)) {
      vazoes_calc[posto, ] <- 0L
    }
  }
  
  vazoes_calc
}

#' Ordena postos artificiais considerando dependências
#' @param regras Lista de regras
#' @return Vetor de postos ordenados
ordenar_postos_dependencias <- function(regras) {
  postos <- regras$postos_artificiais
  
  # Extrair dependências de cada posto
  deps <- list()
  for (p in postos) {
    deps[[as.character(p)]] <- c()
    
    # Buscar todas as regras deste posto
    for (chave in names(regras$regras)) {
      if (regras$regras[[chave]]$posto == p) {
        formula <- regras$regras[[chave]]$formula
        # Encontrar VAZ(nnn) na fórmula
        postos_ref <- as.integer(regmatches(formula, gregexpr("(?<=VAZ\\()([0-9]+)(?=\\))", formula, perl = TRUE))[[1]])
        deps[[as.character(p)]] <- unique(c(deps[[as.character(p)]], postos_ref))
      }
    }
  }
  
  # Ordenação topológica simples
  ordenados <- c()
  restantes <- postos
  max_iter <- length(postos) * 2
  iter <- 0
  
  while (length(restantes) > 0 && iter < max_iter) {
    iter <- iter + 1
    for (p in restantes) {
      # Verificar se todas as dependências já foram processadas
      deps_p <- deps[[as.character(p)]]
      deps_artificiais <- intersect(deps_p, postos)
      
      if (all(deps_artificiais %in% ordenados) || length(deps_artificiais) == 0) {
        ordenados <- c(ordenados, p)
        restantes <- setdiff(restantes, p)
        break
      }
    }
  }
  
  # Adicionar restantes (ciclos ou não resolvidos)
  ordenados <- c(ordenados, restantes)
  
  ordenados
}

cat("[OK] Parser de REGRAS.DAT carregado\n")
