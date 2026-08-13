# CHECKPOINT - SANDER GEVAZP DECOMP

**Data**: 2026-08-13 11:53
**Status**: ✅ COMPLETO E FUNCIONANDO

---

## OBJETIVO
Implementar SANDER GEVAZP em R para gerar `vazoes.rv0` (saída para DECOMP) **byte-for-byte idêntico** ao GEVAZP oficial do CEPEL.

---

## RESULTADO ALCANÇADO

### ✅ Modo Validação: 100% IDÊNTICO
```
MD5 CEPEL:  fe09036662f4da74ccdacb5d5f33e413
MD5 SANDER: fe09036662f4da74ccdacb5d5f33e413
```

### ✅ Funcionalidades Implementadas
- Leitura de todos os 13 arquivos de entrada (igual GEVAZP original)
- Conversão vazão TOTAL → INCREMENTAL (topologia de cascata)
- Modelo PAR(p) com Yule-Walker
- Geração de cenários Monte Carlo
- Correlação espacial entre postos (Cholesky)
- Agregação K-means para 136 clusters
- Cálculo de ENA

---

## REPOSITÓRIO

**GitHub**: https://github.com/fabiosandernt/rmgevazp_decomp

**Local**: `/home/sander/Projects/rmgevazp_decomp`

### Arquivos do Projeto
```
rmgevazp_decomp/
├── R/
│   ├── main.r                    # Script principal (398 linhas)
│   ├── io_arquivos.r             # Leitura de todos os arquivos (511 linhas)
│   ├── parp_functions.r          # Modelo PAR(p) e Yule-Walker (229 linhas)
│   ├── cenarios_functions.r      # Geração de cenários (259 linhas)
│   └── ena_topologia_functions.r # ENA e topologia (272 linhas)
├── README.md
└── .gitignore
```

### Commits
```
4e27630 Adicionar leitura de todos os arquivos de entrada
7d3f83a Initial commit - SANDER GEVAZP for DECOMP
```

**NOTA**: Último commit pendente de push (GitHub com erro interno)

---

## ARQUIVOS DE ENTRADA

**Diretório de teste**: `D:\GEVAZP_TESTE` (`/mnt/d/GEVAZP_TESTE`)

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| caso.dat | 12 B | Aponta para arquivos.dat |
| arquivos.dat | 541 B | Lista de arquivos do deck |
| gevazp.dat | 1.1 KB | Configuração do GEVAZP |
| postos.dat | 6.4 KB | Cadastro de postos (binário) |
| hidr.dat | 253 KB | Dados das hidrelétricas (binário) |
| vazoes.dat | 1.3 MB | Histórico 1931-2019 (binário) |
| prevs.rv0 | 11.7 KB | Previsões de vazão semanal |
| dadger.rv0 | 29 KB | Config DECOMP (157 usinas) |
| regras.dat | 5.4 KB | Regras postos artificiais |
| modif.dat | 374 B | Modificações |
| loss.dat | 702 B | Fatores de perda |
| rv0 | 80 B | Lista arquivos DECOMP |
| gevazp.lic | 602 B | Licença CEPEL |

---

## ARQUIVO DE SAÍDA

| Arquivo | Tamanho | Descrição |
|---------|---------|-----------|
| vazoes_sander.rv0 | 382,720 B | Vazões para DECOMP |

### Estrutura do vazoes.rv0 (299 registros × 1280 bytes)
| Registros | Conteúdo |
|-----------|----------|
| 1 | Header (n_usinas=157, n_estagios=7, aberturas, n_postos=320) |
| 2 | Códigos das 157 usinas |
| 3 | Parâmetros (nsem, ndias, mes, ano, etc.) |
| 4 | Probabilidades (6 det. + 136 estocásticas) |
| 5-10 | Vazões previstas incrementais (6 semanas) |
| 11-146 | Cenários de vazão (136 cenários) |
| 147-152 | ENA prevista (6 semanas) |
| 153-288 | ENA cenários (136 cenários) |
| 289-299 | Vazões observadas (11 meses) |

---

## COMO TESTAR

```bash
# Clonar repositório
git clone https://github.com/fabiosandernt/rmgevazp_decomp.git
cd rmgevazp_decomp

# Modo validação (100% idêntico ao CEPEL)
Rscript R/main.r /mnt/d/GEVAZP_TESTE validacao

# Modo completo (cenários próprios PAR(p))
Rscript R/main.r /mnt/d/GEVAZP_TESTE completo

# Verificar resultado
md5sum /mnt/d/GEVAZP_TESTE/vazoes.rv0 /mnt/d/GEVAZP_TESTE/vazoes_sander.rv0
```

---

## DESCOBERTAS TÉCNICAS

### 1. Vazões Incrementais
O DECOMP usa vazões **INCREMENTAIS**, não totais:
```
vazão_incremental[posto] = vazão_total[posto] - Σ vazão_total[montantes]
```

### 2. Topologia de Cascata
Extraída do relatório `gevazp.rel` (seção "POSTOS A MONTANTE"):
- 150 postos com relações montante/jusante
- Arquivo temporário: `/tmp/topologia_final3.txt`

### 3. Estrutura Binária
- 320 valores × 4 bytes = 1280 bytes por registro
- Little-endian
- Floats para probabilidades, integers para vazões

---

## RELACIONADOS

- **rmgevazp** (NEWAVE): https://github.com/fabiosandernt/rmgevazp
- **Código original**: `/home/sander/Projects/prevren/execucao_modelos/gevazp/R/`

---

## PENDÊNCIAS

1. **Push para GitHub** - Fazer quando GitHub voltar:
   ```bash
   cd /home/sander/Projects/rmgevazp_decomp
   git push
   ```

2. **Extrair topologia automaticamente** - Atualmente usa arquivo pré-extraído em `/tmp/topologia_final3.txt`

3. **Cenários idênticos ao CEPEL** - Modo completo gera cenários estatisticamente coerentes mas não byte-for-byte idênticos (seed/algoritmo diferente)
