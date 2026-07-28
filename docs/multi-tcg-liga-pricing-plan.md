# Plano de preços da Liga para múltiplos TCGs

Atualizado em 28/07/2026.

## Objetivo

Levar para Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh o fluxo de preços
que já funciona no One Piece: coletar o menor preço publicado na Liga,
resolver a variante correta da carta, salvar o resultado no Supabase e
reutilizá-lo na biblioteca, coleção, vendas e marketplace.

O plano evita copiar o atualizador do One Piece cinco vezes. O núcleo de
coleta, persistência, monitoramento e exibição deve ser compartilhado; apenas
as regras de identificação de edição e variante mudam por jogo.

## Estado verificado das fontes

Auditoria feita em produção, com navegador real, em 28/07/2026:

| TCG | Catálogo usado pelo app | Resultado | Itens informados |
| --- | --- | --- | ---: |
| One Piece | OPTCG API via `/api/optcg-cards` | operacional | 5.105 |
| Pokemon | Pokemon TCG API v2 | operacional no navegador | 20.479 |
| Digimon | Heroicc | operacional | 5.608 |
| Magic | Scryfall | operacional | paginação ativa |
| Riftbound | Riftcodex | operacional | 1.451 |
| Yu-Gi-Oh | YGOPRODeck v7 | operacional | 14.476 |

Os seis portais da Liga também responderam com uma página de edições:

- `ligaonepiece.com.br`
- `ligapokemon.com.br`
- `ligamagic.com.br`
- `ligayugioh.com.br`
- `ligadigimon.com.br`
- `ligariftbound.com.br`

A Pokemon TCG API bloqueou algumas chamadas feitas por clientes de terminal
com Cloudflare, mas respondeu HTTP 200 dentro do navegador do aplicativo.
Por isso a integração atual permanece direta. Se esse comportamento começar a
afetar visitantes, a migração deve ser para uma função proxy com cache, sem
expor a chave da API no cliente.

## Arquitetura proposta

### 1. Catálogo canônico

Cada carta precisa de uma identidade interna independente da fonte externa:

- `game_slug`
- `catalog_card_id`
- `card_code` ou número de colecionador
- `set_code`
- `language`
- `variant_key`
- `finish` quando existir
- URL da imagem usada para conferência

Os IDs das APIs devem ficar em uma tabela de aliases. Assim, uma troca futura
de API não invalida coleção, anúncios ou histórico de preço.

### 2. Cache unificado de preço

Generalizar o cache atual para uma tabela como `tcg_card_price_cache`, com:

- `game_slug`
- `lookup_code`
- `card_code`
- `edition_code`
- `variant_key`
- `min_price`
- `source_url`
- `source_image_url`
- `resolved_at`
- `match_method`
- `match_confidence`

A chave única deve incluir ao menos jogo e `lookup_code`. Dados antigos nunca
devem ser apagados porque uma coleta isolada falhou.

### 3. Adaptadores por jogo

Um adaptador por TCG transforma catálogo e HTML da Liga no modelo comum:

- **One Piece:** preservar código, paralelo, promoção e pre-release já
  tratados.
- **Pokemon:** combinar número, edição, idioma e acabamento
  normal/holo/reverse.
- **Digimon:** combinar código, arte alternativa, promoção e pre-release.
- **Magic:** combinar código da coleção, número de colecionador, idioma e
  acabamento normal/foil.
- **Riftbound:** combinar coleção, número de colecionador e acabamento.
- **Yu-Gi-Oh:** combinar código da edição, raridade, idioma e variante.

Correspondências incertas devem ficar visíveis no monitor administrativo e
não podem sobrescrever silenciosamente uma correspondência de alta confiança.

### 4. Coleta e agendamento

Reaproveitar o comportamento operacional validado no One Piece:

- execuções às 00:00, 08:00 e 16:00 no fuso de São Paulo;
- uma edição por vez;
- intervalo mínimo configurável, inicialmente 30 segundos;
- tentativas com espera progressiva para 403, 429 e erros temporários;
- checkpoint por jogo e edição para retomar uma execução interrompida;
- limite total de execução e divisão em lotes quando necessário;
- resumo final com edições completas, parciais, vazias e com erro.

Como o HTML da Liga não é uma API pública estável, seletores e formatos devem
ter testes de amostra. Antes de ampliar a frequência, também é necessário
confirmar os termos de uso e manter uma taxa conservadora.

### 5. Consumo no aplicativo

Criar um provedor comum de preço e usar a mesma apresentação em:

1. biblioteca;
2. detalhe da carta;
3. coleção e valor total;
4. cartas à venda;
5. marketplace;
6. cartas procuradas, quando útil.

Cada cartão deve mostrar preço, data da consulta e um estado visual:
`verificada`, `sem anúncio`, `correspondência incerta` ou `ainda não
verificada`.

### 6. Administração e qualidade

Expandir o monitor atual para filtrar por TCG e exibir:

- edições publicadas, processadas e pendentes;
- última atualização por edição;
- quantidade e percentual de cartas resolvidas;
- erros e tentativas recentes;
- correspondências de baixa confiança;
- idade do preço e duração da última execução.

## Ordem recomendada de implementação

1. Generalizar schema, repositório e componentes visuais sem alterar o One
   Piece.
2. Implementar Pokemon como primeiro adaptador, validando idioma e
   acabamento.
3. Implementar Yu-Gi-Oh e Magic, que exigem tratamento explícito de edição,
   idioma e acabamento.
4. Implementar Digimon e Riftbound.
5. Integrar coleção, vendas e marketplace de cada TCG somente depois que a
   cobertura da biblioteca estiver validada.
6. Ativar o agendamento geral de forma gradual e acompanhar bloqueios,
   duração e qualidade durante os primeiros ciclos.

## Critérios para concluir cada TCG

- pelo menos 95% das cartas publicadas pela Liga resolvidas automaticamente;
- 100% das variantes de uma amostra manual crítica conferidas;
- nenhuma substituição de preço causada somente por nome parecido;
- execução retomável e sem perda de dados após falha;
- preço e estado de verificação consistentes em todas as telas;
- monitor administrativo e testes de regressão atualizados.
