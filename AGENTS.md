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

### 28/07/2026 - Carga integral dos precos Pokemon em andamento

- A Liga Pokemon publicou 781 edicoes ja lancadas entre os grupos principal e
  auxiliar. Antes desta carga, o Supabase possuia somente PBL, com 120 linhas.
- A importacao integral foi iniciada localmente em segundo plano pelo processo
  `65012`, usando `scripts/update_liga_tcg_price_cache.py`, shard unico e
  intervalo de 30 segundos entre edicoes.
- Saida e erros podem ser acompanhados em `pokemon_full_import.out.log` e
  `pokemon_full_import.err.log`; esses arquivos operacionais sao ignorados pelo
  Git.
- As tres primeiras edicoes foram gravadas sem erro: PBL (120), M5 (118) e CRI
  (122). A leitura posterior do banco confirmou 360 linhas Pokemon.
- A previsao da carga completa e de aproximadamente 6h30 a 7h, desde que o
  computador e o processo permaneçam ligados. O coletor continua depois de
  falhas isoladas e apresenta a lista consolidada no final.
- O workflow agendado continua cobrindo Pokemon em 12 shards, portanto tambem
  funciona como recuperacao gradual caso a execucao local seja interrompida.

### 28/07/2026 - Fundacao da expansao funcional multi-TCG

- O inventario confirmou que Colecao, Decks, Vendas, Marketplace, Procurados,
  Scanner e importacoes ainda dependem de `OpCard`; bibliotecas e parte dos
  precos ja possuem adaptadores por jogo.
- `docs/multi-tcg-feature-expansion.md` registra a matriz de capacidades,
  arquitetura, ordem de implantacao e criterios de conclusao.
- Foi criado o registro tipado dos seis jogos e de sete formatos iniciais:
  One Piece Construido, Pokemon Padrao, Digimon Construido, Magic Standard,
  Magic Commander, Riftbound Construido e Yu-Gi-Oh Advanced.
- O validador comum entende zonas separadas, quantidades, limites por nome ou
  numero, excecoes de recursos basicos, identidade de cor/dominio e snapshots
  dinamicos de cartas restritas.
- As configuracoes seguem as fontes oficiais atuais. Regras mutaveis como
  rotacao e banimentos foram deixadas fora do binario e devem ser carregadas
  como snapshots com vigencia.
- `sql/multi_tcg_foundation.sql` prepara `game_slug`, identidade de catalogo,
  variante, formato e zona em Colecao, Decks e Procurados. A migracao e
  aditiva; registros existentes recebem `one-piece`.
- A proxima fase funcional e Colecao Pokemon, seguida por Digimon, Yu-Gi-Oh,
  Riftbound e Magic. A migracao SQL precisa ser aplicada antes de o aplicativo
  passar a consultar as novas colunas.
- Validacoes aprovadas: `flutter analyze` e 87 testes Flutter.
- Durante esta etapa, a carga Pokemon permaneceu ativa e alcancou 40/781
  edicoes sem interrupcao do processo `65012`.

### 28/07/2026 - Primeira colecao multi-TCG: Pokemon

- O usuario executou `sql/multi_tcg_foundation.sql`. A leitura posterior pelo
  Supabase confirmou as novas colunas de jogo, catalogo, variante, formato e
  zona em Colecao, Decks e Procurados.
- Foi criado um modelo e repositorio de colecao genericos por TCG. Os registros
  Pokemon usam `game_slug = pokemon`, `catalog_card_id` e `variant_id`, sem
  alterar nem misturar a colecao One Piece existente.
- A biblioteca Pokemon ganhou um botao de inclusao na grade e no detalhe da
  carta. Novas inclusoes incrementam a quantidade da mesma impressao em vez de
  criar duplicatas.
- O hub Pokemon agora oferece a rota `/pokemon/collection`. A tela mostra
  cartas diferentes, quantidade total, menor preco individual da Liga e valor
  total estimado, multiplicando preco pela quantidade.
- A quantidade pode ser aumentada, reduzida ou removida pelo detalhe da carta.
  Visitantes recebem a orientacao para entrar; usuarios autenticados leem e
  gravam somente a propria colecao pelas politicas do Supabase.
- Metadados web e E2E passaram a cobrir o hub, a biblioteca e a colecao
  Pokemon. Validacoes aprovadas: `flutter analyze`, 89 testes Flutter no total,
  build web com variaveis publicas e verificacao no navegador local e em
  producao.
- Commit funcional `d82f676`, enviado para `origin/main`.
- Deploy Vercel `dpl_44BwrLBPmndXbLzbXWzS45Aqg5J2`, status READY e publicado
  em `https://tcgbh.vercel.app`. Health check, protecao de origem e tres fluxos
  Pokemon passaram em producao; a varredura da ultima hora nao encontrou erros
  de runtime.
- A carga integral Pokemon continuou ativa no processo `65012` durante toda a
  entrega e havia alcancado 81/781 edicoes sem erros no ultimo acompanhamento.
- Proxima expansao recomendada: reutilizar essa mesma colecao generica em
  Digimon, Yu-Gi-Oh, Riftbound e Magic, adicionando antes o adaptador de
  identidade/preco de cada catalogo.

### 28/07/2026 - Colecoes habilitadas em todos os TCGs

- A colecao generica foi expandida para Digimon, Magic, Riftbound e Yu-Gi-Oh.
  Cada hub ganhou uma rota `/[jogo]/collection`, isolada por `game_slug`, e
  cada biblioteca permite adicionar cartas pela grade ou pelo detalhe.
- Digimon usa o numero impresso completo, por exemplo
  `DIGIMON:BT14-001`. Magic e Riftbound usam sigla da edicao mais numero do
  colecionador. Esses formatos sao os mesmos produzidos pelo coletor da Liga.
- Yu-Gi-Oh recebeu tratamento especifico: como uma carta pode possuir muitas
  impressoes, o usuario escolhe a edicao antes de adicionar. A colecao grava o
  `set_code` como variante e consulta o preco daquela impressao, sem misturar
  raridades ou relancamentos.
- As bibliotecas Digimon, Magic e Riftbound exibem o estado/preco da Liga na
  grade e no detalhe. Enquanto uma edicao ainda nao estiver no cache, a
  interface informa que ela nao foi verificada.
- O workflow `Update Liga price cache` aceita disparo manual para os seis
  jogos e, nos horarios de 00:00, 08:00 e 16:00, percorre automaticamente
  Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh depois de One Piece.
- Os jobs multi-TCG usam `max-parallel: 1` e intervalo de 30 segundos. Pokemon
  e Digimon usam 12 shards; Magic e Yu-Gi-Oh usam 24; Riftbound usa 6. Assim,
  os sites nao recebem requisicoes simultaneas e cada job permanece abaixo do
  limite individual de duas horas.
- O GitHub reconheceu o workflow como `active` e o quality gate do commit
  concluiu com sucesso.
- Validacoes aprovadas: `flutter analyze`, 92 testes Flutter, build web e 12
  fluxos E2E locais e em producao cobrindo hubs, bibliotecas, botoes de
  inclusao, colecoes de visitante e navegacao de retorno.
- Commit funcional `a5a72fc`, enviado para `origin/main`.
- Deploy Vercel `dpl_13ZhrmTpQ9VxLcoceM2nRedPymAo`, status READY e publicado
  em `https://tcgbh.vercel.app`. Health check, protecao de origem e varredura
  de runtime passaram sem erros.
- A importacao inicial Pokemon permaneceu ativa no processo `65012` e havia
  alcancado 191/781 edicoes no ultimo acompanhamento.
- Proximas camadas: decks com validadores por formato, vendas/marketplace por
  jogo, procurados e importacao/scanner multi-TCG.

### 28/07/2026 - Construtor de decks multi-TCG

- Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh ganharam a rota
  `/[jogo]/decks` nos respectivos hubs. Os decks One Piece permanecem no fluxo
  antigo para preservar compatibilidade.
- O novo repositorio usa `game_slug`, `format_slug`, `catalog_card_id`,
  `variant_id` e `deck_zone` da migracao ja aplicada. Nenhum SQL adicional foi
  necessario.
- O usuario pode criar/excluir decks, escolher formato, adicionar cartas da
  propria colecao, ajustar quantidades e mover cartas entre zonas.
- Formatos ativados: Pokemon Padrao; Digimon Construido; Magic Standard e
  Commander; Riftbound Construido; Yu-Gi-Oh Advanced.
- O editor separa Main Deck, Digi-Eggs, Commander, recursos/runas, campeao,
  lenda, campos de batalha, Extra Deck e Side Deck conforme cada formato.
- A validacao mostra contagem por zona, limites basicos de copias, excecoes
  para recursos basicos, singleton de Commander, identidade de cor/dominio e
  nomes unicos de campos Riftbound.
- O editor deixa explicito que listas banidas/restritas com vigencia ainda nao
  foram sincronizadas. Assim, um deck nao e apresentado como plenamente legal
  usando uma lista possivelmente desatualizada.
- Magic passou a armazenar `color_identity` do Scryfall, em vez de apenas as
  cores impressas, para validar Commander corretamente.
- Validacoes aprovadas: `flutter analyze`, 94 testes Flutter, build web e 10
  fluxos E2E locais e em producao cobrindo os cinco hubs e as cinco rotas de
  decks para visitante.
- Commit funcional `7d23cc3`, enviado para `origin/main`.
- Deploy Vercel `dpl_5XPEopgCDoQGs7zvBZWpn9GriSMC`, status READY e publicado
  em `https://tcgbh.vercel.app`. Health check, protecao de origem e varredura
  de runtime passaram sem erros.
- A carga inicial Pokemon permaneceu ativa no processo `65012` e havia
  alcancado 236/781 edicoes no ultimo acompanhamento.
- Proxima camada recomendada: vendas e marketplace isolados por TCG, seguida
  por procurados e importacao/scanner.

### 28/07/2026 - Vendas e marketplaces multi-TCG

- Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh ganharam as rotas
  `/[jogo]/sales` e `/[jogo]/marketplace`. O fluxo antigo de One Piece foi
  preservado para evitar regressao nos anuncios existentes.
- Nenhum SQL adicional foi necessario: a fundacao multi-TCG ja havia
  adicionado `game_slug`, `catalog_card_id`, `variant_id` e o indice de
  marketplace por jogo em `collection_items`.
- A colecao de cada jogo agora possui a acao `Colocar uma a venda`. A
  importacao reaproveita a identidade exata da impressao e impede anunciar
  mais copias do que o usuario possui.
- A tela de vendas permite alterar quantidade, condicao, observacoes e status,
  escolher preco manual ou percentual sobre o menor preco da Liga e publicar
  ou renovar o anuncio por sete dias.
- A precificacao percentual suporta ajuste positivo ou negativo e
  arredondamento para cima, para baixo ou sem arredondar. Precos dinamicos
  vencidos ha mais de 24 horas sao recalculados ao abrir as vendas.
- A publicacao exige preco valido e WhatsApp cadastrado. Anuncios reservados,
  vendidos ou expirados deixam de aparecer automaticamente.
- Cada marketplace consulta apenas o `game_slug` correspondente, possui busca
  por carta, edicao ou vendedor e libera o contato protegido pelo WhatsApp
  somente depois do login.
- Os cinco hubs passaram a exibir Vendas e Marketplace como recursos ativos.
  Metadados web foram adicionados para as dez novas rotas.
- O utilitario E2E passou a aceitar varias ocorrencias de `--route`, permitindo
  validar um conjunto direcionado de telas em uma unica sessao do navegador.
- Validacoes aprovadas: `flutter analyze`, 97 testes Flutter, build web,
  verificacao visual e 15 fluxos E2E locais e em producao. Health check,
  protecao de origem e varredura de runtime tambem passaram.
- Commit funcional `6aaca3b`, enviado para `origin/main`.
- Deploy Vercel `dpl_84dF2zZcQM6aAyX25ZKrgRHEvkUn`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- A carga inicial Pokemon permaneceu ativa no processo `65012` e alcancou
  270/781 edicoes no ultimo acompanhamento.
- Proxima camada recomendada: procurados multi-TCG, seguida por
  importacao/scanner e compartilhamento de vitrines por jogo.

### 28/07/2026 - Cartas procuradas multi-TCG

- Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh ganharam a rota
  `/[jogo]/wanted`. O modulo antigo de procuradas One Piece foi preservado.
- Nenhum SQL adicional foi necessario: `wanted_cards` ja possuia
  `game_slug`, `catalog_card_id` e `variant_id` pela fundacao multi-TCG, alem
  das politicas de leitura publica e gravacao pelo proprietario.
- As bibliotecas agora exibem a acao `Adicionar as procuradas`. A mesma acao
  tambem aparece no detalhe das cartas da colecao.
- Cada procurada preserva a identidade exata da impressao. Yu-Gi-Oh exige a
  escolha da edicao antes da inclusao; os demais jogos reutilizam o mesmo
  codigo normalizado empregado no cache da Liga.
- Inclusoes repetidas incrementam a quantidade da busca existente, em vez de
  criarem registros duplicados.
- A tela possui as visoes Comunidade e Minhas procuradas, busca por carta,
  edicao ou jogador, quantidade total, edicao de quantidade e observacoes,
  pausa, privacidade e exclusao.
- O botao `Eu tenho` monta uma oferta com carta, quantidade e observacao e
  abre o WhatsApp do jogador. O telefone nao e incluido na consulta publica;
  ele e obtido pelo RPC protegido somente apos login.
- Cada usuario pode copiar um link publico isolado por TCG no formato
  `/shared/wanted/[jogo]/[usuario]`.
- Os cinco hubs passaram a mostrar Procuradas como recurso ativo e as cinco
  rotas receberam metadados web dedicados.
- Validacoes aprovadas: `flutter analyze`, 99 testes Flutter, build web,
  verificacao visual e 10 fluxos E2E locais e em producao. Health check,
  protecao de origem e varredura de runtime tambem passaram.
- Commit funcional `966641f`, enviado para `origin/main`.
- Deploy Vercel `dpl_9GeNbXwuaSDcrwtB79LD5eYf2rxn`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- A carga inicial Pokemon permaneceu ativa no processo `65012` e alcancou
  295/781 edicoes no ultimo acompanhamento.
- Proxima camada recomendada: importacao e scanner multi-TCG, seguida por
  compartilhamento de colecoes e vitrines filtradas por jogo.

### 28/07/2026 - Importacao e scanner assistido multi-TCG

- Pokemon, Digimon, Magic, Riftbound e Yu-Gi-Oh ganharam a rota
  `/[jogo]/import`, acessivel pelo novo card `Importar e escanear` nos cinco
  hubs.
- O fluxo aceita camera ou imagem, executa OCR no aparelho/navegador, extrai
  um nome ou codigo provavel conforme o TCG e consulta o catalogo correto.
- O usuario sempre confirma a carta e sua impressao antes de adicionar. O
  reconhecimento visual automatico por imagem continua exclusivo do One Piece,
  pois o modelo de referencias atual nao cobre os demais jogos.
- Tambem e possivel pesquisar diretamente por nome ou codigo, sem fornecer
  uma imagem.
- Cada resultado pode ser adicionado diretamente a colecao ou as procuradas,
  preservando `game_slug`, `catalog_card_id`, `variant_id`, edicao, raridade e
  imagem. Yu-Gi-Oh permite selecionar a impressao antes da inclusao.
- Nenhum SQL adicional foi necessario; o scanner reutiliza a fundacao
  multi-TCG e as tabelas ja migradas.
- As cinco APIs foram validadas por buscas reais no navegador: Pikachu,
  Agumon, Lightning Bolt, Ahri e Dark Magician. A API Pokemon apresentou uma
  resposta 500 temporaria, mas o retry existente recuperou a busca e devolveu
  30 resultados.
- Validacoes aprovadas: `flutter analyze`, 103 testes Flutter, build web,
  verificacao visual e 10 fluxos E2E locais e em producao. Health check,
  protecao de origem e varredura de runtime tambem passaram.
- Commit funcional `8eebd48`, enviado para `origin/main`.
- Deploy Vercel `dpl_6v3LvV48bLtTz33rpo2hyRVZz8b3`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- A carga inicial Pokemon concluiu as 781 edicoes e gravou inicialmente
  58.054 linhas. A unica falha, `LA`, foi reprocessada isoladamente com
  sucesso e adicionou 146 cartas. A verificacao direta no Supabase confirmou
  146 linhas `POKEMON:LA:*` e 58.200 linhas Pokemon no cache.
- Proxima camada recomendada: compartilhamento de colecoes e vitrines
  filtradas por TCG, seguida por importacao em lote por planilha.

### 29/07/2026 - Visual de decks One Piece

- O detalhe do deck na colecao deixou de usar uma lista compacta e passou a
  destacar o `Leader` principal em um cartao grande e centralizado.
- As demais cartas aparecem abaixo em uma grade visual com arte, nome, codigo
  e um selo sobre a imagem indicando `1x`, `2x`, `4x` e demais quantidades.
- Os controles de aumentar e diminuir copias foram preservados na visualizacao
  privada e agora atualizam imediatamente o estado exibido no dialogo.
- Listas antigas sem o tipo da carta salvo tentam identificar o lider pelo
  nome do deck e pela quantidade de uma copia. Quando nao existe identificacao
  segura, a interface informa que o lider precisa ser revisado.
- A mesma composicao foi aplicada ao deck compartilhado publicamente, com
  layout responsivo para desktop e celular.
- Validacoes aprovadas: `flutter analyze`, 106 testes Flutter, build web,
  verificacao visual local em desktop e celular e verificacao do deck publico
  real em producao. Health check, protecao de origem e varredura de runtime
  passaram sem erros.
- Commit funcional `844c347`, enviado para `origin/main`.
- Deploy Vercel `dpl_GjdaCJ5qMVggtYuxenXa6WMT1e8r`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Distribuicao de copias por arte no deck

- Cartas com duas ou mais copias no deck privado ganharam a acao
  `Distribuir artes`.
- O editor consulta todas as versoes do mesmo codigo na API One Piece e
  permite dividir a quantidade fixa entre arte normal, parallel, alternative
  art e demais impressoes. Exemplo validado: quatro copias de `EB03-055`
  divididas em `3x` normal e `1x` alternative art.
- O salvamento cria ou atualiza um registro por arte usando a imagem exata,
  sem alterar o total legal do codigo no deck. A soma precisa permanecer
  exatamente igual ao total anterior para o botao de salvar ser habilitado.
- Depois do salvamento, cada arte aparece como um cartao independente com seu
  proprio selo de quantidade. O deck compartilhado preserva a mesma
  composicao visual.
- Contagens de cartas diferentes passaram a agrupar pelo codigo, evitando que
  normal e alternative art sejam contabilizadas como cartas distintas.
- A exportacao da lista tambem agrega as artes pelo codigo; uma composicao
  `3x + 1x` continua sendo exportada como `4xEB03-055`.
- Nenhuma migracao SQL foi necessaria, pois `deck_items` ja aceitava registros
  separados com o mesmo codigo e imagens diferentes.
- Validacoes aprovadas: `flutter analyze`, 109 testes Flutter, build web,
  verificacao visual local e verificacao do deck publico em producao. Health
  check, protecao de origem e varredura de runtime passaram sem erros.
- Commit funcional `8e5dc05`, enviado para `origin/main`.
- Deploy Vercel `dpl_uNosaqskoRtvug866gF5BqEsHH48`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Valor total do deck pela Liga

- O cabecalho do deck privado e do deck compartilhado passou a mostrar o valor
  total estimado pela Liga.
- O calculo usa o menor preco da arte exata selecionada e multiplica pela
  quantidade daquela arte. Normal, parallel e alternative art do mesmo codigo
  podem contribuir com valores diferentes.
- Quando todas as copias possuem preco, a interface mostra
  `Valor total do deck` e a cobertura, por exemplo `51/51 copias com preco`.
- Quando alguma arte nao possui valor verificado, a interface deixa claro que
  se trata de `Valor parcial`, informa a cobertura e nao apresenta o resultado
  como um total completo.
- O deck publico real `Mihawk` foi usado na verificacao visual e retornou
  `R$ 4.578,24`, com `51/51` copias precificadas, em desktop e celular.
- Nenhuma migracao SQL foi necessaria; o recurso consulta o cache publico de
  precos da Liga ja existente.
- Validacoes aprovadas: `flutter analyze`, 110 testes Flutter, build web,
  verificacao visual local responsiva e verificacao em producao. Health check,
  protecao de origem e varredura de runtime passaram sem erros.
- Commit funcional `1e3313a`, enviado para `origin/main`.
- Deploy Vercel `dpl_Bnet8bduZotUNjwvms7Kf9Bw2FAy`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Preco individual nas cartas do deck

- Cada cartao do deck privado e compartilhado passou a mostrar o menor preco
  da Liga correspondente a arte exata selecionada.
- Quando existe mais de uma copia da mesma arte, o cartao mostra o valor
  unitario e o subtotal daquela arte no deck, por exemplo
  `R$ 4,60 cada • R$ 13,80 no deck`.
- Cartas sem valor deixam explicito se ainda nao possuem preco verificado ou
  se foram verificadas mas nao possuem oferta. Valores desatualizados mantem
  uma indicacao visual distinta.
- O tamanho dos cartoes foi ajustado para acomodar o preco sem sobrepor arte,
  nome, codigo ou controles, tanto em desktop quanto em celular.
- Nenhuma migracao SQL foi necessaria; a exibicao reutiliza o mesmo cache
  publico e o mesmo criterio por arte usados no total do deck.
- Validacoes aprovadas: `flutter analyze`, 110 testes Flutter, build web,
  verificacao visual local responsiva, verificacao do deck publico real em
  producao e quality gate do GitHub. Health check, protecao de origem,
  console do navegador e varredura de runtime passaram sem erros.
- Commit funcional `41c3670`, enviado para `origin/main`.
- Deploy Vercel `dpl_7u7naeR1Zsws6ujKL6vsPGAwLyos`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Catalogo completo de promocionais One Piece

- A edicao promocional `PC-01` ja fazia parte do catalogo de 78 edicoes, mas a
  API principal da biblioteca entregava somente 328 impressoes promocionais e
  nao representava todo o conteudo publicado pela Liga.
- A pagina `PC-01` da Liga foi coletada diretamente e confirmou 1.203 cartas e
  variantes. Todas foram atualizadas imediatamente no Supabase.
- O endereco abreviado `//arquivos/...` usado pela Liga passou a ser
  normalizado para `https://repositorio.sbrauble.com/arquivos/...`. As 1.203
  imagens foram verificadas no cache e uma requisicao real respondeu HTTP 200.
- O endpoint `/api/optcg-cards` agora combina as 5.105 impressoes da API
  One Piece com as 1.203 variantes de `PC-01`, totalizando 6.308 registros.
  A biblioteca identifica o conjunto como `Promotion Cards (PC-01)` e
  reaproveita cor, tipo, raridade, texto e atributo da carta-base quando
  disponiveis.
- A chave local do catalogo foi atualizada para que navegadores com cache
  antigo busquem a lista completa imediatamente apos a nova versao.
- Precos iguais a zero passaram a ser interpretados como ausencia de oferta,
  evitando exibir `R$ 0,00` como valor real. Das 1.203 variantes, 878 possuem
  preco e 325 aparecem corretamente como verificadas sem oferta.
- A biblioteca em producao mostrou 6.168 impressoes com imagem visivel; a
  diferenca para os 6.308 registros totais corresponde a registros antigos da
  API principal que nao possuem imagem. As 1.203 promocoes possuem imagem.
- Nenhuma migracao SQL foi necessaria.
- Validacoes aprovadas: 10 testes Python do coletor, 12 testes Node das APIs,
  `flutter analyze`, 110 testes Flutter, build web, E2E da biblioteca e
  verificacao visual real em producao. Quality gate do GitHub, console do
  navegador e varredura de runtime da Vercel passaram sem erros.
- Commits funcionais `58ea8ad` e `2acda87`, enviados para `origin/main`.
- Deploy Vercel `dpl_Bc2f5znrwo9ShSnSQhv36RmKWfeq`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Preco da Girl promocional no deck

- O registro antigo da carta `Girl (OP14 Release Event)` usa o codigo-base
  `P-096`, mas a Liga identifica essa impressao como `P-096-RE`. Por isso a
  consulta em lote do deck buscava apenas `P-096` e nao recebia a linha de
  preco, embora ela estivesse corretamente salva no Supabase.
- A resolucao de variantes agora converte nomes `Release Event` para o sufixo
  `-RE`. A variante `Release Event Winner` recebe `-RW`, evitando misturar o
  preco das duas artes.
- Codigos promocionais exatos com sufixos fora da lista antiga, como
  `P-096-RW`, passam a ser preservados sem duplicar o sufixo.
- A verificacao em producao confirmou `P-096` e `P-096-RE` por `R$ 35,95`,
  enquanto `P-096` Winner e `P-096-RW` mostram `R$ 289,00`.
- Decks existentes com o codigo-base nao precisam ser editados nem recriados;
  a compatibilidade e aplicada durante a consulta.
- Nenhuma migracao SQL ou nova coleta de precos foi necessaria.
- Validacoes aprovadas: `flutter analyze`, 112 testes Flutter, build web e
  verificacao visual da biblioteca real em producao. Quality gate do GitHub,
  console do navegador e varredura de runtime da Vercel passaram sem erros.
- Commit funcional `4b3e61a`, enviado para `origin/main`.
- Deploy Vercel `dpl_AJQrSjFV6BkC14vxunP3kiDfDH2h`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Precos completos e valor do deck Riftbound

- Todas as edicoes publicadas pela Liga Riftbound foram coletadas em sequencia:
  `OGN`, `OGS`, `OGN-PR`, `ROPP`, `SFD`, `UNL` e `VEN`.
- Vendetta foi incluida mesmo com lancamento marcado para 31/07/2026, pois a
  edicao e os precos ja estavam publicados. A rotina agendada do Riftbound
  agora tambem inclui futuras edicoes que a Liga ja tenha disponibilizado.
- O cache terminou com 1.426 cartas: 1.345 com oferta valida e 81 verificadas
  sem oferta. Nenhum registro permaneceu com preco zero.
- A integracao com o RiftCodex passou a preservar sufixos de variantes
  (`63A`, `7B`, etc.) a partir do `riftbound_id`, permitindo consultar o preco
  da impressao correta. Os conjuntos promocionais `OPP` e `PR` sao
  compatibilizados com as siglas `ROPP` e `OGN-PR` usadas pela Liga.
- No editor de decks Riftbound foi adicionado um painel com o valor total ou
  parcial do deck e a quantidade de copias cobertas pelo cache.
- Cada carta do deck mostra o menor preco individual da Liga. Quando ha mais
  de uma copia, tambem mostra o subtotal daquela variante no deck.
- Cartas sem cache e cartas verificadas sem oferta possuem respostas visuais
  distintas. Precos antigos continuam identificados como desatualizados.
- Nenhuma migracao SQL foi necessaria; nao havia registros Riftbound antigos
  nas tabelas de colecao que exigissem correcao de codigo.
- Validacoes aprovadas: quality gate completo, 115 testes Flutter, 14 testes
  Python, 12 testes Node, 29,13% de cobertura, analise estatica, build web,
  E2E da biblioteca e da area de decks em producao, verificacao visual real e
  varredura de runtime sem erros.
- Commits `597d7b8` e `06145c2`, enviados para `origin/main`; quality gate do
  GitHub concluido com sucesso.
- Deploy Vercel `dpl_C8VqG47QoVifBWpNUcaD96uNZzsW`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Importacao de listas de texto Riftbound

- Riftbound passou a aceitar listas de texto no formato usado pelo Piltover
  Archive, com as secoes `Legend`, `Champion`, `MainDeck`, `Battlefields`,
  `Runes` e `Sideboard`.
- O exemplo fornecido foi validado como uma lista legal de 64 cartas:
  1 Lenda, 1 Campeao escolhido, 39 cartas principais, 3 campos de batalha,
  12 runas e 8 cartas no sideboard.
- No editor de deck existe a acao `Montar deck por lista`. O usuario pode
  substituir todas as cartas atuais ou somar a lista ao deck existente.
- Na colecao existe a acao `Adicionar por lista de texto`. Quantidades de uma
  carta repetida em zonas diferentes sao somadas antes da gravacao.
- O importador aceita linhas `3 Charm` e `3x Charm`, agrega repeticoes na mesma
  zona, identifica secoes e mostra erros com o numero da linha.
- Antes de gravar, todos os nomes sao consultados no RiftCodex e o usuario
  revisa a impressao de cada carta. Edicoes regulares sao priorizadas, mas o
  seletor permite trocar para promocional, Starter, Metal, Overnumbered,
  Signature ou Alternative Art quando o catalogo oferece a variante.
- Virgulas e hifens nos nomes sao equivalentes durante a busca, permitindo
  importar `Master Yi, Tempered` mesmo quando o catalogo usa
  `Master Yi - Tempered`.
- Identificadores Signature do RiftCodex com `*` sao convertidos para o sufixo
  `S` usado pela Liga, preservando a consulta do preco da variante correta.
- O deck pode ser montado diretamente pela lista mesmo que as cartas ainda nao
  estejam cadastradas na colecao.
- Nenhuma migracao SQL foi necessaria.
- Validacoes aprovadas: `flutter analyze`, 121 testes Flutter, 14 testes
  Python, 12 testes Node, build web, teste responsivo do dialogo, E2E de
  biblioteca/colecao/decks em producao, quality gate do GitHub e varredura de
  runtime da Vercel sem erros.
- Commit funcional `18d3196`, enviado para `origin/main`.
- Deploy Vercel `dpl_By86nw8NNbyNYAtYzguamcGQgB5p`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Importacao direta de decks do Piltover Archive

- O dialogo de importacao Riftbound agora aceita diretamente o link publico de
  um deck do Piltover Archive, alem de manter a lista de texto como alternativa.
- A acao `Buscar` recupera o nome e a composicao do deck, preenche a lista e
  inicia automaticamente a revisao das impressoes antes de gravar no deck ou
  na colecao.
- Links encontrados na area de transferencia tambem sao reconhecidos
  automaticamente pela acao de colar.
- A integracao usa os endpoints publicos de deck e preco do Piltover Archive
  por meio de `/api/import-riftbound-deck`. O proxy aceita apenas HTTPS no
  dominio oficial, valida o UUID, possui limite de requisicoes, limite de
  resposta, timeout, protecao de origem e nao permite destinos arbitrarios.
- O deck real de validacao retornou 64 cartas: 1 Lenda, 1 Campeao, 39 cartas
  principais, 3 campos de batalha, 12 runas e 8 cartas no sideboard.
- Nenhuma migracao SQL ou nova variavel de ambiente foi necessaria.
- Validacoes aprovadas: `flutter analyze`, 122 testes Flutter, 15 testes Node,
  build web com variaveis publicas, consulta real ao Piltover Archive, quality
  gate do GitHub e cinco fluxos E2E em producao (home, hub, biblioteca,
  colecao e decks Riftbound). A API de producao e a varredura de runtime
  passaram sem erros.
- Commit funcional `8205620`, enviado para `origin/main`; quality gate do
  GitHub concluido com sucesso.
- Deploy Vercel `dpl_6mnsxpdQMcyfb8xammExxNqBcBcG`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Criacao direta de deck Riftbound por lista

- A tela `Decks Riftbound` agora oferece a acao visivel
  `Criar por lista ou link`, tanto no estado vazio quanto acima dos decks
  existentes e na barra superior.
- Nao e mais necessario criar e abrir um deck vazio antes da importacao. O
  usuario cola o link do Piltover Archive ou a lista de texto, revisa as
  impressoes e cria o deck completo no mesmo fluxo.
- Quando a origem e um link, o nome publicado no Piltover Archive preenche
  automaticamente o nome do novo deck e ainda pode ser editado pelo usuario.
- Depois da criacao, o aplicativo abre diretamente o editor do novo deck.
- Se a gravacao das cartas falhar depois da criacao do registro, o deck vazio
  e removido automaticamente para nao deixar dados incompletos.
- Nenhuma migracao SQL ou nova variavel de ambiente foi necessaria.
- Validacoes aprovadas: quality gate local, 123 testes Flutter, 14 testes
  Python, 15 testes Node, analise estatica, build web com variaveis publicas,
  consulta real de 64 cartas no Piltover Archive, E2E de home, hub e decks
  Riftbound em producao e varredura de runtime sem erros.
- Commit funcional `d76ac46`, enviado para `origin/main`; quality gate do
  GitHub concluido com sucesso.
- Deploy Vercel `dpl_HqirFoMY3phmvNJe5XQyx3KVev9H`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 29/07/2026 - Carga inicial completa dos precos multi-TCG

- Foi auditada a cobertura do cache da Liga pelo ID real de cada edicao, pois
  Yu-Gi-Oh reutiliza algumas siglas em IDs diferentes.
- Estado antes da nova carga:
  - Pokemon: 770 das 781 edicoes tinham registros; faltavam 11 IDs;
  - Digimon: 24 das 95 edicoes tinham registros; faltavam 71 IDs;
  - Magic: faltavam 1.314 dos 1.492 IDs publicados;
  - Riftbound: 7 de 7 edicoes completas;
  - Yu-Gi-Oh: faltavam 1.134 dos 1.234 IDs publicados.
- `update_liga_tcg_price_cache.py` ganhou `--missing-only`. O modo consulta o
  Supabase, identifica edicoes processadas pela anotacao `Liga ID` ou pelo
  `edid` da URL e permite retomar a carga sem repetir edicoes concluidas.
- Foi criado `scripts/start_liga_tcg_backfill.ps1`, que inicia um worker oculto
  por TCG, evita processos duplicados e salva PID e logs em
  `.cache/liga-tcg-backfill/`.
- Os workers usam UTF-8 para aceitar nomes historicos de Magic e Yu-Gi-Oh que
  nao podem ser impressos pelo console Windows CP-1252.
- A carga foi iniciada para Pokemon, Digimon, Magic e Yu-Gi-Oh com intervalo de
  30 segundos entre edicoes de cada dominio. Os quatro processos estavam
  ativos e sem erros apos as primeiras gravacoes. A estimativa inicial e de
  aproximadamente 11 horas, limitada pelas 1.314 edicoes pendentes de Magic.
- Primeira verificacao de progresso: 6 edicoes tentadas de Pokemon (todas sem
  cartas publicadas), 386 cartas de Digimon, 64 de Magic e 907 de Yu-Gi-Oh.
- A agenda existente das 00:00, 08:00 e 16:00 continua ativa e serve como
  recuperacao gradual caso a carga local seja interrompida. O computador deve
  permanecer ligado ate os workers terminarem.
- Validacoes aprovadas: quality gate completo, 123 testes Flutter, 16 testes
  Python, 15 testes Node, analise estatica e teste real de gravacao no
  Supabase.
- Commits funcionais `1385fee` e `b6632da`, enviados para `origin/main`.
- Esta etapa permanece em andamento ate a auditoria final confirmar todos os
  IDs processaveis e registrar separadamente as edicoes vazias da Liga.

### 31/07/2026 - Precos distintos por impressao dos lideres One Piece

- Foi corrigido o caso em que lideres comuns, Parallel e Alternate Art
  exibiam o mesmo preco.
- A causa era dupla: a Liga usa sufixos historicos diferentes conforme a
  edicao (`-AA`, `-PA`, `-PAR`, `-E`, `-A` e `-P`) e o cache remoto mantinha
  apenas uma linha canonica para codigos reutilizados por reimpressoes.
- O aplicativo agora consulta todos os sufixos conhecidos e seleciona a
  impressao pelo tipo pedido, imagem, nome e edicao original.
- O coletor passou a preservar tambem uma chave por edicao no formato
  `CODIGO@EDICAO`, sem remover a chave canonica usada pelas integracoes
  existentes.
- O cache persistido no navegador foi versionado de `v1` para `v2`, fazendo a
  interface descartar imediatamente os precos antigos sem afetar colecoes,
  decks ou dados do usuario.
- O Supabase foi atualizado imediatamente para `EB02`, `OP-09`, `OP-07`,
  `EB01`, `OP-05`, `OP-04`, `OP-02` e `OP-01`, totalizando 2.217 linhas.
- Validacao real no banco:
  - `OP02-001@OP-02` comum: R$ 9,99;
  - `OP02-001-E@OP-02` alternativa: R$ 698,75;
  - `OP01-001@OP-01` comum: R$ 84,92;
  - `OP01-001-PAR@OP-01` paralelo: R$ 4.990,00;
  - `EB01-001@EB01` comum: R$ 0,20;
  - `EB01-001-AA@EB01` alternativa: R$ 250,00.
- Validacoes aprovadas: quality gate completo com 126 testes Flutter antes da
  publicacao, analise estatica limpa, testes direcionados de variantes e
  avaliacao (14 testes), build web, quality gate do GitHub, E2E de home e
  biblioteca em producao, API e protecao de origem, e varredura de runtime da
  Vercel sem erros.
- Commits funcionais `7243c8b` e `6fb18ac`, enviados para `origin/main`.
- Deploy Vercel `dpl_4URp693ob6oJ7Hnur2mE7NJu5L1c`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 31/07/2026 - Pastas e simplificacao da colecao One Piece

- Foram removidas as acoes duplicadas de adicionar cartas no topo da colecao;
  a unica entrada permanece no botao flutuante inferior `Adicionar cartas`.
- O menu inferior foi reorganizado em tres fluxos:
  - `Importar carta pela biblioteca`, com busca automatica pelo codigo, imagem
    de referencia e escolha da variante;
  - `Adicionar por codigo`, para um ou mais codigos ou listas;
  - `Escanear com camera - Beta`, com aviso de que o resultado pode exigir
    revisao.
- A colecao agora possui pastas. O usuario pode criar, renomear, excluir,
  filtrar e mover cartas pelos detalhes da carta.
- Existem as visoes fixas `Todas as cartas` e `Sem pasta`. Cartas anteriores a
  migracao permanecem em `Sem pasta`.
- Cada pasta mostra cartas diferentes, quantidade total e valor calculado
  pelos menores precos encontrados na Liga.
- Excluir uma pasta nao exclui cartas: a chave estrangeira usa
  `on delete set null`, devolvendo-as para `Sem pasta`.
- Foi adicionada a tabela `collection_folders` e a coluna
  `collection_items.folder_id`, com RLS, indices, nome unico por usuario/TCG e
  validacao que impede associar uma carta a pasta de outro usuario ou TCG.
- A migracao `sql/collection_folders.sql` foi executada e validada no
  Supabase antes da publicacao.
- Validacoes aprovadas: quality gate local, 128 testes Flutter antes do teste
  final de interface, testes direcionados de pastas/valor/mobile, 16 testes
  Python, 15 testes Node, analise estatica, build web, E2E publico, verificacao
  do bundle de producao e varredura de runtime da Vercel sem erros.
- Commit funcional `74fafab`, enviado para `origin/main`.
- Deploy Vercel `dpl_9p2zDNQ3W5d1krswMJbpkjcBKh4j`, status READY e publicado
  em `https://tcgbh.vercel.app`.

### 31/07/2026 - Perfil do usuario

- Foi criada a rota autenticada `/profile`, acessivel pelo botao `Perfil`
  imediatamente antes de `Sair` tanto no seletor de TCGs quanto no hub One
  Piece.
- A tela permite editar nick/nome publico, telefone/WhatsApp e e-mail da
  conta, com confirmacao de troca de e-mail pelo Supabase.
- O usuario pode selecionar uma foto JPG, PNG ou WebP de ate 5 MB. O arquivo
  e enviado ao bucket publico `profile-avatars`, sempre dentro da pasta do
  proprio `auth.uid()`.
- A area de seguranca permite alterar a senha na sessao atual e solicitar
  recuperacao pelo e-mail autenticado.
- Recuperacao por telefone nao foi simulada com o WhatsApp informado no
  perfil: ela permanece identificada como indisponivel ate que um provedor
  SMS seja ativado e o telefone passe a ser verificado pelo Supabase Auth.
- A migracao `sql/profile_avatar_storage.sql` adiciona `profiles.avatar_url`,
  cria/configura o bucket e instala politicas de leitura, upload, alteracao e
  exclusao limitadas a pasta do usuario.
- A migracao `sql/profile_avatar_storage.sql` foi executada no Supabase. A
  coluna e o bucket foram validados pela API real, incluindo limite de 5 MB e
  os MIME types JPG, PNG e WebP.
- Validacoes aprovadas: quality gate completo, 132 testes Flutter, 16 testes
  Python, 15 testes Node, cobertura de 30,62%, analise estatica limpa e build
  web de producao.
- O teste autenticado real confirmou leitura e edicao do perfil sob RLS,
  upload e leitura publica da foto e troca de senha. A conta, o perfil e a
  imagem temporarios foram removidos ao final.
- Commit funcional `d3afebb`, enviado para `origin/main`.
- Deploy Vercel `dpl_YdeA2fLGFfpPGpy1ake6QaAUAXkS`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: bundle com a rota `/profile`, 49 fluxos publicos E2E
  aprovados e nenhuma ocorrencia nos erros de runtime da Vercel na ultima
  hora.

### 03/08/2026 - Novos circuitos semanais de Pokemon

- O semanal de Pokemon passou de dois para quatro rankings independentes:
  quinta-feira, sabado, MetaNaoPode e GLC (Gym Leader Challenge).
- MetaNaoPode e GLC acontecem no domingo, mas seus torneios, pontos,
  historicos, classificacoes e exportacoes CSV nunca se misturam.
- A importacao TDF agora pede que o administrador confirme o ranking do
  evento. Nomes contendo `MetaNaoPode`, `GLC` ou `Gym Leader Challenge` sao
  pre-identificados; um TDF generico de domingo exige escolha explicita.
- O circuito escolhido fica salvo em `report_data.weekly_circuit`, portanto
  nao foi necessaria migracao SQL. Relatorios antigos continuam compativeis e
  podem ser reimportados para receber a classificacao explicita.
- A pagina ganhou cards proprios para os quatro circuitos, com dia/formato,
  quantidade de torneios e identidade visual separada.
- Os arquivos de ranking usam os nomes
  `ranking_pokemon_meta-nao-pode.csv` e `ranking_pokemon_glc.csv`.
- Validacoes aprovadas: quality gate completo, 135 testes Flutter, 16 testes
  Python, 15 testes Node, cobertura de 30,96%, analise estatica limpa e build
  web de producao.
- Commit funcional `a58be5f`, enviado para `origin/main`.
- Deploy Vercel `dpl_9HXz96SvFKLSJcCVBGkDUaojmUbA`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: pagina Pokemon semanal e health check responderam 200, o
  bundle contem os quatro circuitos e o aviso de separacao dos domingos, e a
  Vercel nao registrou erros de runtime nos 30 minutos verificados.

### 04/08/2026 - Estrutura de privacidade e monetizacao

- Foram criadas as paginas publicas `/privacy`, `/cookies`, `/terms` e
  `/contact`, acessiveis mesmo antes do login e durante a conclusao do perfil.
- A pagina inicial agora possui um rodape publico com links legais e acesso
  permanente a `Gerenciar privacidade`.
- Novos visitantes recebem uma escolha versionada de consentimento, com
  opcoes para aceitar tudo, recusar itens opcionais ou configurar analise e
  anuncios personalizados separadamente.
- A preferencia fica salva localmente na caixa `app_prefs` do Hive e volta a
  ser solicitada se a versao da politica mudar.
- Nenhum anuncio, cookie publicitario ou rastreador foi ativado nesta etapa.
  O componente de espaco publicitario permanece invisivel ate receber
  conteudo aprovado, evitando espacos vazios na interface.
- Foi criado `web/ads.txt` apenas com comentarios. A linha do editor sera
  adicionada depois da aprovacao no AdSense, sem publicar um identificador
  ficticio.
- Nao foi necessaria migracao SQL.
- Validacoes aprovadas: quality gate completo, 138 testes Flutter, 16 testes
  Python, 15 testes Node, cobertura de 30,93%, analise estatica limpa e build
  web de producao.
- Commit funcional `91c8bae`, enviado para `origin/main`.
- Deploy Vercel `dpl_3Fn51WHBx3UVTUq1XUUuEPVjuWdR`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: `ads.txt` e health check responderam 200, a API confirmou a
  release `91c8bae340f8`, o bundle contem as quatro rotas legais e o controle
  de privacidade, nao contem `adsbygoogle`, e a Vercel nao registrou erros de
  runtime nos 30 minutos verificados.

### 07/08/2026 - Verificacao do Google AdSense

- A meta tag de propriedade fornecida pelo Google foi adicionada ao `head`
  publico: `google-adsense-account=ca-pub-3496425300816491`.
- A alteracao serve apenas para conectar e verificar o site no AdSense.
  Nenhum script de anuncios ou `adsbygoogle` foi ativado.
- O `ads.txt` continua sem uma linha de vendedor ate o Google fornecer ou
  confirmar a entrada oficial no painel.
- Validacoes aprovadas: teste direcionado de monetizacao, quality gate
  completo, 138 testes Flutter, 16 testes Python, 15 testes Node, cobertura
  de 30,93%, analise estatica limpa e build web de producao.
- Commit funcional `9ac4ce6`, enviado para `origin/main`.
- Deploy Vercel `dpl_Fj9mssW8nXRBiar3Wi7XfCA4dUrv`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: o HTML respondeu 200 e contem a meta tag exata, nao carrega
  `adsbygoogle.js`, o health check confirmou a release `9ac4ce633523` e a
  Vercel nao registrou erros de runtime nos 30 minutos verificados.

### 08/08/2026 - Venda em lote pelas pastas da colecao

- A area de pastas da colecao One Piece ganhou a acao `Vender esta pasta`;
  na visao `Todas as cartas`, a mesma acao aparece como
  `Vender toda a colecao`.
- Antes de executar, o usuario revisa o total e escolhe entre uma copia de
  cada variante ou todas as copias ainda disponiveis.
- O calculo desconta quantidades que ja estao em `Cartas a venda`, evita
  duplicar estoque e trata carta normal e arte alternativa separadamente pela
  combinacao de codigo e imagem.
- O usuario pode apenas preparar o lote em `Cartas a venda` ou publica-lo
  imediatamente no marketplace. A publicacao usa o WhatsApp do perfil,
  reativa somente os anuncios do lote e define validade de sete dias.
- Precos existentes sao preservados. Novos anuncios entram como `Sem preco`
  para posterior configuracao manual ou percentual da Liga.
- As inclusoes e atualizacoes sao enviadas em lote ao Supabase; publicacoes
  maiores sao divididas em grupos de 100 IDs.
- Nao foi necessaria migracao SQL.
- Validacoes aprovadas: quality gate completo, 142 testes Flutter, 16 testes
  Python, 15 testes Node, cobertura de 31,14%, analise estatica limpa e build
  web de producao.
- Commit funcional `db9cdfb`, enviado para `origin/main`.
- Deploy Vercel `dpl_8h3DTmVt1WzH7FfKqMe386izjrLy`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: o health check respondeu 200 e confirmou a release
  `db9cdfbf08ec`, o bundle contem a acao de vender pasta e a revisao para
  publicar no marketplace, e a Vercel nao registrou erros de runtime nos 30
  minutos verificados.

### 08/08/2026 - Reservas de estoque no marketplace

- O comprador agora escolhe a quantidade antes de reservar uma carta. No
  marketplace One Piece, o carrinho permite reservar varias cartas do mesmo
  vendedor em uma unica operacao; os demais TCGs reservam pelo anuncio.
- A reserva e transacional: o Supabase bloqueia os anuncios, valida o estoque
  e desconta as quantidades de forma atomica, sem permitir estoque negativo
  em compras concorrentes.
- Cada reserva dura 24 horas. O vendedor ve os pedidos pendentes em `Cartas a
  venda`, pode falar com o comprador pelo WhatsApp, confirmar a venda ou
  recusar e devolver o estoque.
- O comprador ganhou `Minhas reservas` em todos os marketplaces e pode
  cancelar um pedido pendente, restaurando o estoque imediatamente.
- Reservas vencidas sao restauradas por uma tarefa `pg_cron` a cada cinco
  minutos e tambem por verificacao oportunista nas operacoes do aplicativo.
- O banco preserva dados essenciais do pedido, aplica RLS para comprador e
  vendedor, exige WhatsApp no perfil e limita cada comprador a dez reservas
  pendentes.
- A migracao `sql/marketplace_inventory_reservations.sql` foi executada no
  Supabase. As duas tabelas e a RPC de expiracao responderam corretamente;
  nao havia reservas vencidas no momento da verificacao.
- Validacoes locais aprovadas: quality gate completo, 151 testes Flutter, 16
  testes Python, 15 testes Node, cobertura de 31,45%, analise estatica limpa
  e build web de producao. Depois dos ajustes finais de protecao, os nove
  testes direcionados e a analise estatica tambem passaram.
- Durante a publicacao, o audit remoto detectou tres avisos de alta severidade
  na dependencia transitiva `ip-address` 10.2.0. O lockfile foi atualizado
  para 10.4.0; `npm audit` voltou a zero vulnerabilidades e o quality gate
  completo foi repetido com sucesso.
- Commits funcionais `9462edf` e `e002b2d`, enviados para `origin/main`; o
  quality gate remoto do commit final terminou com sucesso.
- Deploy Vercel `dpl_EuqKA3hLeXfqYvFxhSg5AkAA4mYb`, status READY e publicado
  em `https://tcgbh.vercel.app`.
- Pos-publicacao: home e marketplace carregaram visualmente sem overlay de
  erro; o bundle contem as quatro acoes novas de reserva, o health check
  confirmou a release `e002b2d82d6c` e banco saudavel, e nao foram encontrados
  erros de runtime nos logs de producao consultados.

### 08/08/2026 - Inicio da auditoria segura de variantes da Liga

- A causa do preco incorreto da Manga `EB01-006` foi localizada: o nome Manga
  tambem contem `Alternate Art`, e o seletor anterior aceitava a linha `-AA`
  antes de distinguir o tipo especifico da impressao.
- Foi criada uma taxonomia explicita para cartas comuns, Alternate Art, Manga,
  Treasure Cup, Treasure Rare, Winner, participante, Pre-release, Release
  Event, Dash Pack, Full Art, Gold, SP, Parallel, Reprint e promocionais.
- Variantes especiais agora usam pareamento estrito. Quando duas impressoes da
  mesma categoria continuam empatadas, o aplicativo retorna `nao verificada`
  em vez de exibir um preco possivelmente incorreto.
- O cache local de precos One Piece foi versionado para `v3`, invalidando
  resultados antigos que possam ter sido associados a outra arte.
- A tela administrativa ganhou uma auditoria calculada a partir do catalogo e
  do cache da Liga: total de cartas, codigos com varias impressoes, cartas
  nesses codigos, maximo de variantes, pareamentos unicos, ambiguos, ausentes e
  contagem por categoria.
- Foi criado e executado `sql/liga_card_variant_mapping_audit.sql` para
  persistir os pareamentos confirmados, a confianca, o metodo de identificacao
  e o historico das auditorias.
- O script `scripts/audit_liga_one_piece_variant_mappings.py` filtra o cache
  compartilhado pelos prefixos One Piece, consolida chaves duplicadas e grava
  a carga de forma idempotente com a service role.
- Primeira auditoria persistida: 5.105 cartas do catalogo comparadas com 11.897
  linhas de preco One Piece; 4.237 correspondencias confirmadas, 224 ambiguas e
  644 ausentes. As 5.105 cartas resultaram em 5.094 chaves unicas.
- A Manga `EB01-006` foi confirmada como `EB01-006-MA@EB01`, confianca 98% e
  menor preco de R$ 13.000,00. A reimpressao `PRB` de R$ 5.700,00 e a Alternate
  Art comum de R$ 499,99 permanecem separadas.
- O aplicativo passou a consultar primeiro o mapeamento confirmado pelo par
  variante/imagem, inclusive nas consultas em lote. Biblioteca, vendas e
  marketplace agora enviam a imagem ao servico para preservar essa identidade.
- A tela administrativa usa o ultimo `liga_price_audit_runs` persistido e
  informa tambem data/hora e quantidade de linhas de preco auditadas.
- Validacoes direcionadas: 16 testes Flutter e 3 testes Python passaram; a
  analise estatica nao encontrou problemas. O quality gate completo e o build
  devem ser repetidos antes da publicacao.

### 09/08/2026 - Pastas independentes em Cartas a venda

- Foi preparada uma estrutura de pastas exclusiva para o estoque de vendas,
  sem misturar as pastas pessoais da colecao.
- A funcionalidade atende One Piece, Pokemon, Digimon, Magic, Riftbound e
  Yu-Gi-Oh sobre a tabela compartilhada `collection_items`.
- Cada tela de vendas permite criar, selecionar, renomear e excluir pastas. Os
  cards das pastas mostram anuncios diferentes, quantidade total e valor total
  anunciado.
- O editor de cada anuncio permite mover a carta para uma pasta ou devolve-la a
  `Sem pasta`. Excluir uma pasta nao remove anuncios; a chave estrangeira usa
  `on delete set null`.
- One Piece passou a filtrar explicitamente `game_slug = one-piece` nas
  consultas e operacoes de vitrine, evitando misturar anuncios de outros TCGs.
- A migracao `sql/sale_folders.sql` foi executada e validada: a tabela
  `sale_folders` e a coluna `collection_items.sale_folder_id` respondem pela
  API, nao havia pastas residuais e uma insercao anonima foi bloqueada com HTTP
  401 pelas politicas de acesso.
- Validacoes aprovadas: quality gate completo com 160 testes Flutter, 19 testes
  Python e 15 testes Node/API, analise estatica limpa e build web de producao.

### 09/08/2026 - Catalogo proprio One Piece

- A Liga passou a publicar OP-17 e os Starter Decks ST31 a ST36, elevando o
  catalogo de edicoes de 78 para 85 entradas. O fallback versionado foi
  atualizado com os novos IDs e datas.
- O job automatico de precos funcionou: ST31 a ST36 possuem 30 chaves de cache
  cada uma. A biblioteca continuava sem as cartas porque `allSTCards` da
  OPTCG API retornava zero registros desses decks.
- Foi pesquisada uma fonte alternativa. Limitless ja lista ST31 a ST36 e
  `one-piece.cards` lista os decks recentes, mas a solucao escolhida evita
  trocar uma dependencia externa por outra sem API publica estavel.
- A migracao `sql/one_piece_card_catalog.sql` cria o catalogo proprio do TCG BH.
  Ele guarda uma linha por impressao da Liga, incluindo edicao, codigo, nome,
  imagem, metadados de origem e campos reservados para enriquecimento futuro.
- `scripts/update_liga_edition_price_cache.py` agora atualiza precos e catalogo
  na mesma passagem. Se a tabela ainda nao existir, o preco continua sendo
  salvo e o script registra apenas um aviso sobre o catalogo.
- `/api/optcg-cards` mescla a OPTCG API com o catalogo proprio, elimina
  duplicatas e herda tipo, cor, raridade e texto de uma impressao conhecida
  quando o codigo ja existe na fonte antiga.
- O cache local de cartas foi alterado para `all_cards_v4`, forçando os
  navegadores a obter a nova lista depois do deploy.
- Antes da migracao, a tentativa de usar diretamente toda a tabela compartilhada
  de precos foi descartada: ela continha 237.930 linhas de varios TCGs e geraria
  uma resposta de aproximadamente 78 MB. A tabela dedicada mantem a consulta
  pequena e previsivel.
- Validacoes locais aprovadas: quality gate completo com 160 testes Flutter,
  20 testes Python e 18 testes Node/API, analise estatica limpa e build web de
  producao.
- A migracao foi executada no Supabase e a carga inicial gravou 90 variantes:
  15 por starter entre ST31 e ST36, sendo cinco codigos novos em cada edicao.
  Todas as 90 linhas possuem imagem. A mesclagem real retornou 5.195 cartas em
  aproximadamente 3,5 MB.
- Os nomes completos dos novos Starter Decks foram adicionados ao fallback e
  corrigidos diretamente nas 90 linhas da carga inicial.
- Commit funcional inicial `676b831`, enviado para `origin/main`. Deploy Vercel
  `dpl_CwgskDhqNbuN5VGmThEUdUgLQtBX` publicado como READY em
  `https://tcgbh.vercel.app`.
- A verificacao do endpoint em producao retornou 5.195 cartas e confirmou cinco
  codigos novos com imagem em cada uma das edicoes ST31, ST32, ST33, ST34,
  ST35 e ST36. Health check e banco responderam como saudaveis.

### 09/08/2026 - Carga antecipada parcial de OP-17

- A Liga ja publica parcialmente `OP-17 - The World's Strongest Warriors`, com
  lancamento previsto para o fim de agosto de 2026.
- A pagina da edicao continha 45 linhas. Destas, 34 impressoes tinham codigo e
  imagem validos, incluindo 30 codigos iniciados por `OP17-`; nenhuma possuia
  preco publico no momento da carga.
- O atualizador direcionado gravou 90 chaves no cache de precos, por manter as
  chaves geral e por edicao, e 34 variantes unicas no catalogo proprio.
- A verificacao de producao confirmou 34 linhas com imagem no Supabase e 30
  cartas OP17 visiveis em `/api/optcg-cards`. A resposta total passou de 5.195
  para 5.229 cartas sem exigir novo deploy.
- As futuras execucoes automaticas da edicao completarao o catalogo e os precos
  conforme a Liga publicar novas cartas e ofertas.

### 09/08/2026 - Correcao da busca OP17 apos carga parcial

- O usuario pesquisou `OP17` na biblioteca e recebeu zero resultados, embora o
  endpoint de producao ja retornasse 30 cartas OP17 com imagem.
- Os logs mostraram `GET /api/optcg-cards` com HTTP 200 e sem erro. O indicador
  `Mais filtros 1` representava apenas a propria consulta digitada, nao um filtro
  avancado adicional.
- A causa foi cache em duas camadas: o CDN mantinha o endpoint por seis horas e
  o Hive do navegador mantinha o catalogo por doze horas. `Ctrl + F5` nao limpa
  o armazenamento Hive, portanto o cliente continuava usando a lista anterior a
  carga de OP-17.
- O cache do endpoint foi reduzido para cinco minutos no CDN, com um minuto no
  navegador e revalidacao por 30 minutos. O cache Hive agora expira em 30
  minutos e sua chave mudou para `all_cards_v5`, forçando renovacao imediata.
- A busca tambem passou a comparar o codigo normalizado, aceitando formatos com
  ou sem hifen.
- Validacoes locais aprovadas: quality gate completo com 160 testes Flutter,
  20 testes Python e 18 testes Node/API, analise estatica limpa e build web de
  producao.

### 09/08/2026 - Filtro Azul e painel visual da biblioteca

- A lista de cores da Biblioteca One Piece passou a exibir explicitamente
  `Azul`, alem de `Multicolor`, junto das demais cores suportadas pelo jogo.
- Cada opcao de cor agora possui uma amostra visual propria; `Multicolor` usa
  um gradiente para deixar seu significado claro sem depender apenas do texto.
- O painel `Mais filtros` foi reorganizado em duas abas, `Cores` e `Detalhes`,
  com cabecalho explicativo, campos com icones e a acao principal
  `Ver resultados` sempre visivel.
- O contador de `Mais filtros` agora considera apenas filtros avancados. A
  busca digitada e o modo de favoritos nao inflam mais esse indicador.
- O botao `Limpar` redefine somente os filtros avancados, preservando a busca
  e a escolha de favoritos feita pelo usuario.
- A tela foi conferida visualmente em desktop e em viewport movel de 390 x 844,
  incluindo as duas abas, sem erros de pagina ou estouro de layout.

### 09/08/2026 - Catalogo OP17 preso no cache do navegador

- A API de producao foi validada nos dominios `tcgbh.vercel.app` e
  `optcgbh.vercel.app`: ambos retornavam 5.229 cartas e 30 codigos OP17 com
  imagem, sem erros nos logs da Vercel.
- Uma sessao limpa do navegador encontrou as 30 cartas, enquanto sessoes que
  ja possuíam o catalogo local continuavam exibindo zero resultados.
- A causa estava no comportamento stale-while-revalidate do `OpApiService`:
  o refresh atualizava a memoria e o Hive em segundo plano, mas a tela ja havia
  recebido uma copia da lista antiga e nao era reconstruida.
- O cache passou para `all_cards_v6`, com carimbo de data tambem versionado,
  evitando reaproveitar a validade de uma versao anterior do catalogo.
- Quando o cache vence, a biblioteca agora aguarda a atualizacao da API antes
  de devolver as cartas. Se a rede falhar, o ultimo catalogo valido continua
  sendo usado como fallback.
- A janela local foi alinhada ao cache do endpoint e reduzida para cinco
  minutos. Chaves antigas sao removidas depois da primeira gravacao v6.
- Como o navegador do usuario ainda manteve o bundle anterior sob controle do
  service worker, a estrategia Web foi endurecida: toda nova abertura consulta
  a API primeiro e usa o Hive apenas se a rede falhar.
- O endpoint Web recebeu um identificador de catalogo e requisicao `no-cache`.
  O shell PWA passou para `optcg-shell-v6` e o marcador do `index.html` foi
  alterado para desregistrar o worker e apagar os caches antigos uma vez.

### 09/08/2026 - Identificacao de cartas multicoloridas

- A API usa combinacoes como `Blue Purple`, `Green Red` e `Blue Yellow`; o
  filtro `Multicolor` procurava apenas a palavra literal `Multi` e, por isso,
  nao encontrava essas cartas.
- Foram identificadas 17 combinacoes multicoloridas no catalogo atual.
  Hannyabal `EB01-021`, em todas as tres artes, possui `Blue Purple` na origem.
- `OpCard` agora separa as seis cores oficiais, reconhece uma carta como
  multicolorida quando encontra duas ou mais cores e disponibiliza o nome
  localizado para exibicao.
- A biblioteca continua permitindo filtrar cada cor individual de uma carta
  multicolorida e o filtro `Multicolor` passa a inclui-la corretamente.
- Biblioteca, detalhes e comparador exibem combinacoes em portugues, como
  `Azul / Roxo`.

### 09/08/2026 - Duplicatas do catalogo, preco da colecao e busca por nome

- A API oficial e o catalogo derivado da Liga estavam publicando novamente a
  mesma impressao com URLs de imagem diferentes. Como a URL fazia parte da
  identidade anterior, a biblioteca exibia as duas copias.
- A mesclagem agora compara codigo base, nome normalizado da impressao, edicao
  e colecao. Artes validas de outras edicoes continuam separadas; os aliases
  `Manga` e `Parallel` tambem sao reconhecidos quando representam a mesma arte.
- Uma auditoria sobre a resposta de producao reduziu a simulacao de 11.791 para
  7.309 registros, removendo 4.482 copias de catalogo. `OP09-093` ficou com as
  oito impressoes reais: normal, alternate art, wanted poster, manga, gold,
  silver, reprint e aniversario.
- A mesclagem final passou a usar o resultado que ja inclui promocionais, em vez
  de recomecar pela lista bruta e descartar a etapa anterior.
- O preco da Alternate Art na colecao falhava porque `AA` e `Parallel` empatavam
  quando as imagens da API e da Liga tinham URLs diferentes. A variante de tipo
  exato agora vence uma variante apenas compativel, fazendo `OP09-093-AA`
  recuperar os R$ 229,99 armazenados no cache.
- `Importar carta pela biblioteca` passou a aceitar codigo ou nome. A busca por
  nome mostra os resultados com codigo, imagem, edicao e raridade para o usuario
  selecionar a impressao correta antes de adicionar.
- O identificador do endpoint Web foi atualizado para `catalog=v7`, impedindo
  que navegadores reutilizem a resposta duplicada em cache.

### 09/08/2026 - Aviso ao importar cartas para vendas

- O aviso exibido depois de importar uma pasta ou carta da colecao para vendas
  permanecia indefinidamente porque o Flutter define `persist = true` por
  padrao sempre que um `SnackBar` possui uma acao.
- Os dois fluxos agora usam o mesmo helper, com encerramento automatico apos
  cinco segundos e substituicao segura de qualquer aviso anterior.
- A acao `ABRIR VENDAS` captura o roteador antes da mudanca de tela, remove o
  aviso imediatamente e navega para `/sales`, sem depender de um `BuildContext`
  que pode ter sido desmontado.
- Testes direcionados da colecao e da importacao para vendas foram aprovados,
  junto da analise estatica sem alertas.

### 09/08/2026 - Rolagem integral da vitrine publica

- A vitrine publica mantinha o cabecalho, os indicadores e a busca parados
  porque somente a grade de cartas estava dentro do componente rolavel.
- A tela passou a usar um `NestedScrollView`: barra superior e resumo formam
  os slivers do cabecalho, enquanto a grade virtualizada permanece no corpo.
- Ao descer a pagina, toda a parte superior agora sai da tela junto com as
  cartas; o resumo fixo do carrinho continua visivel somente quando necessario.
- Foi adicionado um teste estrutural para impedir a reintroducao de uma grade
  com rolagem isolada do cabecalho.

### 09/08/2026 - Retorno da vitrine publica ao TCG BH

- A vitrine compartilhada passou a exibir um atalho de inicio na barra superior
  e o botao textual `Ir para o TCG BH` junto das ferramentas da vitrine.
- Em telas pequenas, o botao textual ocupa toda a largura e permanece separado
  da acao de copiar o link; em telas maiores, as duas acoes ficam lado a lado.
- Os dois atalhos levam diretamente para `/home`, inclusive quando a vitrine e
  aberta por um link externo sem historico de navegacao no navegador.

### 09/08/2026 - Seletor de cartas mais facil na importacao

- Os resultados de `Importar carta pela biblioteca` deixaram de usar uma faixa
  horizontal estreita, que exigia clicar e arrastar com precisao no desktop.
- O dialogo agora aproveita melhor a largura da tela e mostra uma grade vertical
  responsiva com duas a cinco colunas, conforme o espaco disponivel.
- A grade possui barra de rolagem visivel e pode ser navegada pela roda do mouse
  ou por gesto vertical. Ate duas linhas ficam visiveis antes da rolagem.
- A carta escolhida recebe borda destacada, selo de confirmacao e o texto
  `Carta selecionada`, reduzindo o risco de adicionar a arte errada.
- Um teste de interface cobre a busca, a grade vertical e a selecao visual.

### 10/08/2026 - Busca completa ao importar pela biblioteca

- O dialogo de importacao solicitava explicitamente somente 40 resultados,
  embora o catalogo calculasse e ordenasse todas as cartas correspondentes.
- As duas consultas do fluxo, durante a digitacao e ao confirmar, passaram a
  solicitar todos os resultados nos mesmos campos da Biblioteca: nome, codigo,
  edicao, raridade, atributo, tipo e subtipo. Buscas internas de OCR e
  conciliacao mantem limites pequenos para preservar seu desempenho.
- A grade continua virtualizada: mesmo uma busca com mais de 170 correspondencias
  cria visualmente apenas as cartas necessarias para a area exibida.
- O teste do dialogo passou a simular 60 cartas e confirma que nenhum limite e
  enviado ao servico e que a contagem completa aparece para o usuario.

### 10/08/2026 - Filtro de cor na importacao pela biblioteca

- O dialogo de busca ganhou o campo `Cor da carta`, com todas as
  seis cores oficiais, a opcao `Multicolor` e o retorno para `Todas as cores`.
- Ao filtrar uma cor individual, cartas multicoloridas que possuem aquela cor
  tambem permanecem nos resultados; `Multicolor` mostra apenas combinacoes.
- A interface informa quantas cartas estao sendo exibidas em relacao ao total e
  apresenta uma orientacao clara quando nenhuma carta corresponde a cor.
- Se uma carta selecionada deixar de pertencer ao filtro escolhido, a selecao e
  limpa para impedir que uma arte oculta seja adicionada por engano.

### 10/08/2026 - Variantes com sufixo na busca por codigo

- A Biblioteca encontrava variantes como `OP09-119-3A` por substring, mas o
  importador agrupava somente as cartas cuja chave era exatamente `OP09-119`.
  Por isso mostrava quatro das seis impressoes desse codigo.
- A normalizacao anterior tambem descartava varios sufixos alfanumericos com
  hifen. A auditoria do catalogo de producao encontrou 655 codigos-base afetados
  e 1.883 variantes que nao apareciam na busca exata do importador.
- O catalogo em memoria agora mantem um indice exato e outro por codigo-base.
  Digitar o codigo-base retorna todas as impressoes; digitar um codigo completo
  com sufixo continua retornando apenas aquela variante.
- Sufixos de sets, promocionais e DON, como `AA`, `SP`, `3A` e `TTC`, passaram
  a ser normalizados e indexados sem perder sua identidade.
- Testes cobrem as seis impressoes de `OP09-119`, a consulta especifica de
  `OP09-119-3A` e formatos com e sem hifen.

### 10/08/2026 - Edicao visivel nas cartas da Biblioteca One Piece

- Cartas com a mesma arte podem ser impressoes legitimas de edicoes diferentes,
  como `EB01-006` e `EB01-006-MA`, e devem continuar separadas porque possuem
  codigo, origem e preco proprios.
- A grade da Biblioteca agora exibe `Edicao: <nome da edicao>` diretamente em
  cada carta, sem exigir que o usuario abra os detalhes para identificar a
  impressao correta.
- Os cards ficaram ligeiramente mais altos e mostram tres informacoes fixas:
  edicao, categoria e cor, alem do codigo, nome e preco que ja eram exibidos.
- Um teste estrutural garante que a identificacao da edicao continue presente
  nos resultados da Biblioteca.

### 10/08/2026 - Confirmacao ao repetir carta em Cartas a venda

- O fluxo da colecao ja consolidava silenciosamente uma carta em seu registro
  de venda existente, mas nao informava ao usuario que aquela impressao ja
  estava anunciada.
- Quando encontra a mesma impressao por codigo e imagem, o dialogo agora mostra
  a quantidade atual em Cartas a venda, o saldo ainda disponivel na colecao e
  pergunta se o usuario deseja acrescentar mais copias.
- A confirmacao usa o texto `Adicionar mais`; depois da operacao, o aviso mostra
  a quantidade adicionada e o novo total anunciado daquela impressao.
- Se todas as copias ja estiverem anunciadas, nenhuma alteracao e feita e o
  aviso informa quantas cartas ja existem em Cartas a venda.

### 10/08/2026 - Preco correto para cartas de aniversario

- `Bartholomew Kuma (Japanese Version 3rd Anniversary Set)` chegava do catalogo
  com o codigo base `OP12-119`. Como `Anniversary` nao era uma variante
  reconhecida, o resolvedor selecionava o preco de R$ 97,43 da carta comum.
- O cache da Liga possui a impressao correta como `OP12-119-3A`, no valor de
  R$ 359,90. O classificador agora converte nomes como `3rd Anniversary` em
  sufixos `-3A`, aplicando o mesmo padrao a outros numeros de aniversario.
- Impressoes de aniversario passaram a exigir correspondencia estrita por
  variante. Se o preco especifico estiver ausente, a interface mostra a carta
  como nao verificada em vez de reutilizar silenciosamente o preco comum.
- Testes cobrem a inferencia do codigo, a selecao entre os dois registros reais
  do Kuma e a proibicao de fallback de qualquer variante estrita para a base.

### 10/08/2026 - Imagem e preco corretos para Winner Pack

- `Kouzuki Hiyori (Winner Pack 2026 Vol. 1)` chegava da API promocional com o
  codigo base `OP12-028` e sem URL de imagem. A tela reutilizava a arte comum e
  procurava o sufixo generico de vencedor `-RW`.
- A Liga ja mantinha a impressao correta como `OP12-028-WP`, com imagem propria
  e menor preco de R$ 28,49. `Winner Pack` agora e uma variante estrita separada
  e usa o sufixo `-WP`; vencedores de Release Event continuam usando `-RW`.
- Ao mesclar o catalogo promocional, a versao canonica da Liga substitui o
  registro incompleto da API quando codigo-base e nome identificam a mesma
  impressao, evitando duas entradas concorrentes para a mesma carta.
- O catalogo geral tambem descarta a mesma impressao quando codigo, nome e URL
  da imagem reaparecem sob aliases de set (`P` e `PC-01`), sem unir artes
  realmente distintas de edicoes diferentes.
- A colecao, os decks e as vitrines agora recuperam a impressao por codigo,
  nome e set. Registros antigos salvos com o codigo ou a imagem base passam a
  exibir automaticamente a arte canonica da variante sem precisar ser refeitos.
- As leituras dos dois catalogos no Supabase repetem automaticamente respostas
  429/5xx e falhas de rede antes de usar o catalogo de contingencia. Isso evita
  que uma indisponibilidade transitoria recoloque a variante incompleta em cache.
- O cache web do catalogo foi versionado como `v9`. Testes cobrem a fusao da
  imagem Winner, a inferencia `OP12-028-WP` e a selecao do preco especifico.

### 10/08/2026 - Carregamento progressivo da colecao

- O F5 iniciava a colecao como uma lista vazia e aguardava a carga integral de
  `/api/optcg-cards` antes de consultar e mostrar os registros do usuario. Nesse
  intervalo a tela exibia incorretamente zero cartas e `Nenhuma carta`.
- A carga agora tem duas fases: primeiro consulta colecao e decks diretamente
  no Supabase e os exibe; depois atualiza imagens e metadados com o catalogo em
  segundo plano. A consulta ao banco e a do catalogo tambem rodam em paralelo.
- Sem dados iniciais, a pagina mostra `Carregando sua colecao...`. Com as cartas
  ja visiveis, um aviso informa que imagens e detalhes ainda estao sendo
  atualizados. Falha nessa segunda fase preserva os itens salvos na tela.
- O endpoint carrega os catalogos promocional e geral em paralelo, registra a
  duracao da operacao e usa cache HTTP de 5 minutos no navegador e 15 minutos
  no CDN, com revalidacao em segundo plano. O cliente nao envia mais `no-cache`
  ao proxy web em todo F5.
- Visitantes nao consultam mais `liga_card_variant_mappings`, protegida para
  usuarios autenticados. Isso remove respostas 401 e trabalho inutil durante o
  carregamento publico da Biblioteca; a resolucao publica por variante continua
  funcionando normalmente.

### 10/08/2026 - Estabilidade da tela de vendas no iPhone

- Um video real mostrou o Chrome do iPhone reiniciando a aba de `Cartas a venda`
  e depois exibindo `Nao e possivel abrir essa pagina`. Nao houve erro no
  servidor nem chamada de recarregamento no site: o processo grafico estava
  sendo encerrado por pressao de memoria.
- A tela montava todas as cartas dentro de `SingleChildScrollView` com uma grade
  `shrinkWrap`, mantendo todas as imagens em alta resolucao vivas. Agora usa
  `CustomScrollView`, `SliverList` e `SliverGrid`, construindo apenas os itens
  proximos da area visivel.
- Miniaturas de vendas passam a ser decodificadas no tamanho necessario, com
  qualidade leve e fallback HTML apenas quando CORS exigir. O cache web de
  imagens foi limitado a 120 entradas e 48 MB para evitar novo encerramento da
  aba em aparelhos com pouca memoria.

### 10/08/2026 - Segunda rodada de performance e visual das vendas

- A busca em `Cartas a venda` agora espera 220 ms apos a digitacao antes de
  filtrar, evitando reconstruir cabecalho, pastas e grade em toda tecla.
- Contagens e valores de todas as pastas sao calculados em uma unica passagem
  pelos anuncios e reutilizados. A grade deixou de criar uma chave gigante com
  IDs, codigos e URLs em toda renderizacao.
- No celular, o resumo usa indicadores compactos e pode ser recolhido, mantendo
  busca e seletor Grade/Lista acessiveis. Pastas ocupam menos largura e o botao
  `Nova pasta` vira um icone com dica, liberando espaco.
- O preco passou a ter uma linha destacada e sempre visivel em cada carta. O
  botao duplicado de adicionar no topo foi removido; o botao flutuante permanece.
- A carga inicial das vendas agora informa `Carregando suas vendas...` junto aos
  esqueletos, inclusive para leitores de tela.

### 10/08/2026 - Welcome Pack separado da carta comum

- `Nami (Welcome Pack 2026 Vol.1)` chegava ao catalogo com o codigo-base
  `PRB02-012`. Como apenas `Winner Pack` era reconhecido, a impressao especial
  era classificada como comum e herdava os R$ 27,75 da Nami de `PRB2`.
- O cache da Liga ja continha a impressao correta como `PRB02-012-WP`, na edicao
  promocional `PC-01`, com menor preco de R$ 45,00.
- `Welcome Pack` agora e uma variante estrita propria, usando o sufixo `-WP` sem
  se confundir com `Winner Pack`. Se a impressao especifica nao existir, o site
  nao reutiliza silenciosamente o preco da carta comum.
- O auditor automatico passou a reconhecer `-WP` e a distinguir Welcome Pack,
  Winner Pack e Winner de evento. Testes cobrem o preco correto e bloqueiam o
  fallback para a carta normal.

### 10/08/2026 - Carregamento inicial da vitrine publica

- A primeira visita a uma vitrine aguardava `/api/optcg-cards` antes de buscar
  os anuncios. Em medicao de producao, esse catalogo completo levou 10,15 s e
  transferiu 4,73 MB, enquanto o HTML respondeu em 0,08 s.
- Os anuncios ja persistem nome, imagem, set e demais metadados necessarios.
  A vitrine agora consulta apenas os anuncios publicos e o perfil do vendedor,
  executando essas duas operacoes em paralelo.
- O catalogo completo e a atualizacao de precos dinamicos do proprietario foram
  removidos do caminho critico da pagina publica. Imagens antigas sem URL ainda
  podem usar a resolucao tardia, sem impedir que a vitrine apareca.
- Um teste de regressao garante que `getPublicListingsByUser` nao volte a chamar
  o carregamento geral de catalogo.

### 11/08/2026 - Imagem Full Art correta no marketplace

- O anuncio `OP16-108` estava nomeado como `Shiryu (Full Art)`, mas conservava
  a URL da arte comum recebida da API antiga. O modal priorizava qualquer URL
  persistida e, por isso, mostrava uma impressao diferente do nome e do preco.
- O catalogo e o cache da Liga ja continham a variante correta como
  `OP16-108-FA`, com imagem propria e menor preco de R$ 118,88.
- Colecao, cartas a venda, marketplace e compartilhamento individual agora usam
  um resolvedor comum de variantes. Impressões estritas sao selecionadas pelo
  conjunto codigo-base, nome, set e imagem; `Full Art` nao pode mais herdar a
  arte comum.
- Testes cobrem a substituicao da imagem antiga, a preservacao da carta normal e
  a proibicao de fallback quando a variante estrita nao existe no catalogo.

### 11/08/2026 - Carrosseis aleatorios no marketplace

- A carta principal do marketplace deixou de ser sempre o primeiro resultado.
  Os anuncios filtrados sao embaralhados e o destaque troca automaticamente a
  cada 15 segundos, com transicao suave, indicador e botoes anterior/proximo.
- Ao abrir os detalhes do destaque, a rotacao e pausada e recomeca somente ao
  fechar o modal, evitando que a carta mude escondida durante a consulta.
- `Ofertas em destaque` agora usa todos os resultados filtrados em ordem
  aleatoria, avanca automaticamente a cada 7 segundos e aceita arraste, roda do
  mouse e botoes laterais. Ao completar uma volta, a ordem e embaralhada de novo.
- Timers e controlador de rolagem sao sempre descartados ao sair da tela. Testes
  de regressao verificam intervalo, aleatoriedade, controles e descarte seguro.

### 11/08/2026 - Imagem Full Art preservada nos anuncios

- O anuncio `OP16-108` ja guardava a imagem correta da Full Art obtida na Liga,
  mas o catalogo auxiliar nomeava a arte comum como `Shiryu (Full Art)` e
  sobrescrevia a URL correta durante o carregamento do marketplace global.
- Para variantes estritas, imagens persistidas no repositorio oficial usado
  pela Liga agora sao tratadas como a referencia visual mais forte. O catalogo
  continua preenchendo imagens ausentes e corrigindo URLs antigas de outras
  fontes, mas nao substitui mais uma impressao exata da Liga.
- Testes cobrem a preservacao da Full Art da Liga e a correcao de imagens antigas
  que nao vieram desse repositorio.

### 11/08/2026 - Estabilidade e memoria nas paginas de cartas

- O marketplace global carregava o catalogo completo de mais de 7 mil cartas
  antes de montar poucos anuncios. Marketplace e `Cartas a venda` agora usam os
  dados persistidos do anuncio e nao bloqueiam a primeira tela nesse catalogo.
- No celular, a grade global deixou de usar `GridView` com `shrinkWrap` dentro de
  outra rolagem. Ela passou a ser um `SliverGrid` virtualizado, sem manter cards
  fora da tela vivos e com carregamento progressivo ao se aproximar do fim.
- Miniaturas do marketplace agora limitam a largura decodificada e evitam criar
  uma visualizacao HTML separada para cada carta. Respostas de preco da Liga sao
  agrupadas por 120 ms, reduzindo varias reconstrucoes completas em sequencia.
- O aplicativo limpa imagens decodificadas quando o navegador informa pressao de
  memoria. Uma auditoria automatizada garante que bibliotecas, colecoes, vendas,
  procurados, vitrines e marketplaces principais continuem usando grades lazy.

### 16/08/2026 - Primeira abertura da colecao sem F5

- Depois de 12 horas, o cache local de precos era descartado antes da consulta
  remota. A colecao agora mostra imediatamente o ultimo valor salvo como
  desatualizado e o substitui pela resposta atual do Supabase em segundo plano.
- Consultas de preco iniciadas antes e depois da atualizacao do catalogo podiam
  terminar fora de ordem. Cada carga passou a ter uma geracao; somente a mais
  recente pode alterar a tela, e respostas parciais nao apagam precos ja
  exibidos.
- Falhas na auditoria de variantes eram marcadas como definitivamente lidas e
  so voltavam a ser consultadas apos F5. Agora leituras remotas tentam novamente
  com espera progressiva e somente consultas bem-sucedidas entram no cache.
- Auditoria de variantes e precos por codigo passaram a carregar em paralelo,
  reduzindo uma viagem ao banco durante a primeira abertura.
- Imagens da colecao que falharem por indisponibilidade transitoria fazem duas
  novas tentativas automaticamente, em 800 ms e 2 s, mantendo o limite de
  decodificacao e a grade virtualizada.
- Validacao: 209 testes Flutter, 26 Node e 21 Python aprovados; cobertura de
  34,42%, analise estatica limpa e build web concluido.

### 16/08/2026 - Imagens ausentes na colecao

- A origem `www.optcgapi.com` deixou de responder inclusive em testes de 30 s,
  fazendo cartas antigas e variantes aparecerem como blocos vazios ou imagens
  quebradas. As copias ja existentes no CDN R2 continuavam respondendo `200`.
- A colecao agora resolve codigo, nome, set e variante pelo catalogo visual
  local e usa automaticamente a copia duravel do R2. A carta normal, Alternate
  Art, Manga, SP e reprints com o mesmo codigo nao se confundem nesse fallback.
- O catalogo carregado em memoria tambem troca URLs instaveis pelas copias do
  R2, estendendo a correcao para biblioteca, importacao e demais telas.
- Cartas novas como `ST31-004` e `ST31-005` chegavam da API com imagem nula,
  embora o catalogo da Liga tivesse uma URL valida. A mesclagem agora substitui
  imagens vazias ou hospedadas na OPTCG API pela imagem equivalente da Liga.
- A versao do endpoint e do cache local do catalogo foi incrementada para que
  navegadores existentes recebam a correcao sem depender de limpar dados ou F5.
- Validacao: 213 testes Flutter, 28 Node e 21 Python aprovados; cobertura de
  34,76%, analise estatica limpa e build web concluido.

### 17/08/2026 - Primeira rodada de performance geral

- O marketplace global fazia uma consulta de preco para cada anuncio. Agora
  envia todas as cartas em uma leitura em lote e atualiza a interface uma unica
  vez, reduzindo viagens ao Supabase e reconstrucoes da grade.
- As leituras publicas do cache da Liga passaram de `card_code` para a chave
  primaria `lookup_code`. A consulta antiga foi reproduzida com timeout 57014;
  a nova respondeu normalmente. `sql/performance_indexes.sql` tambem ganhou um
  indice em `card_code` para telas administrativas e consultas antigas.
- Colecao e marketplace deixaram de carregar o JSON visual completo. O novo
  `assets/one_piece_image_catalog.json` tem apenas os campos necessarios, cerca
  de 1 MB bruto e 100 KB com Brotli, mantendo 4.939 impressoes e o espelho R2.
- O marketplace resolve URLs antigas da Liga/OPTCG para o espelho R2 antes de
  desenhar os anuncios, preservando a identidade exata de artes alternativas.
- `marketplace_hero` caiu de 1,72 MB para 94 KB e `scanner_card_stack` de 599 KB
  para 49 KB com WebP. Os PNGs continuam apenas onde metadados sociais exigem.
- O service worker foi atualizado para v7, usa revalidacao condicional e nao
  baixa antecipadamente duas copias completas do CanvasKit. O shell web tambem
  deixou de usar `no-store`, permitindo resposta 304 sem servir versao antiga.
- A API do catalogo ganhou timeout de origem, cache CDN de 6 horas e stale de 7
  dias. `puppeteer-core` passou a dependencia de desenvolvimento atualizada e
  a auditoria de dependencias de producao ficou sem vulnerabilidades.
- Validacao: analise estatica limpa, 218 testes Flutter e 28 Node aprovados,
  build web e dry run Wasm concluidos, alem de smoke visual local da Home e do
  Marketplace Global.

### 17/08/2026 - Segunda rodada de performance e carregamento inicial

- Telas pesadas e pouco acessadas no primeiro uso passaram a usar imports
  adiados. Administracao da Liga, testes de integracao, importadores por camera,
  codigo e imagem, marketplace global, produtos e rankings semanais agora sao
  baixados somente quando a rota correspondente e aberta.
- O JavaScript inicial bruto caiu de 5.160.491 para 4.245.246 bytes, reducao de
  aproximadamente 18%. As partes adiadas sao mantidas em arquivos separados e
  exibem carregamento e opcao de tentar novamente em caso de falha.
- A inicializacao do Hive e do Supabase passou a ocorrer em paralelo. As quatro
  caixas locais do Hive tambem abrem concorrentemente, diminuindo trabalho
  sequencial antes da primeira tela.
- O documento web ganhou conexoes antecipadas com Supabase e o espelho R2 das
  imagens, alem de resolucao DNS antecipada para o repositorio secundario.
- Os dois carrosseis do marketplace preservam os intervalos de 15 e 7 segundos,
  mas aguardam 60 segundos na primeira visita. Isso evita que uma imagem grande
  trocada pelo timer reinicie a medicao de LCP enquanto a pagina ainda carrega;
  controles manuais continuam respondendo imediatamente.
- O build WebAssembly experimental foi testado, mas nao adotado porque as rotas
  adiadas apresentaram tela vazia no teste ponta a ponta. A publicacao continua
  usando o build JavaScript estavel.
- Validacao: analise estatica limpa, 222 testes Flutter e 28 Node aprovados,
  auditoria npm sem vulnerabilidades, build web concluido e smoke local aprovado
  na Home, Marketplace Global, Produtos e rankings semanais.

### 17/08/2026 - Terceira rodada de performance e bootstrap web

- O bootstrap aguardava a exclusao de todos os caches e o cancelamento de
  service workers antes de iniciar o Flutter em um navegador novo. Essa limpeza
  saiu do caminho critico; o Flutter inicia imediatamente e a migracao continua
  sob responsabilidade do service worker versionado `optcg-shell-v7`.
- Biblioteca, colecao, vendas e procuradas de One Piece foram reunidas em um
  modulo adiado. As telas genericas e bibliotecas dos demais TCGs formam outro
  modulo, enquanto decks, vendas e vitrines compartilhadas ficam em um terceiro.
  Isso evita enviar toda a aplicacao para quem abre somente a Home.
- O JavaScript inicial bruto caiu de 4.245.246 para 3.401.452 bytes nesta etapa.
  Em relacao aos 5.160.491 bytes anteriores a divisao de rotas, a reducao total
  chegou a aproximadamente 34%.
- A estrategia experimental de um import adiado por tela foi descartada porque
  criava fragmentos demais. O agrupamento final preserva o ganho de tamanho e
  reduz a fragmentacao por dominio funcional.
- Medicao direta em navegador limpo encontrou o primeiro frame local em cerca
  de 0,55 s. Smoke local aprovou Home, Biblioteca One Piece, Marketplace Global,
  Produtos, Biblioteca Pokemon e rankings semanais. Validacao completa: analise
  estatica limpa, 223 testes Flutter e 28 Node aprovados, auditoria npm sem
  vulnerabilidades e build web concluido.

### 21/08/2026 - Catalogo completo e precos de OP-17

- A pagina da Liga ID 83 passou de uma publicacao parcial para 172 impressoes
  com codigo e imagem. Destas, 157 usam codigos `OP17-*` e cobrem os 119
  numeros-base da colecao; as outras 15 sao DON, SP e reimpressoes especiais
  publicadas dentro da mesma edicao.
- O coletor direcionado gravou 172 impressoes no catalogo proprio e 344 chaves
  de preco, mantendo a chave exata e a chave com escopo da edicao. Na coleta,
  154 impressoes tinham menor preco publico e 18 estavam verificadas sem oferta.
- A resposta mesclada de `/api/optcg-cards?catalog=v12` foi validada com 7.513
  cartas no total, 157 entradas OP17 e imagem, raridade e cor presentes em
  todas elas.
- Os codigos numericos da Liga agora sao convertidos para as raridades e cores
  usadas pelo app. Isso permite filtrar as novas cartas OP17 por cor e raridade,
  mesmo quando elas ainda nao existem na API antiga.
- O cache HTTP recebeu o identificador `catalog=v12` e o Hive passou para
  `all_cards_v9`, incluindo as versoes anteriores na limpeza de legado. Assim,
  navegadores existentes recebem o catalogo completo sem depender de F5 ou
  limpeza manual.

### 21/08/2026 - Quantidade parcial ao mover cartas entre pastas

- O dialogo `Mover para pasta` agora reune destino e quantidade na mesma etapa,
  mostra o total disponivel e oferece controles para mover uma parte ou todas as
  copias. A pasta atual fica identificada e indisponivel como destino.
- Mover apenas parte de um registro reduz a quantidade na pasta de origem e
  cria a parcela na pasta escolhida. Se a mesma impressao ja existe no destino,
  as quantidades sao somadas sem misturar variantes que compartilham codigo.
- O fluxo tambem permite retirar uma quantidade especifica para `Sem pasta` e
  preserva o comportamento anterior quando todas as copias sao movidas.
- Validacao: testes de widget cobrem destino, quantidade parcial e `Sem pasta`;
  os 225 testes Flutter passaram, a analise estatica ficou limpa e o build web
  foi concluido.

### 21/08/2026 - Navegacao horizontal das pastas da colecao

- A faixa de pastas ganhou um controlador horizontal proprio e uma barra de
  rolagem sempre visivel, deixando claro quando existem pastas fora da janela.
- Toque, trackpad, roda do mouse e arraste com o botao do mouse passam a mover a
  faixa. Setas de navegacao aparecem somente quando ha conteudo antes ou depois
  da posicao atual e deslocam quase uma pagina por vez.
- Os cartoes usam largura menor em janelas estreitas e a interface exibe uma
  instrucao curta de navegacao enquanto houver pastas fora da area visivel.
- O teste de estabilidade da colecao protege os dispositivos de entrada, a
  barra horizontal, os controles laterais e a instrucao visual.

### 21/08/2026 - Consolidacao de cartas duplicadas nas pastas

- O movimento completo agora procura a mesma impressao na pasta de destino
  antes de alterar o `folder_id`. Quando ela existe, soma as quantidades,
  preserva o favorito e remove o registro antigo com restauracao em caso de
  falha na segunda operacao.
- A carga inicial da colecao executa uma reconciliacao leve. Duplicatas exatas
  preexistentes na mesma pasta sao consolidadas, corrigindo os registros criados
  pelo fluxo anterior assim que o usuario abrir ou atualizar a colecao.
- A identidade exige pasta, codigo, nome, edicao e imagem equivalentes. Parametros
  temporarios da URL sao ignorados, mas artes alternativas e pastas diferentes
  permanecem independentes.
- Testes cobrem URLs com cache diferente, separacao entre arte normal e
  alternativa, pastas diferentes e o fallback seguro para cartas sem imagem.
  A validacao completa terminou com 229 testes Flutter aprovados, analise
  estatica limpa e build web concluido.

### 24/08/2026 - Exclusao de pastas com destino das cartas

- Ao excluir uma pasta da colecao, o usuario agora escolhe entre preservar as
  cartas em `Sem pasta` ou remover permanentemente todas as cartas da pasta.
- O dialogo informa quantas impressoes diferentes e quantas copias existem na
  pasta antes da decisao, e destaca visualmente a opcao destrutiva.
- O repositorio limita a alteracao ao usuario autenticado, a cartas da colecao
  e ao identificador exato da pasta antes de excluir a propria pasta.
- Validacao: 230 testes Flutter aprovados, analise estatica limpa e build web
  concluido.
