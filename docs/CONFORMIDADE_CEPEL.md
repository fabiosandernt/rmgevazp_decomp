# Conformidade com CEPEL GEVAZP 11

**Data**: 2026-08-13
**Versão SANDER GEVAZP**: 3.0
**Referência**: Manual GEVAZP 11 - CEPEL

---

## ✅ Funcionalidades Implementadas

| Item | CEPEL GEVAZP 11 | SANDER GEVAZP | Status |
|------|-----------------|---------------|--------|
| **Tipo execução** | 99 = DECOMP | Implementado | ✅ |
| **Modelo PAR(p)** | Autorregressivo periódico | Yule-Walker | ✅ |
| **Ordem máxima PAR(p)** | 1-11 | Até 6 (configurável) | ✅ |
| **Número de postos** | 320 ou 600 | 320 (detecta config) | ✅ |
| **Agregação cenários** | K-means | K-means | ✅ |
| **Vazões incrementais** | Total - Σ montantes | Implementado | ✅ |
| **Correlação espacial** | Cholesky | Implementado | ✅ |
| **Cálculo de ENA** | Por subsistema | Implementado | ✅ |
| **Formato saída binário** | 320 × 4 bytes little-endian | Igual | ✅ |
| **Revisões DECOMP** | RV0, RV1, RV2... | Auto-detecta | ✅ |
| **Case insensitive** | Arquivos maiúsculo/minúsculo | Implementado | ✅ |

### Arquivos de Entrada Lidos (13 arquivos)

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| caso.dat | Aponta para arquivos.dat | ✅ Lê |
| arquivos.dat | Lista de arquivos do deck | ✅ Lê |
| gevazp.dat | Configuração principal | ✅ Lê |
| postos.dat | Cadastro de postos (binário) | ✅ Lê |
| hidr.dat | Dados das hidrelétricas (binário) | ✅ Lê |
| vazoes.dat | Histórico de vazões (binário) | ✅ Lê |
| prevs.rvX | Previsões de vazão semanal | ✅ Lê |
| dadger.rvX | Configuração DECOMP | ✅ Lê |
| regras.dat | Regras postos artificiais | ✅ Lê (não processa) |
| modif.dat | Modificações configuração | ✅ Lê (não processa) |
| loss.dat | Fatores de perda | ✅ Lê |
| rvX | Lista arquivos DECOMP | ✅ Lê |
| gevazp.lic | Licença CEPEL | ✅ Verifica |

### Arquivo de Saída

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| vazoes_sander.rvX | Vazões para DECOMP | ✅ Gera |

#### Estrutura do vazoes.rvX (299 registros × 1280 bytes)

| Registros | Conteúdo | Status |
|-----------|----------|--------|
| 1 | Header (n_usinas, n_estagios, aberturas, n_postos) | ✅ |
| 2 | Códigos das usinas | ✅ |
| 3 | Parâmetros (nsem, ndias, mes, ano) | ✅ |
| 4 | Probabilidades (6 det. + N estocásticas) | ✅ |
| 5-10 | Vazões previstas incrementais (6 semanas) | ✅ |
| 11-146 | Cenários de vazão (N cenários) | ✅ |
| 147-152 | ENA prevista (6 semanas) | ✅ |
| 153-288 | ENA cenários (N cenários) | ✅ |
| 289-299 | Vazões observadas (11 meses) | ✅ |

---

## ⚠️ Funcionalidades NÃO Implementadas

### Modelo MS-PAR(p) - El Niño/La Niña

| Item | Descrição | Impacto |
|------|-----------|---------|
| ONI.DAT | Histórico do índice ONI | Não lê |
| ONIPREV.DAT | Previsões probabilísticas ONI | Não lê |
| MSPAR.DAT | Configuração MS-PAR(p) | Não lê |
| Estados ENOS | 0/1/2/3 (Neutro/Niña/Niño) | Não considera |

**Consequência**: Usa único conjunto de parâmetros PAR(p), sem distinção de estados climáticos.

### Incerteza Eólica

| Item | Descrição | Impacto |
|------|-----------|---------|
| INDICES.CSV | Lista de arquivos eólicos | Não lê |
| EOLICA-*.CSV | Cadastro/config usinas eólicas | Não lê |
| HIST-VENTOS.CSV | Histórico velocidades vento | Não lê |
| PARQUE-EOLICO-*.CSV | Dados PEEs | Não lê |
| VELOCIDADES.XXX | Saída velocidades vento | Não gera |

**Consequência**: Não processa dados de geração eólica.

### Tendência Hidrológica

| Item | Descrição | Impacto |
|------|-----------|---------|
| VAZPAST.DAT | Arquivo de tendências | Não processa |
| Flag registro 18 | Tendência 0=Não, 1=Sim | Ignora |

**Consequência**: Não aplica ajuste de tendência ao histórico.

### Regras de Postos Artificiais

| Item | Descrição | Impacto |
|------|-----------|---------|
| regras.dat | Fórmulas de cálculo | Lê mas não executa |
| Operações | +, -, *, / | Não processa |
| Funções | MAX(), MIN(), SE() | Não processa |
| VAZ(posto) | Referência a vazão | Não processa |

**Consequência**: Postos artificiais não são calculados dinamicamente.

### Modificações de Configuração

| Item | Descrição | Impacto |
|------|-----------|---------|
| PARTIF | Usina sem registro vazão natural | Lê mas não aplica |
| VINCR | Usina com vazão lateral | Lê mas não aplica |

**Consequência**: Usa configuração padrão sem modificações.

### Outras Funcionalidades

| Item | Descrição | Status |
|------|-----------|--------|
| Matriz correlação mensal | Opção 1 no gevazp.dat | Usa anual |
| Ajuste condicional vazão | Valores extremos | Não implementado |
| Estudos prospectivos | VEC, MLT, ESPC | Não implementado |
| Formato PARALELO | Opção 0 (NEWAVE) | Não implementado |
| Formato ÁRVORE | Opção 1 (multi-estágio) | Não implementado |
| Testes estatísticos | TESTES.REL | Não gera |
| Relatório completo | GEVAZP.REL | Não gera |

---

## 📊 Modos de Operação

### Modo `validacao`
- Lê cenários do arquivo oficial (vazoes.rvX)
- Gera saída **100% byte-for-byte idêntica** ao CEPEL
- Útil para validar a leitura e escrita de arquivos

### Modo `completo`
- Gera cenários próprios com modelo PAR(p)
- Vazões previstas **idênticas** ao CEPEL
- Cenários **estatisticamente similares** mas não idênticos (seed diferente)
- Funciona **sem arquivo oficial**

---

## 🔧 Parâmetros do Modelo

| Parâmetro | Valor | Notas |
|-----------|-------|-------|
| Ordem máxima PAR(p) | 6 | Configurável |
| Número de postos | 320 | Fixo |
| Cenários Monte Carlo | N × 10 | Depois agrega para N |
| Método agregação | K-means | Igual CEPEL |
| Correlação espacial | Cholesky | Igual CEPEL |

---

## 📁 Estrutura do Projeto

```
rmgevazp_decomp/
├── R/
│   ├── main.r                    # Script principal
│   ├── io_arquivos.r             # Leitura de arquivos
│   ├── parp_functions.r          # Modelo PAR(p)
│   ├── cenarios_functions.r      # Geração de cenários
│   └── ena_topologia_functions.r # ENA e topologia
├── data/
│   └── topologia_cascata.txt     # Relações montante/jusante
├── docs/
│   └── CONFORMIDADE_CEPEL.md     # Este documento
├── Dockerfile
├── docker-entrypoint.sh
├── README.md
├── CHECKPOINT.md
└── .gitignore
```

---

## 🚀 Roadmap Futuro (se necessário)

1. **MS-PAR(p)** - Suporte a El Niño/La Niña
2. **Regras postos artificiais** - Parser de fórmulas
3. **Tendência hidrológica** - Ajuste temporal
4. **Incerteza eólica** - Processamento de ventos
5. **Relatórios** - GEVAZP.REL, TESTES.REL
6. **Formato NEWAVE** - Opção PARALELO

---

## 📚 Referências

1. Manual GEVAZP 11 - CEPEL (gevazp11-manual.md)
2. Maceira, M.E.P.; Bezerra, C.M.B. – "Modelo de Geração de Séries Sintéticas de Energias e Vazões"
