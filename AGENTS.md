# Memoria de continuidade do TCG BH

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

- Aplicativo Flutter chamado publicamente de **TCG BH** desde 28/07/2026.
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

### 23/07/2026 - Catalogo completo a cada 30 segundos

- Por solicitacao do usuario, o intervalo entre edicoes foi reduzido de 360
  para 30 segundos.
- Os grupos foram removidos do workflow. Cada uma das tres execucoes diarias
  agora percorre as 78 edicoes em sequencia, na ordem do catalogo.
- O comando automatico usa `--shard-count 1 --shard-index 0`,
  `--priority-editions 0` e `--delay 30`.
- O tempo minimo de espera do catalogo completo passa a ser aproximadamente
  39 minutos, mais o tempo das requisicoes e gravacoes.
- O limite do job foi reduzido de 210 para 120 minutos.
- O intervalo padrao do script tambem passou a ser 30 segundos, mantendo
  execucoes manuais e automaticas consistentes.
- O `--dry-run` confirmou exatamente 78 edicoes selecionadas e os 6 testes
  Python foram aprovados.
- Observacao: a Liga declara `Crawl-delay: 360` no `robots.txt`; usar 30
  segundos foi uma decisao explicita do usuario e pode aumentar o risco de
  bloqueio temporario da origem.

### 23/07/2026 - Horarios redondos para a atualizacao de precos

- A agenda do GitHub Actions foi ajustada para executar todos os dias as
  00:00, 08:00 e 16:00 no horario de Brasilia.
- Os crons correspondentes em UTC sao `0 3 * * *`, `0 11 * * *` e
  `0 19 * * *`.
- Cada horario continua percorrendo as 78 edicoes em sequencia, com intervalo
  de 30 segundos entre paginas.

### 24/07/2026 - Primeira carga completa e correcao de codigos repetidos

- A carga manual `30062088626` percorreu as 78 edicoes em aproximadamente 40
  minutos e a Liga respondeu normalmente.
- A EB-04 ainda nao possui cartas publicadas na pagina e retornou uma lista
  vazia.
- A gravacao inicial falhou antes do primeiro lote com HTTP 500 porque cartas
  reimpressas aparecem em mais de uma edicao com o mesmo `lookup_code`, chave
  primaria de `liga_card_price_cache`.
- O coletor passou a consolidar os registros antes do upsert, mantendo a
  primeira ocorrencia do codigo. Como o catalogo vem do mais recente para o
  mais antigo, a edicao mais recente tem prioridade.
- Edicoes sem nenhuma carta publicada agora geram aviso e nao fazem o job
  inteiro falhar.
- `PYTHONUNBUFFERED=1` foi adicionado ao workflow para que o progresso por
  edicao apareca no GitHub Actions em tempo real.
- Foi adicionado um teste de regressao para codigos repetidos; os 7 testes
  Python foram aprovados.
- A carga corrigida `30063945621`, no commit `15c44f3`, terminou com sucesso
  as 00:59:51 de 24/07/2026.
- Resultado confirmado diretamente no Supabase:
  - 78 paginas de edicao consultadas;
  - EB-04 ignorada por ainda nao possuir cartas publicadas;
  - 5.315 codigos unicos consolidados e gravados;
  - 5.315 registros com menor preco e horario recente da nova execucao;
  - 62 siglas permanecem nos registros finais porque edicoes auxiliares e
    reimpressoes que so repetem codigos sao consolidadas sob a edicao mais
    recente.

### 24/07/2026 - Valor total da colecao pelos precos da Liga

- O cabecalho da aba `Colecao` passou a mostrar o indicador `Valor pela Liga`.
- O total multiplica o menor preco salvo no cache da Liga pela quantidade
  possuida de cada carta e soma toda a colecao propria.
- Cartas cadastradas em decks nao entram na conta, evitando somar novamente
  itens que ja pertencem a colecao.
- O valor considera a colecao inteira, independentemente de busca, favoritos
  ou filtros visuais ativos.
- O indicador mostra a cobertura no formato `X/Y com preco`; cartas sem
  verificacao ou sem oferta nao entram no total e aparecem como pendentes no
  tooltip.
- O carregamento reutiliza a consulta em lote do `LigaPriceScope`, sem fazer
  uma requisicao individual adicional para cada carta.
- Foi criada uma funcao pura de calculo e dois testes cobrindo quantidade,
  cartas sem preco e valores ausentes.
- Validacoes aprovadas: `flutter analyze`, 52 testes Flutter e build web
  release.
- Commit funcional `2fa7e58`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_6qgTLtSzXkD2oinWnmZWGkqTPyH6`, status READY no alias
  `https://optcgbh.vercel.app`.
- A home foi validada novamente em producao e a consulta de logs do novo
  deploy nao encontrou erros.

### 24/07/2026 - Envio de cartas da colecao para vendas

- As cartas da aba `Colecao` passaram a oferecer a acao
  `Adicionar as vendas` na grade, na lista e no dialogo de detalhes.
- A acao copia a quantidade escolhida para `Cartas a venda` sem remover a
  carta da colecao.
- O dialogo informa quantas copias ainda podem ser anunciadas e impede que a
  soma em vendas ultrapasse a quantidade possuida.
- Quando a mesma carta e variante ja existe em vendas, a quantidade e
  incrementada no registro existente, preservando preco, condicao, status e
  demais configuracoes do anuncio.
- A confirmacao oferece o atalho `Abrir vendas` para configurar e ativar o
  anuncio.
- A regra de montagem do registro foi isolada em
  `lib/features/collection/collection_sale_import.dart`.
- Foram adicionados tres testes cobrindo nova entrada, incremento sem
  duplicacao e bloqueio de quantidade excedente.
- Validacoes aprovadas: `flutter analyze`, 55 testes Flutter e build web
  release.
- Commit funcional `b29a25b`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_7PzDESykhWgSiEHLB3jCjAd2iKkG`, status READY no alias
  `https://optcgbh.vercel.app`.
- O dominio de producao respondeu HTTP 200, carregou o bootstrap do Flutter e
  a consulta de logs do novo deploy nao encontrou erros.

### 24/07/2026 - Diagnostico das edicoes Release Event

- A investigacao confirmou que `OP-15-RE` foi descoberta e consultada
  normalmente na carga completa: a pagina foi a quinta de 78 e retornou 90
  cartas e variantes.
- Essas linhas nao aparecem como `OP-15-RE` no cache porque a tabela usa
  `lookup_code` como chave unica e o coletor consolida codigos repetidos antes
  do upsert, preservando a primeira ocorrencia.
- Como `OP-15` e processada antes de `OP-15-RE` e as cartas Release Event
  reutilizam os codigos das cartas normais, as linhas auxiliares sao
  absorvidas pela edicao principal.
- Consulta direta ao Supabase em 24/07/2026: `OP-15` com 204 registros,
  `OP-15-RE` com zero, `OP-14-RE` com zero e `OP-12-RE` com zero.
- O problema afeta estruturalmente edicoes auxiliares que reutilizam codigos,
  e nao a agenda ou a requisicao da pagina da Liga.
- Uma correcao segura exigira identificar precos por carta e variante/edicao,
  migrar a chave unica do cache e ajustar a correspondencia da aplicacao; nao
  basta mudar a ordem de coleta, pois isso apenas substituiria o preco normal
  pelo Release Event.

### 24/07/2026 - Correcao das edicoes auxiliares de preco

- A colisao foi corrigida sem uma migracao destrutiva da tabela: edicoes
  principais continuam usando `lookup_code` normal e edicoes auxiliares usam
  a chave de armazenamento `<codigo>@<edicao>`.
- Exemplo: a carta normal permanece `OP15-001`, enquanto a Release Event fica
  `OP15-001@OP-15-RE`; `card_code` continua sendo `OP15-001` nas duas linhas.
- O coletor passa a preservar simultaneamente a carta principal e cada versao
  auxiliar durante a consolidacao e o upsert.
- A aplicacao passou a consultar candidatos pelo `card_code` real e escolher
  a variante por imagem exata, nome indicando Pre-Release/Release Event ou,
  sem indicacao de variante, manter a edicao principal.
- As consultas em lote por `card_code` paginam respostas acima de 1.000
  linhas, evitando perder variantes quando muitos codigos sao carregados
  simultaneamente.
- A imagem da carta agora acompanha as referencias de preco na biblioteca,
  colecao, valor total e dialogo de detalhes.
- A atualizacao direcionada de `OP-15-RE` foi executada localmente e gravou 90
  linhas no Supabase; consulta posterior confirmou 90/90 registros com menor
  preco.
- Foram adicionados testes de regressao para chave auxiliar, sobrevivencia da
  edicao principal e auxiliar no mesmo upsert e selecao correta de variante.
- Validacoes aprovadas: 9 testes Python, `flutter analyze`, 58 testes Flutter
  e build web release.
- A carga inicial das 21 edicoes auxiliares foi executada em sequencia com 30
  segundos entre paginas e terminou sem falhas.
- O Supabase foi atualizado com 1.198 linhas auxiliares. A conferencia por
  sigla encontrou 1.198/1.198 registros esperados e nenhuma divergencia;
  `OP-15-RE` ficou com 90/90 e `OP-14-RE` com 89/89.
- Commit funcional `7fc923c` e endurecimento da paginacao `c13983c`, ambos
  enviados para `origin/main`.
- Deploy Vercel final de producao
  `dpl_C6gNoApvbfJMRTb3rwR7tXo1pkuB`, status READY no alias
  `https://optcgbh.vercel.app`.

### 24/07/2026 - Planejamento da pagina de produtos personalizados

- O usuario forneceu `Deck Box One Piece.3mf` e duas fotos da deck box
  impressa, separada e montada.
- O arquivo foi validado como projeto Bambu Studio 2.7 completo, com unidade
  em milimetros, seis placas, geometria preservada e todas as malhas
  `manifold`.
- As seis placas/grupos de personalizacao identificados sao:
  1. base inferior com encaixes (`Ultimate_Bottom`);
  2. berco interno para cartas (`Ultimate_Insert_Long`);
  3. oito marcadores, duas copias de Freeze, Negate, Used e Blocker;
  4. corpo externo (`Ultimate_Box_Long`);
  5. bandeja/tampa dos marcadores (`Ultimate_Lid_Tokens`);
  6. quatro suportes altos e quatro baixos, agrupados na placa `Montagem`.
- Dimensoes principais aproximadas:
  - corpo externo: 90,4 x 79,4 x 111 mm;
  - berco interno: 76 x 64 x 99 mm;
  - base inferior: 80,4 x 79,4 x 20,9 mm;
  - tampa dos marcadores: 81,55 x 79,4 x 15 mm;
  - marcadores: 31,6 x 14,8 x 3 mm cada;
  - suportes: secao de 13 x 13 mm, alturas de 30 e 11,5 mm.
- O projeto possui quatro filamentos configurados: amarelo `#F6DA5A`, preto
  `#000000`, vermelho `#C52C18` e azul-claro `#A4DAE6`.
- Os marcadores sao internamente bicolores: corpo no extrusor 1 e
  simbolos/letras no extrusor 2. Deve ser decidido se o cliente escolhe as
  duas cores ou apenas a cor-base.
- O 3MF preserva uma disposicao explodida, nao as coordenadas finais
  encaixadas. A montagem web precisara ser reconstruida a partir das malhas,
  dimensoes e fotos.
- Direcao recomendada para o configurador: um GLB com malhas nomeadas,
  visualizacao 3D com rotacao/zoom, selecao das cores por grupo e alternancia
  entre os modos `Montada` e `Explodida`.

### 24/07/2026 - Revisao do modelo e paleta da deck box

- O usuario atualizou `Deck Box One Piece.3mf`, separando a antiga placa
  `Montagem` em duas placas. O projeto agora possui sete placas.
- As novas placas mostram quatro bases altas, com 30 mm, e quatro bases
  baixas, com 11,5 mm. No metadata ambas ainda aparecem como `Montagem`; no
  configurador serao tratadas provisoriamente como `Bases altas` e
  `Bases baixas`.
- A placa das fichas passou a exibir corretamente duas cores: uma para o corpo
  e outra para contorno, linha e escrita.
- Com a separacao nova, o configurador tera oito seletores:
  1. base inferior;
  2. berco interno;
  3. corpo/base das fichas;
  4. linhas e escrita das fichas;
  5. corpo externo;
  6. tampa/bandeja das fichas;
  7. bases altas;
  8. bases baixas.
- Paleta comercial informada pelo usuario: Preto, Branco, Verde, Amarelo,
  Azul, Azul Claro, Vermelho, Roxo, Laranja, Marrom e Rosa.
- Os valores hexadecimais usados na visualizacao ainda devem ser definidos
  como aproximacoes da cor real dos filamentos ou fornecidos conforme
  marca/material usados na impressao.

### 24/07/2026 - Primeira versao da pagina de produtos

- Foi criada a rota publica `/products`, acessivel pelo novo card `Produtos
  personalizados` no hub One Piece.
- A pagina apresenta a Deck Box One Piece com as duas fotos reais fornecidas,
  uma secao para a futura caixa de bulk em MDF e chamada para producao local
  sob encomenda.
- O configurador possui os oito controles definidos no modelo atualizado:
  corpo externo, berco interno, base inferior, tampa/bandeja, bases altas,
  bases baixas, base das fichas e detalhes das fichas.
- A paleta foi cadastrada com aproximacoes visuais para Preto, Branco, Verde,
  Amarelo, Azul, Azul claro, Vermelho, Roxo, Laranja, Marrom e Rosa. A pagina
  avisa que luz, tela e lote do filamento podem mudar a percepcao da cor.
- A previa ilustrativa responde imediatamente as escolhas, permite alterar o
  angulo e alternar entre `Montada` e `Pecas`. Ela representa os grupos
  separados do 3MF sem depender de carregamento externo.
- O cliente pode copiar a configuracao completa ou compartilhar o texto pelo
  WhatsApp; valor e prazo permanecem para confirmacao no atendimento.
- As fotos foram adicionadas em `assets/products/deck_box/` e os metadados da
  rota foram registrados no HTML web.
- A verificacao permanente ganhou o fluxo `products`, com capturas para
  desktop e celular. Tambem foram adicionados testes de widget para os oito
  seletores e para a troca de visualizacao.
- Validacoes locais aprovadas nesta etapa: `flutter analyze`, suite Flutter,
  build web com variaveis publicas e E2E da rota sem erros de console ou de
  pagina.
- A implementacao foi registrada no commit `c0472d5` e enviada para
  `origin/main`.
- Deploy Vercel de producao
  `dpl_GrFCHNPVvLEXPgAX5rwex7UAtCzE`, status READY e publicado no alias
  `https://optcgbh.vercel.app`.
- A verificacao E2E posterior ao deploy confirmou HTTP 200, titulo correto,
  primeiro frame renderizado e ausencia de erros de console/pagina em
  `https://optcgbh.vercel.app/#/products`.

### 24/07/2026 - Vista das pecas baseada no 3MF original

- A previa desenhada da deck box montada foi removida do configurador a pedido
  do usuario; a interface nao possui mais alternancia `Montada`/`Pecas` nem
  controle de angulo.
- As imagens `Metadata/plate_1.png` ate `Metadata/plate_7.png` foram extraidas
  diretamente do `Deck Box One Piece.3mf` atualizado e adicionadas em
  `assets/products/deck_box/model_parts/`.
- A vista agora exibe os renders originais das sete placas: base inferior,
  berco interno, fichas, corpo externo, tampa/bandeja, bases altas e bases
  baixas.
- O render original das fichas foi separado em duas camadas transparentes,
  preservando forma, sombra, linha e escrita para permitir a escolha
  independente da cor do corpo e da cor dos detalhes.
- Foi adicionado `tool/build_deck_box_preview_assets.dart` para reproduzir a
  copia das placas e a separacao das duas camadas das fichas a partir do
  diretorio `Metadata` extraido do projeto.
- A recoloracao usa a luminosidade dos renders originais. Assim, encaixes,
  recortes e relevos permanecem visiveis em todas as cores; os tons continuam
  identificados como aproximacoes visuais dos filamentos.
- Validacoes aprovadas: 60 testes Flutter, `flutter analyze`, build web com
  variaveis publicas e E2E local/produçao da rota de produtos.
- Commit funcional `1804732`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_DicH6VP7w6gTzTJE68meY81NY7Z6`, status READY no alias
  `https://optcgbh.vercel.app`.

### 24/07/2026 - Correcao da recoloracao das pecas 3MF

- Foi identificado que os previews do Bambu Studio possuíam um fundo escuro
  opaco e que o modo de mistura anterior recoloria toda a imagem.
- O gerador de assets agora remove apenas o fundo conectado ao contorno,
  mantendo escrita escura, sombras, furos e recortes internos das geometrias.
- Cada peça e cada camada das fichas e convertida para uma mascara de
  luminosidade com transparencia real.
- A interface passou a usar `BlendMode.modulate`, aplicando a cor somente nos
  pixels da peça e preservando o painel de fundo da pagina.
- Foi adicionado teste de regressao que decodifica os nove PNGs, confirma
  transparencia no fundo e valida a troca do corpo externo para vermelho.
- Validacoes aprovadas: 62 testes Flutter, `flutter analyze`, build web e E2E
  visual local sem erros.
- Commit funcional `de6d231`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_2pMtRx67icRyKcW4jBnJLbNwRp5Q`, status READY no alias
  `https://optcgbh.vercel.app`; o E2E posterior ao deploy passou sem erros.

### 24/07/2026 - Correcao da segunda cor das fichas

- A cor escolhida em `Detalhes das fichas` chegava ao widget correto, mas a
  mascara de escrita/linha quase nao continha pixels porque a separacao usava
  apenas saturacao.
- A separacao agora identifica a base amarela pelo dominio combinado dos
  canais vermelho/verde sobre o azul. Pixels neutros e escuros da escrita,
  contorno e linha passam integralmente para a camada de detalhes.
- Os assets `plate_3_body.png` e `plate_3_detail.png` foram regenerados; a
  segunda camada agora mostra claramente os nomes e contornos das oito fichas.
- O teste de assets exige mais de 500 pixels opacos na camada de detalhes, e
  um novo teste de widget escolhe `Azul claro` e confirma que essa cor foi
  aplicada especificamente em `model-part-plate-3-detail`.
- Validacoes aprovadas: testes dedicados da pagina, `flutter analyze`, build
  web e E2E local da rota de produtos.
- Suite final com 63 testes Flutter aprovada.
- Commit funcional `2708f99`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_A283SH7dRFTwjBrzhwov6R3wPvEq`, status READY no alias
  `https://optcgbh.vercel.app`; o E2E posterior ao deploy passou sem erros.

### 24/07/2026 - Cores deterministicas nos modelos e fichas

- A gravacao `Gravacao de Tela 2026-07-24 040407.mp4` confirmou que
  `BlendMode.modulate` escurecia ou deslocava alguns tons e que a escrita fina
  das fichas permanecia branca em vez de acompanhar o ultimo seletor.
- O filtro de cor em tempo real foi removido completamente da visualizacao.
- O gerador passa a criar uma variante PNG pronta para cada uma das onze cores
  e para cada vista usada pela pagina. Corpo e detalhes das fichas continuam
  sendo gerados em arquivos independentes.
- Os nomes dos assets usam chaves estaveis como `plate_4_vermelho.png`,
  `plate_3_body_rosa.png` e `plate_3_detail_azul_claro.png`.
- Cada variante usa exatamente o RGB exibido no seletor na area iluminada e
  apenas escurece o mesmo tom nas sombras; pixels quase transparentes nao
  participam mais da normalizacao da luminosidade.
- A pagina agora troca diretamente o arquivo da variante, eliminando
  diferencas de composicao entre navegadores e garantindo a segunda cor nas
  letras, linhas e contornos.
- Os 108 previews ocupam aproximadamente 1,52 MB no total.
- O teste de regressao abre as onze variantes dos detalhes e confirma que cada
  uma contem exatamente o RGB solicitado, alem de validar os nomes dos assets
  escolhidos apos as interacoes.
- Validacoes desta etapa: testes dedicados aprovados, `flutter analyze`, build
  web e E2E local sem erros ou assets ausentes.
- Suite final com 64 testes Flutter aprovada.
- Commit funcional `5a6cbbe`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_BUvR39QHgCFEYorpGWbStNSrbqsg`, status READY no alias
  `https://optcgbh.vercel.app`; o E2E posterior ao deploy passou sem erros.

### 24/07/2026 - Preco e pedido direto da Deck Box

- A Deck Box personalizada passou a exibir o preco fixo de `R$ 80,00` por
  unidade na area `Sua configuracao`.
- Foi adicionado um seletor de quantidade com calculo imediato do valor total.
- O botao principal agora usa o texto `Fazer pedido no WhatsApp` e abre uma
  conversa direta com o numero informado pelo usuario, normalizado como
  `+55 31 99353-3860` (`5531993533860` no link `wa.me`).
- A mensagem do pedido inclui todas as cores escolhidas, quantidade, valor
  unitario e valor total.
- A composicao do link foi isolada em uma funcao testavel. Os testes confirmam
  o destino, a preservacao da mensagem e a atualizacao do total de `R$ 80,00`
  para `R$ 160,00` ao selecionar duas unidades.
- O bloco de preco e quantidade usa quebra responsiva para evitar estouro
  horizontal em larguras intermediarias.
- Validacoes aprovadas: 66 testes Flutter, `flutter analyze`, build web e E2E
  local e de producao da rota de produtos.
- Commit funcional `be09a09`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_3MxCzMCPUSQ4CUpTGtXtY5eJrxsV`, status READY no alias
  `https://optcgbh.vercel.app`; o E2E posterior ao deploy passou sem erros.

### 24/07/2026 - Calibracao neutra e cache das cores 3D

- O relato de que `Branco` ainda aparecia amarelo foi reproduzido e
  investigado comparando o PNG local com o arquivo entregue pela producao.
- A geracao atual ja neutralizava a imagem original em escala de cinza antes
  de aplicar o RGB do filamento. O arquivo publicado estava correto, mas
  variantes antigas continuavam reutilizadas pelo cache do navegador porque
  as versoes corrigidas mantiveram os mesmos nomes.
- Todas as variantes foram regeneradas diretamente das sete placas contidas
  no `Deck Box One Piece.3mf`, sem usar a pasta `Downloads/Metadata`
  desatualizada que continha somente tres placas.
- Os novos arquivos usam o sufixo versionado `calibrated_v2`, forcando o
  navegador a baixar as imagens corrigidas em vez de reutilizar o cache.
- O branco foi ajustado para o RGB neutro `#F2F2F2`, sem diferenca entre os
  canais vermelho, verde e azul.
- Um teste de regressao agora abre as 88 combinacoes efetivamente exibidas
  (oito camadas/pecas por onze cores) e exige que cada PNG contenha exatamente
  o RGB configurado.
- A troca de `Tampa e bandeja` para `Branco` foi validada no navegador e a
  captura confirmou a geometria branca, sem amarelo residual.
- Validacoes aprovadas: 67 testes Flutter, `flutter analyze`, build web, E2E
  local/producao e verificacao visual em producao selecionando `Branco`.
- Commit funcional `977c0fc`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_13hoBAQesiNYrWY7TkTJUJX6E35C`, status READY no alias
  `https://optcgbh.vercel.app`.

### 25/07/2026 - Precos nas grades da biblioteca e colecao

- O preco da Liga aparecia corretamente no detalhe da carta, mas as grades da
  biblioteca e da colecao mostravam `Liga: nao verificada`.
- A consulta em lote ao Supabase foi confirmada com respostas `200` e dados
  validos. A falha estava na selecao local: havia candidatos para todas as
  referencias, mas o primeiro candidato podia ser descartado na compilacao web
  por depender somente do valor sentinela usado na pontuacao.
- O seletor agora aceita explicitamente o primeiro candidato quando ainda nao
  existe melhor resultado e depois compara pontuacao e data normalmente.
- O carregamento em lote passou a indexar tanto `card_code` quanto
  `lookup_code`, deduplicar candidatos e registrar aliases pela referencia
  exata da imagem, codigo de variante e codigo base da carta.
- O componente visual prioriza a referencia exata da imagem e usa os aliases
  somente como fallback. Isso mantem a biblioteca e a colecao alinhadas com o
  preco resolvido no detalhe da carta.
- Falhas isoladas de consulta ou conversao agora sao enviadas ao
  `AppErrorReporter`; os fallbacks locais de memoria, Hive e assets continuam
  disponiveis sem criar uma requisicao remota por carta.
- Foram adicionados testes de regressao para a referencia exata, para a troca
  de URL da imagem e para o fallback pelo codigo base.
- Validacoes locais aprovadas: 70 testes Flutter, `flutter analyze`, build web,
  E2E da biblioteca e conferencia visual com dados reais do Supabase. A grade
  voltou a exibir os valores da Liga.
- Commit funcional `8405789`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_FmL5z7eGrkp2jSR8pBVcm56tfVYs`, status READY no alias
  `https://optcgbh.vercel.app`.
- O E2E posterior ao deploy passou e a conferencia visual em producao confirmou
  os precos e o estado `verificada` diretamente nos cartoes da biblioteca.

### 25/07/2026 - Atualizacao automatica do PWA apos correcoes

- Uma captura do usuario ainda mostrava todos os cartoes como
  `Liga: nao verificada`, apesar de o build novo funcionar em uma sessao sem
  cache.
- O deploy estava READY e os arquivos do Vercel tinham o `ETag` e a data do
  build correto. A causa foi o worker `optcg-shell-v4`: para arquivos comuns,
  inclusive `main.dart.js`, ele devolvia o cache antigo primeiro e atualizava
  apenas em segundo plano.
- O worker `optcg-shell-v5` passou a usar rede primeiro para navegacoes,
  bootstrap, JavaScript principal, manifesto de assets e versao do Flutter,
  mantendo o cache somente como fallback offline.
- O registro do worker usa `updateViaCache: none` e solicita uma verificacao de
  atualizacao depois do primeiro frame.
- A chave de limpeza foi alterada para
  `2026-07-25-liga-price-grid-v1`, removendo uma unica vez os workers e caches
  antigos antes de carregar o Flutter para visitantes que ja usavam o site.
- Vercel recebeu `no-store` explicito para HTML e arquivos executaveis sem hash.
- A regressao foi reproduzida localmente criando `optcg-shell-v4` e a chave de
  reset anterior. Depois do reload, restou somente `optcg-shell-v5`, a chave
  nova foi gravada, o worker controlou a pagina e os precos continuaram
  visiveis.
- Validacoes aprovadas: 70 testes Flutter, `flutter analyze`, build web e
  conferencia visual da biblioteca com dados reais.
- Commit funcional `71f02c5`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_ETXqxr3fDayrrx7hKrMTjkuy7fuA`, status READY no alias
  `https://optcgbh.vercel.app`.
- Em producao, `main.dart.js`, `flutter_bootstrap.js` e o worker responderam
  com `no-store`; o E2E passou. Uma sessao preparada com o cache v4 foi
  migrada para v5 no reload e a captura final confirmou os precos visiveis.

### 25/07/2026 - Estabilidade da colecao no Safari do iPhone

- O video `WhatsApp Video 2026-07-25 at 21.27.43.mp4` mostrou o processo WebKit
  encerrando durante o scroll: na primeira queda o Safari recarregava a pagina
  e, na segunda, exibia `Um problema ocorreu repetidamente`.
- Nao havia erro Flutter ou Vercel no horario. A colecao combinava
  `SingleChildScrollView`, grids/listas com `shrinkWrap`, imagens como elementos
  HTML sobre CanvasKit e um `RepaintBoundary` por carta. Assim, todas as cartas
  permaneciam renderizadas durante o scroll.
- A tela passou a usar um unico `CustomScrollView`, com cabecalho em
  `SliverToBoxAdapter` e conteudo em `SliverGrid` ou `SliverList`. Cartas fora
  da area proxima ao viewport agora podem ser descartadas pelo Flutter.
- As camadas extras por carta foram removidas do delegate do grid.
- As imagens da colecao limitam a largura decodificada conforme tela e
  densidade, com teto de 720 pixels. A estrategia web mudou de elemento HTML
  obrigatorio para fallback, usando-o apenas quando o host bloqueia a
  renderizacao direta.
- Foram adicionados testes de regressao para a arquitetura virtualizada e para
  a politica de imagens.
- Validacoes locais aprovadas: 72 testes Flutter, `flutter analyze`, build web
  e abertura da colecao em viewport movel sem erros de console.
- Commit funcional `9066f2f`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_8LabgzYFhFzs6626ghsSipSvsSL2`, status READY no alias
  `https://optcgbh.vercel.app`.
- O `main.dart.js` novo foi confirmado pelo ETag de producao e a rota da
  colecao abriu em viewport de celular sem erros de console. A sessao de teste
  nao possui as cartas privadas do usuario; a confirmacao final no WebKit com
  as 15 cartas depende de novo teste no iPhone autenticado.

### 28/07/2026 - TCG BH, produtos globais e auditoria dos catalogos

- A marca publica foi alterada de `OPTCG BH` para `TCG BH` no aplicativo,
  metadados web, manifesto PWA, compartilhamentos e testes. Identificadores
  internos e o dominio `optcgbh.vercel.app` foram preservados para evitar
  quebra de cache, links e infraestrutura.
- Produtos Personalizados deixou o hub One Piece e passou a ter um destaque
  proprio na pagina principal de selecao dos TCGs. O botao Voltar da pagina de
  produtos agora retorna para `/home`.
- A auditoria em navegador real confirmou respostas HTTP 200 e listas
  renderizadas para os seis catalogos:
  - One Piece: OPTCG API, 5.105 registros brutos;
  - Pokemon: Pokemon TCG API v2, 20.479;
  - Digimon: Heroicc, 5.608;
  - Magic: Scryfall, primeira pagina carregada e paginacao ativa;
  - Riftbound: Riftcodex, 1.451;
  - Yu-Gi-Oh: YGOPRODeck v7, 14.476.
- A Pokemon TCG API bloqueou clientes de terminal com Cloudflare em parte dos
  testes, mas respondeu normalmente ao navegador da aplicacao. Deve ser
  monitorada e migrada para proxy com cache apenas se o problema passar a
  atingir usuarios.
- Os portais de edicoes da Liga para One Piece, Pokemon, Magic, Yu-Gi-Oh,
  Digimon e Riftbound responderam HTTP 200 com navegacao de edicoes.
- `docs/multi-tcg-liga-pricing-plan.md` registra a proposta de cache unificado,
  aliases de catalogo, adaptadores de variantes, agendamento, monitoramento,
  ordem de implantacao e criterios de qualidade para levar precos da Liga aos
  demais TCGs.
- Validacoes locais aprovadas: `flutter analyze`, 74 testes Flutter, 9 testes
  Node das APIs, build web, E2E da home e E2E de Produtos em desktop/celular.
- Commit funcional `0d269e6`, enviado para `origin/main`.
- Deploy Vercel de producao
  `dpl_EGQhTXwqvoAzCVCHmjGFQrNonN1k`, status READY e publicado no alias
  `https://optcgbh.vercel.app`.
- A verificacao posterior ao deploy confirmou os titulos `TCG BH`, as rotas
  home/Produtos, API de saude, protecao de origem e Supabase operacionais. O
  release reportado por `/api/health` foi `0d269e68bfc2`.

### 28/07/2026 - Dominio tcgbh e primeiros precos Pokemon

- O projeto Vercel foi renomeado de `optcg_manager` para `tcgbh`.
- `https://tcgbh.vercel.app` foi cadastrado como dominio verificado do projeto,
  portanto acompanha automaticamente os proximos deploys de producao.
- `optcgbh.vercel.app` continua ativo por compatibilidade, mas canonical,
  sitemap, robots, metadados, health check e E2E passaram a usar `tcgbh`.
- Foi criado `scripts/update_liga_tcg_price_cache.py`, coletor compartilhado
  para Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh. As chaves possuem
  namespace por jogo para conviver com o cache One Piece atual.
- Pokemon foi o primeiro TCG ativado. A edicao `PBL` foi importada manualmente
  com 120/120 linhas; a leitura posterior no Supabase confirmou todas as
  linhas e seus menores precos.
- A biblioteca Pokemon exibe o menor preco e estado da verificacao na grade e
  no detalhe. O catalogo Pokemon ganhou ate tres tentativas para respostas 429
  e 5xx, pois a API apresentou falhas intermitentes.
- O workflow `Update Liga price cache` aceita selecao manual entre One Piece e
  Pokemon. Nas agendas de 00:00, 08:00 e 16:00, Pokemon atualiza sempre as tres
  edicoes recentes e percorre o historico em 12 shards automaticos, preservando
  o intervalo de 30 segundos.
- O GitHub reconheceu o workflow atualizado como `active`. O ambiente local
  nao possui o executavel `gh`, por isso o disparo manual do workflow nao foi
  feito pela CLI; a importacao inicial foi executada diretamente e validada.
- Validacoes aprovadas: 78 testes Flutter, 9 testes Node, 2 testes Python,
  `flutter analyze`, build web, verificacao visual da grade/detalhe Pokemon,
  E2E da home e de Produtos.
- Commit funcional `0078aee`, enviado para `origin/main`.
- Deploy Vercel `dpl_4xiHKVfzVFXKtWKq7xFKhj3FiH1v`, status READY. O health
  check em `https://tcgbh.vercel.app` reportou release `0078aee7db7d`, banco e
  configuracao operacionais.

### 28/07/2026 - Retorno correto em cada TCG

- A causa do retorno indevido da biblioteca Pokemon para One Piece era o
  fallback implicito `/home/one-piece` do `HomeNavigationButton`. O problema
  aparecia principalmente ao abrir ou recarregar uma rota direta, quando nao
  havia historico interno para desempilhar.
- O botao compartilhado agora exige `destinationRoute` e sempre navega para o
  pai semantico declarado pela pagina. Nao existe mais fallback global para
  One Piece nem dependencia de `context.canPop()`.
- Bibliotecas Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh retornam para seus
  respectivos hubs. A biblioteca e os recursos de One Piece retornam ao hub
  One Piece; telas globais retornam ao seletor de TCGs.
- Detalhes e comparacao retornam para a biblioteca One Piece. Importacoes
  retornam para Colecao ou Vendas de acordo com o destino recebido na rota.
- Login, cadastro, perfil e links publicos retornam para a home global.
- O E2E passou a validar o clique real de retorno em rotas abertas diretamente,
  incluindo as seis bibliotecas, Produtos, Semanais e autenticacao.
- Validacoes aprovadas: `flutter analyze`, 80 testes Flutter, build web e 14
  fluxos E2E tanto localmente quanto em producao.
- Commit funcional `ddcd46f`, enviado para `origin/main`.
- Deploy Vercel `dpl_8X8aamFqThDnZTcDq275j1wpNGhC`, status READY e aliases
  `https://tcgbh.vercel.app` e `https://optcgbh.vercel.app`.
- O health check de producao reportou release `ddcd46f19378`, configuracao e
  banco operacionais. A varredura de logs nao encontrou erros no novo deploy.
