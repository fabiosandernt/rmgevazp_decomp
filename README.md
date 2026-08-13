# SANDER GEVAZP - DECOMP

Gerador de Vazões Sintéticas para **DECOMP** usando metodologia PAR(p) - Periodic AutoRegressive com Yule-Walker.

## 🎯 Objetivo

Gerar arquivo `vazoes.rv0` compatível com o modelo DECOMP do setor elétrico brasileiro, produzindo saída **byte-for-byte idêntica** ao GEVAZP oficial do CEPEL (no modo validação).

## ✅ Status

| Funcionalidade | Status |
|----------------|--------|
| Vazões previstas | ✅ 100% idênticas ao CEPEL |
| Conversão Total → Incremental | ✅ Implementado |
| Modelo PAR(p) | ✅ Implementado |
| Geração de cenários | ✅ Implementado |
| Correlação espacial | ✅ Implementado |
| Agregação K-means | ✅ Implementado |
| Cálculo ENA | ✅ Implementado |

## 📁 Estrutura

```
rmgevazp_decomp/
├── R/
│   ├── main.r                    # Script principal
│   ├── parp_functions.r          # Modelo PAR(p) e Yule-Walker
│   ├── cenarios_functions.r      # Geração e agregação de cenários
│   └── ena_topologia_functions.r # ENA e topologia de cascata
├── README.md
└── .gitignore
```

## 🚀 Como Usar

### Pré-requisitos

- R >= 4.0
- Arquivos de entrada DECOMP:
  - `dadger.rv0` - Configuração das usinas
  - `prevs.rv0` - Previsões de vazão
  - `vazoes.dat` - Histórico de vazões
  - `gevazp.rel` - Relatório GEVAZP (para topologia)

### Execução

```bash
# Modo validação (100% idêntico ao CEPEL)
Rscript R/main.r /caminho/para/dados validacao

# Modo completo (cenários próprios PAR(p))
Rscript R/main.r /caminho/para/dados completo
```

### Saída

- `vazoes_sander.rv0` - Arquivo de vazões para DECOMP (382,720 bytes)

## 📊 Estrutura do vazoes.rv0

| Registros | Conteúdo |
|-----------|----------|
| 1 | Header (n_usinas, n_estagios, aberturas, n_postos) |
| 2 | Códigos das 157 usinas |
| 3 | Parâmetros |
| 4 | Probabilidades (6 determinísticas + 136 estocásticas) |
| 5-10 | Vazões previstas incrementais (6 semanas) |
| 11-146 | Cenários de vazão (136 cenários) |
| 147-152 | ENA prevista (6 semanas) |
| 153-288 | ENA cenários (136 cenários) |
| 289-299 | Vazões observadas (11 meses) |

**Total**: 299 registros × 1280 bytes = 382,720 bytes

## 🔬 Metodologia

### 1. Conversão Total → Incremental

O DECOMP usa vazões **incrementais** (não totais). A conversão usa a topologia de cascata:

```
vazão_incremental[posto] = vazão_total[posto] - Σ vazão_total[montantes]
```

### 2. Modelo PAR(p)

- **Estatísticas mensais**: média, desvio padrão por posto/mês
- **Autocorrelação**: lags 1-6 com periodicidade mensal
- **Yule-Walker**: resolução das equações para coeficientes φ
- **Seleção de ordem**: critério AIC

### 3. Geração de Cenários

- **Correlação espacial**: matriz 320×320 dos resíduos
- **Cholesky**: decomposição para ruído correlacionado
- **Monte Carlo**: 1360 cenários sintéticos
- **K-means**: agregação para 136 clusters

## 📈 Resultados

### Modo Validação
```
MD5 CEPEL:  fe09036662f4da74ccdacb5d5f33e413
MD5 SANDER: fe09036662f4da74ccdacb5d5f33e413
✅ ARQUIVOS 100% IDÊNTICOS
```

### Modo Completo
```
✅ Vazões previstas: 100% idênticas ao CEPEL
✅ Cenários: Gerados com modelo PAR(p) próprio
○  Cenários: Estatisticamente coerentes (correlação 0.80 com CEPEL)
```

## 🔗 Relacionados

- [rmgevazp](https://github.com/fabiosandernt/rmgevazp) - Versão para NEWAVE (PARP.DAT, CORVAZ.DAT)

## 👨‍💻 Autor

Desenvolvido por **Sander**

## 📄 Licença

MIT License
