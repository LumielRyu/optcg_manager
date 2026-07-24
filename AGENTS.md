# Memoria de continuidade do OPTCG Manager

Este arquivo e a memoria persistente das sessoes de trabalho deste repositorio.
Ele existe para que uma nova janela do Codex consiga retomar o contexto sem
depender do historico da conversa.

## Protocolo para futuras sessoes

1. Leia este arquivo inteiro antes de iniciar uma tarefa no repositorio.
2. Consulte `git status`, o diff relevante e os testes antes de assumir que o
   estado descrito aqui ainda e atual.
3. Ao concluir trabalho material, atualize as secoes "Estado atual", "Pendencias"
   e "Diario de sessoes".
4. Registre fatos verificados separadamente de hipoteses ou itens que ainda
   precisam de confirmacao.
5. Nunca copie tokens, chaves, senhas, conteudo de `.env` ou dados pessoais para
   esta memoria.
6. Preserve mudancas existentes do usuario. Nao descarte o worktree sujo sem
   autorizacao explicita.

## Visao geral do produto

- Aplicativo Flutter chamado publicamente de **OPTCG BH**.
- Gerencia catalogo e colecao de cartas, decks, vendas, procuras, marketplace e
  torneios semanais.
- Usa Riverpod e GoRouter no app, Supabase para autenticacao/dados e funcoes
  JavaScript na Vercel.
- Oferece suporte a One Piece, Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh.
- O repositorio Git real fica nesta pasta interna:
  `D:\Aplicativo\optcg_manager\optcg_manager`.
- Branch observada em 23/07/2026: `main`, alinhada com `origin/main` no commit
  `24ea926`.

## Historico recuperado

### Trabalho commitado ate 10/07/2026

Os commits mais recentes indicam esta sequencia:

- Integracao e cache de precos da Liga One Piece, incluindo variantes paralelas,
  solicitacao de atualizacao por workflow e execucao diaria.
- Renomeacao publica para OPTCG BH e expiracao semanal de anuncios.
- Otimizacao do carregamento inicial do OCR.
- Endurecimento da configuracao web e reducao dos arquivos enviados a Vercel.
- Grande revisao visual do site: layout premium/editorial, superficies mais
  suaves, marketplace editorial e uso ampliado das imagens editoriais.
- Correcao da traducao dos textos das cartas.

Ultimos commits, do mais novo para o mais antigo:

- `24ea926` - Extend editorial visuals across site
- `b5ff7ec` - Implement editorial marketplace layout
- `22b8b3a` - Fix card text translation
- `f770803` - Soften app layout surfaces
- `7fb9865` - Polish premium visual layout
- `2741775` - Refresh site visual design

### Trabalho nao commitado recuperado (principalmente 14 a 17/07/2026)

Em 23/07/2026 havia um lote grande no worktree: 32 arquivos rastreados
alterados (aproximadamente 1.059 insercoes e 578 remocoes) e muitos arquivos
novos. O conteudo indica:

- **Central de semanais**
  - Seletor de jogos em `/weeklies`.
  - One Piece em `/weeklies/one-piece`.
  - Pokemon em `/weeklies/pokemon`.
  - Revisao ampla do dashboard semanal, navegacao, layout responsivo,
    classificacoes, area administrativa e estados de erro.

- **Relatorios oficiais de One Piece**
  - Importacao e parser de standings.
  - Persistencia no Supabase e SQL com politicas para leitura publica e
    administracao.
  - Ranking mensal acumulado por jogador e por lider.
  - Metagame, historico de arquivos, CSV e visualizacao para TV.
  - Testes do parser e do ranking mensal.

- **Relatorios oficiais de Pokemon**
  - Importacao de arquivos TDF/XML, validacao antes da gravacao e remocao de
    datas de nascimento do payload serializado.
  - Historico persistido no Supabase, auditoria de alteracoes e funcao SQL de
    restauracao.
  - Circuitos independentes de quinta-feira e sabado, ranking acumulado e
    classificacao final unificada.
  - Exportacao CSV protegida contra formula injection, selecao de arquivos para
    web/IO e visualizacao para TV.
  - Testes de parser, validador, CSV e circuitos.

- **Seguranca e observabilidade**
  - Utilitarios compartilhados para CORS, origens permitidas, exigencia de JSON,
    rate limiting e headers defensivos.
  - Logs estruturados, `X-Request-ID`, sanitizacao de erros e endpoint para
    erros do cliente.
  - Endpoint `/api/health` com verificacao da configuracao e dependencia publica
    do Supabase.
  - Testes Node para seguranca e observabilidade.

- **Qualidade e operacao**
  - Gate local em `scripts/quality_gate.py`.
  - GitHub Actions para analise/testes/build, monitor de saude horario e smoke
    test diario de producao.
  - Smoke tests com Puppeteer e artefatos de diagnostico.
  - Scripts npm para analise, testes, cobertura, qualidade, build e E2E.

- **Web e experiencia**
  - Metadados, manifest, `robots.txt`, `sitemap.xml`, bootstrap e service worker
    PWA customizados.
  - Captura de erros Flutter no cliente.
  - Componentes reutilizaveis de acessibilidade e erro assincrono.
  - Ajustes de navegacao, catalogo, autenticacao, marketplace, telas TCG,
    responsividade e suporte a teclado/leitores de tela.
  - Testes de acessibilidade, metadados, budget de assets e seguranca do pacote.

## Estado atual verificado

Verificado localmente em **23/07/2026**:

- `npm run quality`: **aprovado**.
- Validacao de JSON e sintaxe de JavaScript/Python: aprovada.
- Testes Node das APIs: **9/9 passaram**.
- `flutter analyze --fatal-infos --fatal-warnings`: sem problemas.
- Testes Flutter: **48/48 passaram**.
- Branch local e `origin/main`: 0 commits de diferenca, ambos em `24ea926`.
- Todo o trabalho posterior a 10/07 descrito acima continua sem commit.

Artefatos visuais em `artifacts/` mostram testes locais de One Piece e Pokemon
em desktop, mobile e TV. Eles sao evidencias de uma rodada anterior e podem
estar desatualizados em relacao ao codigo atual.

## Pendencias e riscos conhecidos

- Organizar e revisar o lote grande de mudancas antes de fazer commits; nao
  assumir que todos os arquivos novos devem entrar no mesmo commit.
- Confirmar se os SQLs novos de relatorios One Piece/Pokemon e auditoria foram
  realmente aplicados no Supabase. A existencia local dos arquivos nao prova a
  aplicacao remota.
- Reexecutar o E2E das rotas semanais no ambiente correto:
  - um artefato local anterior de One Piece registrou 404 em
    `/api/optcg-cards`;
  - um artefato anterior de Pokemon nao encontrou os textos das ligas de quinta
    e sabado;
  - um smoke anterior de producao tratou HTTP 304 como falha.
- Confirmar o estado atual do deploy de producao; ele nao foi consultado nesta
  sessao.
- Reformular a atualizacao de precos da Liga One Piece:
  - a coleta por edicao, correspondencia de variantes, interface e agenda foram
    implementadas e publicadas em 23/07/2026;
  - `sql/liga_card_price_cache.sql` foi aplicado pelo usuario e verificado em
    23/07/2026: leitura publica funciona e escrita autenticada comum retorna
    HTTP 403.
- Decidir se `tmp_video_frames/`, `tmp_video_frames_2/`, `artifacts/`,
  `android/build/` e saidas locais da Vercel devem ser ignorados ou removidos do
  conjunto a versionar. Nao apagar sem verificar o uso e a intencao do usuario.
- O README ainda descreve apenas build web e storage; ele nao cobre as novas
  funcionalidades de torneios e operacao.

## Comandos uteis

```powershell
npm run quality
npm run quality:full
npm run test:e2e
git status --short --branch
git diff --stat
```

## Diario de sessoes

### 23/07/2026 - Recuperacao de contexto e criacao da memoria

- Pedido do usuario: reconstruir o que foi feito nas sessoes anteriores e criar
  um resumo persistente para novas janelas.
- Fontes consultadas: historico e reflog do Git, status/diff, datas dos arquivos,
  rotas, modelos, servicos, repositories, SQL, workflows, testes e artefatos E2E.
- Resultado: historico recuperado e consolidado neste arquivo.
- Validacao executada: `npm run quality`, aprovado integralmente.
- Nenhum commit, deploy, alteracao remota ou aplicacao de SQL foi realizado.

### 23/07/2026 - Revisao do preco automatico da Liga One Piece

- As paginas publicas de edicoes e da edicao OP-16 foram inspecionadas sem
  gravacoes remotas.
- A pagina de edicoes retornou 57 edicoes principais e 19 auxiliares.
- A pagina OP-16 retornou 159 registros em um unico `cardsjson`; cada registro
  possui codigo exato da variante, `precoMenor`, media e `precoMaior`.
- O cache Supabase estava acessivel, com 483 linhas. Na comparacao exata com os
  159 codigos exibidos na pagina OP-16, apenas 2 tinham correspondencia no
  cache e ambos estavam com menor preco diferente do valor atual.
- O workflow existente roda uma vez ao dia e consulta somente cartas ativas em
  vendas, individualmente. Ele nao popula o catalogo completo por edicao.
- Riscos identificados:
  - o app aceita qualquer linha remota sem validar `resolved_at`;
  - as politicas SQL permitem que qualquer usuario autenticado insira ou altere
    precos;
  - a identificacao de variantes depende parcialmente do nome, enquanto a Liga
    fornece sufixos exatos como `-AA`, `-SP`, `-MA`, `-DP`, `-TR` e `-FA`;
  - o componente de preco da biblioteca esta definido, mas sem uso no layout.
- O `robots.txt` observado declara `Crawl-delay: 360`. A recomendacao e usar
  coleta por edicao com ritmo respeitoso, priorizacao das edicoes recentes e
  rotacao das antigas, ou obter autorizacao/API oficial antes de atualizar tudo
  tres vezes ao dia.
- Nenhuma implementacao, commit, deploy ou mudanca no banco foi feita durante
  esta revisao.

### 23/07/2026 - Precos automaticos por edicao e deploy de producao

- Criado `scripts/update_liga_edition_price_cache.py`.
- O coletor descobre 78 edicoes, atualiza sempre as tres mais recentes e divide
  as demais em tres grupos. Com tres execucoes diarias, edicoes recentes sao
  atualizadas tres vezes e as antigas uma vez ao dia.
- O intervalo padrao entre paginas e 360 segundos, conforme o `robots.txt`.
- O workflow `update-liga-price-cache.yml` agenda execucoes as 03:17, 11:17 e
  19:17 UTC, equivalentes a 00:17, 08:17 e 16:17 em Brasilia.
- Variantes como `-AA`, `-SP`, `-MA`, `-DP`, `-TR`, `-FA`, `-G` e `-RE` sao
  armazenadas separadamente.
- A biblioteca passou a mostrar menor preco, fonte, horario da coleta e alerta
  para cache com mais de 30 horas.
- A escrita remota pelo cliente Flutter foi removida. O SQL local agora revoga
  escrita de `anon` e `authenticated`, mas a migracao nao pode ser aplicada
  remotamente sem acesso administrativo SQL ao projeto Supabase.
- Carga inicial da OP-16 executada: 159 registros gravados e confirmados por
  leitura publica. `OP16-001` ficou em R$ 0,19 e `OP16-001-AA` em R$ 168,99 na
  coleta de `2026-07-24T01:18:04Z`.
- Validacoes:
  - 4 testes Python do coletor;
  - 9 testes Node;
  - 48 testes Flutter;
  - `flutter analyze` sem problemas;
  - cobertura de 23,38%;
  - build web e seis fluxos E2E aprovados;
  - verificacao visual de `OP16-001-AA` em producao aprovada.
- Commit publicado: `9e36dfd` (`main`).
- Deploy Vercel de producao: `dpl_DVprUuQBUT56sH8tTNX13NM9Sahu`, alias
  `https://optcgbh.vercel.app`, estado READY.

### 23/07/2026 - Checkout da migracao SQL de precos

- O usuario informou que executou `sql/liga_card_price_cache.sql`.
- Leitura anonima de `OP16-001-AA` retornou HTTP 200.
- Foi criado um usuario temporario, autenticado e usado para tentar inserir uma
  linha exclusiva de teste em `liga_card_price_cache`.
- A insercao recebeu HTTP 403, confirmando que usuarios autenticados comuns nao
  possuem mais escrita.
- O usuario temporario foi removido e foi confirmado que nenhuma linha
  `SECURITY-CHECK-*` permaneceu no banco.
- O health check de producao retornou `ok` para funcao, configuracao e banco.
- A tela publica de `OP16-001-AA` retornou HTTP 200 e continuou exibindo
  `R$ 168,99`, sem falhas de rede.

### 23/07/2026 - Precos na Biblioteca, Colecao e correcao do carregamento

- Criado `lib/core/widgets/liga_price_display.dart`, com:
  - escopo de carregamento em lote para as listas;
  - rotulo compacto `Liga: R$ ...`;
  - painel de detalhes com menor preco, estado da sincronizacao e alerta de
    dado desatualizado.
- `LigaOnePieceService` ganhou leitura em lote do cache Supabase, em blocos de
  ate 80 codigos, preservando a identificacao exata de variantes.
- A pagina principal da Biblioteca passou a mostrar o menor preco da Liga em
  cada card. O detalhe da Biblioteca manteve o painel completo que ja existia.
- A Colecao passou a mostrar o preco nos modos grade e lista, e tambem no
  dialogo aberto ao clicar em uma carta.
- A tela de vendas agora consulta primeiro o cache compartilhado. Quando o
  preco ainda nao existe, solicita atualizacao em segundo plano e deixa de
  manter o dialogo preso em `Liga: consultando...`.
- O smoke E2E passou a incluir a rota publica da Biblioteca e salva a captura
  `artifacts/e2e/library-prices.png`.
- Validacoes locais:
  - `flutter analyze`: sem problemas;
  - 48 testes Flutter aprovados;
  - 9 testes Node/API aprovados;
  - build web oficial com variaveis publicas aprovado;
  - 6 fluxos publicos gerais e a rota da Biblioteca aprovados no Chrome;
  - captura visual confirmou precos reais na grade, incluindo `Liga: R$ 0,20`.
- Commit local: `5307f00` (`Show Liga prices across card collections`), ainda
  nao enviado ao remoto Git no momento deste registro.
- Deploy Vercel de producao:
  `dpl_FqYVcQEafVB3bqysuccLtuVPxux6`, estado READY, alias
  `https://optcgbh.vercel.app`.
- Pos-deploy aprovado: health HTTP 200, protecao de origem HTTP 403, sete
  fluxos publicos E2E (incluindo Biblioteca) e nenhum erro de runtime encontrado
  nos logs da implantacao.

### 23/07/2026 - Estado visual da verificacao e auditoria da automacao

- Biblioteca, Colecao e Vendas passaram a distinguir quatro estados:
  - verificando o cache;
  - verificada e atual, em verde;
  - verificada mas desatualizada, em amarelo;
  - ainda nao verificada, em cinza.
- Uma carta encontrada na pagina da edicao sem oferta passa a ser salva com
  precos nulos. Isso permite mostrar `verificada, sem oferta` sem confundir com
  uma carta nunca consultada.
- O detalhe da Biblioteca tambem distingue `nao verificada` de `verificada sem
  oferta` e mostra quando a verificacao ficou antiga.
- O workflow agora termina com erro quando as credenciais obrigatorias nao
  estiverem configuradas, em vez de registrar falso sucesso.
- Auditoria do GitHub Actions:
  - o workflow esta agendado e teve 29 execucoes;
  - a execucao #29, de 23/07/2026, terminou em apenas 9 segundos;
  - a anotacao confirmou que `SUPABASE_URL` e
    `SUPABASE_SERVICE_ROLE_KEY` nao estao configurados;
  - portanto, a atualizacao automatica ainda nao esta gravando precos e exige
    essa configuracao unica nos secrets do repositorio.
- Validacoes: `flutter analyze`, 48 testes Flutter, 5 testes Python, build web e
  E2E visual da Biblioteca aprovados. A captura confirmou os estados
  `desatualizado` e `nao verificada`.
- Commit da interface e auditoria: `7ff43d6`.
- Deploy Vercel de producao:
  `dpl_4xs1bqAeb81kjXo3QmjvTtAUvrxn`, READY no alias
  `https://optcgbh.vercel.app`.
- A rota da Biblioteca, health check e protecao de origem foram aprovados
  novamente em producao; os logs do deploy nao apresentaram erros.

### 23/07/2026 - Fallback para bloqueio 403 no catalogo de edicoes

- O teste manual do usuario confirmou que os secrets passaram pela validacao,
  mas o runner hospedado do GitHub recebeu HTTP 403 ao abrir a pagina publica
  que lista as edicoes da Liga.
- Foi criado `assets/liga_one_piece_editions.json`, com as 78 edicoes
  observadas, seus IDs, datas e grupos.
- Quando uma edicao especifica e solicitada, o coletor usa diretamente o
  catalogo versionado e nao consulta a pagina de edicoes bloqueada.
- Nas execucoes agendadas, o coletor ainda tenta descobrir edicoes novas pela
  pagina publica; em caso de bloqueio, continua com o catalogo local.
- A pagina individual da OP-16 permaneceu legivel a partir da maquina local e
  retornou 159 cartas/variantes.
- O esquema de tres rodadas diarias foi mantido:
  - 00:17, 08:17 e 16:17 em Brasilia;
  - 360 segundos entre paginas;
  - tres edicoes recentes em todas as rodadas;
  - edicoes antigas divididas em tres grupos, resultando em uma atualizacao
    diaria por edicao.
- Validacoes: 6 testes Python aprovados, `--edition OP-16 --dry-run` aprovado e
  leitura/parser da pagina individual OP-16 aprovados.
- Ainda e necessario testar a pagina individual a partir do runner do GitHub;
  se ela tambem responder 403, sera necessario um runner auto-hospedado ou um
  agendador local, pois o bloqueio sera do IP do datacenter.
- Commits `60fa2d4` e `a6e7d8e` enviados para `origin/main`.
- Diagnosticos disparados pela API do GitHub:
  - a primeira execucao foi cancelada porque aguardava 360 segundos antes da
    primeira pagina; isso foi corrigido sem remover os intervalos entre
    requisicoes;
  - a execucao `30060604795` usou o catalogo local, tentou somente OP-16 e
    recebeu HTTP 403 na pagina individual;
  - portanto, a Liga bloqueia o IP do runner hospedado do GitHub, e nao apenas a
    pagina de catalogo.
- Proxima solucao recomendada: runner auto-hospedado Windows instalado como
  servico na maquina/rede do usuario, ou agendador local. Isso e uma mudanca
  persistente no sistema e requer autorizacao explicita antes da instalacao.

### 23/07/2026 - Runner local e automacao de precos operacional

- O usuario autorizou a configuracao completa de um runner auto-hospedado.
- GitHub Actions Runner `v2.336.0` instalado em `C:\actions-runner`.
- Runner registrado no repositorio como `optcg-liga-lumiel`, Windows x64, com
  rotulo exclusivo `liga-price-cache`.
- A sessao nao estava elevada; por isso o runner nao foi instalado como servico
  do Windows. Em vez disso:
  - `C:\actions-runner\start-hidden.ps1` inicia o runner sem janela e evita
    processos duplicados;
  - a entrada HKCU `OPTCGLigaPriceRunner` inicia o script automaticamente no
    login deste usuario;
  - o computador precisa estar ligado e este usuario precisa ter feito login.
- O workflow foi convertido para PowerShell e direcionado somente a
  `[self-hosted, Windows, X64, liga-price-cache]`.
- Permissoes do workflow foram limitadas a `contents: read`; os gatilhos
  continuam somente manual e agenda.
- Agenda mantida em 00:17, 08:17 e 16:17 (Brasilia), com tres grupos e 360
  segundos entre paginas. Isso atualiza as edicoes antigas uma vez ao dia e as
  tres mais recentes em todas as rodadas.
- Commit do workflow: `59c3820`, enviado para `origin/main`.
- Validacao real:
  - runner apareceu online e executou o job `update-cache`;
  - run GitHub `30060885093` terminou com sucesso;
  - OP-16 retornou 159 cartas/variantes;
  - Supabase foi atualizado com 159 linhas em
    `2026-07-24T02:10:29Z`;
  - leitura publica confirmou os novos horarios e valores.
- Qualidade completa aprovada antes da publicacao: 6 testes Python, 9 testes
  Node, 48 testes Flutter e `flutter analyze` sem problemas.

### 23/07/2026 - Tela administrativa do monitor de precos

- Criada a rota protegida `/admin/liga-prices`, acessivel apenas para usuarios
  autenticados com o claim `app_metadata.is_weekly_admin`.
- Administradores veem um novo atalho `Monitor de precos` no Hub One Piece.
- A tela combina as 78 edicoes do catalogo
  `assets/liga_one_piece_editions.json` com todos os registros salvos em
  `liga_card_price_cache`.
- A leitura do Supabase e paginada em blocos de 1.000 linhas para nao truncar
  o resultado no limite padrao da API.
- Para cada edicao a tela mostra:
  - quantidade de cartas verificadas;
  - quantidade com menor preco disponivel;
  - cobertura visual por barra de progresso;
  - data e hora local da ultima atualizacao;
  - estado `Atualizada`, `Parcial`, `Atrasada` ou `Nunca atualizada`.
- Uma edicao e considerada atual quando todos os registros foram resolvidos
  nas ultimas 30 horas. Se somente parte das linhas for recente, fica
  `Parcial`; se nenhuma linha recente existir, fica `Atrasada`.
- Foram adicionados busca por sigla, filtros por estado, totais resumidos e
  botao de recarga.
- A protecao existe tanto no roteador quanto na propria tela; usuarios sem
  sessao sao enviados ao login e usuarios sem claim administrativo voltam ao
  Hub One Piece.
- Validacoes aprovadas: build web release, E2E da home, E2E da protecao da rota
  administrativa, `flutter analyze` e 50 testes Flutter.
- Commit funcional `bae5c09`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_D4j7VF5eeY7WWEhakP8BxgxazzUc`, status READY no alias
  `https://optcgbh.vercel.app`.
- A home e a protecao da rota administrativa foram aprovadas novamente em
  producao; a consulta de logs do novo deploy nao encontrou erros.

### 23/07/2026 - Auditoria da primeira atualizacao automatica completa

- A consulta foi feita as 23:30 (Brasilia), pouco depois da instalacao do
  runner local.
- O unico job executado pelo novo runner ate esse momento foi o teste manual
  da OP-16, entre 23:09 e 23:10. Por isso a OP-16 era a unica edicao recente
  no monitor administrativo.
- Nenhuma rodada automatica da nova agenda havia ocorrido ainda. A primeira
  esta prevista para 24/07/2026 as 00:17 (03:17 UTC).
- Agenda confirmada:
  - 00:17: grupo 0;
  - 08:17: grupo 1;
  - 16:17: grupo 2.
- Os tres grupos foram validados em `--dry-run`: cada rodada seleciona 28
  edicoes, sendo as 3 mais recentes em todas as rodadas e 25 antigas por
  grupo. A uniao cobre as 78 edicoes do catalogo.
- Com intervalo de 360 segundos, cada rodada gasta no minimo 162 minutos em
  espera entre paginas, mais o tempo das requisicoes. O limite do job e 210
  minutos, deixando aproximadamente 48 minutos para rede e gravacao.
- O runner estava ativo no PID 21088, conectado desde 23:07:54, e a entrada
  `HKCU\...\Run\OPTCGLigaPriceRunner` estava configurada para reinicia-lo
  automaticamente no proximo login.
- Restricao operacional: como o runner nao e um servico do Windows, o
  computador precisa permanecer ligado, sem suspensao, e com este usuario
  conectado durante toda a rodada. Se isso nao ocorrer, o job fica aguardando
  o runner ou e interrompido.
- Estado do Supabase na auditoria: 640 linhas em 28 siglas historicas; somente
  OP-16 possuia uma importacao completa e recente, com 159 linhas resolvidas
  em `2026-07-24T02:10:29Z`.
