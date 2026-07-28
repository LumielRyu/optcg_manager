# Expansao das funcionalidades para todos os TCGs

## Objetivo

Levar Colecao, Decks, Vendas, Marketplace, Procurados, precos da Liga,
importacoes, scanner e Semanais aos seis jogos do TCG BH sem tratar todos como
se fossem One Piece.

Jogos:

- One Piece
- Pokemon
- Digimon
- Magic: The Gathering
- Riftbound
- Yu-Gi-Oh

## Principio de arquitetura

Cada registro persistido recebe:

- `game_slug`: identifica o jogo;
- `catalog_card_id`: identidade estavel na API de origem;
- `card_code`: codigo exibido e usado nas buscas;
- `variant_id`: impressao, arte ou acabamento especifico;
- `format_slug`: formato do deck;
- `deck_zone`: zona do deck.

As telas compartilham apresentacao e operacoes. Catalogo, correspondencia de
preco, validacao de deck, legalidade e importacao usam adaptadores por jogo.

## Matriz das regras de deck

| Jogo/formato | Estrutura inicial suportada | Limite normal |
| --- | --- | --- |
| One Piece Construido | 1 Lider, 50 no principal, 10 DON!! | 4 por numero |
| Pokemon Padrao | 60 no principal | 4 por nome; Energia basica isenta |
| Digimon Construido | 50 no principal, 0-5 Digi-Eggs | 4 por numero |
| Magic Standard | 60+ no principal, 0-15 no sideboard | 4 por nome; terreno basico isento |
| Magic Commander | 99 no principal, 1 comandante | singleton; terreno basico isento |
| Riftbound Construido | 39 + Campeao escolhido, 1 Lenda, 12 runas, 3 campos, side 0 ou 8 | 3 por nome |
| Yu-Gi-Oh Advanced | 40-60 no principal, 0-15 Extra, 0-15 Side | 3 por nome antes da lista vigente |

Regras mutaveis, como rotacao, cartas banidas/restritas, pares proibidos e
excecoes escritas nas cartas, devem vir de snapshots versionados. O aplicativo
nao deve fixar essas listas para sempre no binario.

Fontes oficiais:

- One Piece: <https://en.onepiece-cardgame.com/rules/>
- Pokemon: <https://www.pokemon.com/us/play-pokemon/about/tournaments-rules-and-resources>
- Digimon: <https://world.digimoncard.com/rule/>
- Magic: <https://magic.wizards.com/formats>
- Riftbound: <https://playriftbound.com/en-us/news/organizedplay/riftbound-tournament-rules/>
- Yu-Gi-Oh: <https://www.yugioh-card.com/en/events/organizedplay/>

## Fases

### Fase 0 - Fundacao

- Registro comum dos jogos e formatos.
- Validador de quantidade, zonas, copias, identidade e restricoes dinamicas.
- Migracao aditiva e retrocompativel do Supabase.
- One Piece permanece como valor padrao para os dados existentes.

### Fase 1 - Colecao Pokemon

- Adicionar da Biblioteca Pokemon para a Colecao.
- Filtrar a Colecao por jogo.
- Exibir valor total com o cache da Liga Pokemon.
- Adicionar ao deck e mover para Vendas.
- Compartilhamento identifica o TCG.

Pokemon e o primeiro porque biblioteca e cache de precos ja estao ativos.

### Fase 2 - Colecao dos demais catalogos

Ordem sugerida:

1. Digimon
2. Yu-Gi-Oh
3. Riftbound
4. Magic

Cada adaptador converte a carta da API em um snapshot comum e define a chave
usada pela Liga. Magic exige tratamento de faces duplas e impressao; Yu-Gi-Oh
exige separar identidade da carta e impressao/set.

### Fase 3 - Decks legais

- Seletor de formato ao criar deck.
- Zonas proprias de cada jogo.
- Contadores e mensagens de validacao em tempo real.
- Snapshots de rotacao e listas banidas/restritas com data de vigencia.
- Exportadores/importadores especificos por plataforma e jogo.

### Fase 4 - Vendas, Marketplace e Procurados

- Filtros por TCG, set, condicao, variante e preco.
- Paginas publicas preservam `game_slug`.
- Preco manual ou percentual da Liga por jogo.
- Busca e enriquecimento usam o catalogo correto.

### Fase 5 - Precos da Liga

- Completar cache Pokemon.
- Ativar coletores Digimon, Magic, Riftbound e Yu-Gi-Oh.
- Monitor administrativo com TCG, edicao, cobertura, falhas e ultima coleta.
- Vincular variantes sem misturar arte, idioma ou acabamento.

### Fase 6 - Importacao e scanner

- Importacao por codigo usa o parser do jogo selecionado.
- Imagem/OCR escolhe primeiro o TCG e depois o candidato.
- Referencias visuais e limiares de similaridade separados por jogo.
- Revisao humana obrigatoria quando houver ambiguidade.

### Fase 7 - Semanais

- Nucleo comum de evento, rodada, classificacao e exportacao.
- Adaptadores de arquivo por programa oficial de cada jogo.
- Desempates, estrutura de partida e circuitos configurados por TCG/formato.
- Rankings nunca misturam jogos, formatos ou circuitos.

## Criterio de conclusao por modulo

Uma funcionalidade so e considerada disponivel para um TCG quando:

1. API e fallback carregam o catalogo;
2. identidade e variante permanecem estaveis;
3. preco da Liga usa a chave correta;
4. gravacao e leitura ficam isoladas por `game_slug`;
5. regras do formato possuem testes;
6. compartilhamentos e marketplace preservam o jogo;
7. fluxo desktop e celular passa no E2E;
8. dados One Piece existentes continuam intactos.
