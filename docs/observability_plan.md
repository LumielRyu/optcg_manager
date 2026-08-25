# Plano de observabilidade do TCG BH

## Situacao encontrada em 25/08/2026

- Os deploys da Vercel estavam saudaveis e o endpoint `/api/health` respondeu
  normalmente.
- O endpoint `/api/client-errors` recebia falhas do Flutter e do navegador, mas
  escrevia somente no log temporario da Function. Nao havia historico duravel,
  busca por codigo de referencia ou painel de acompanhamento.
- A abertura do Marketplace dependia de mais de uma leitura do Supabase. Uma
  oscilacao curta na consulta secundaria de nomes dos vendedores derrubava a
  pagina inteira; tentar novamente normalmente funcionava.
- O detector de sessao interrompida aceitava um intervalo de 12 horas e podia
  registrar como falha uma aba apenas fechada ou suspensa normalmente.

## Fase 1 - implementada no codigo

- Repetir leituras remotas idempotentes com espera curta e limite de tentativas.
- Nao impedir a exibicao dos anuncios quando apenas os nomes dos vendedores
  estiverem temporariamente indisponiveis.
- Guardar erros sanitizados em `client_error_events`, com codigo de referencia,
  contexto, rota, plataforma, diagnostico de rede/tela, deploy e horario.
- Manter tambem os logs estruturados da Vercel, correlacionados por request ID.
- Considerar uma sessao interrompida apenas quando o ultimo batimento ocorreu
  ha menos de 90 segundos, reduzindo falsos positivos.

Para ativar a persistencia, execute `sql/client_error_events.sql` no Supabase e
adicione `SUPABASE_SERVICE_ROLE_KEY` somente ao ambiente Production da Vercel.
A chave nunca deve ser exposta no Flutter, no Git ou em variaveis publicas.

## Fase 2 - proxima melhoria recomendada

- Criar uma tela administrativa protegida para consultar erros por periodo,
  rota, contexto, versao e codigo de referencia.
- Registrar o inicio, sucesso, falha e duracao das cargas criticas (colecao,
  biblioteca, marketplace, vitrine e precos), sem registrar cliques comuns nem
  dados pessoais.
- Diferenciar falha recuperada automaticamente de falha exibida ao usuario.
- Exibir no painel taxa de erro, rotas mais afetadas, navegadores e deploy em
  que cada regressao comecou.

## Fase 3 - alertas e retencao

- Alertar quando uma rota ultrapassar um limite de falhas em uma janela curta,
  ou quando `/api/health` falhar repetidamente.
- Manter erros detalhados por 30 dias e agregar apenas contagens mais antigas.
- Revisar periodicamente sanitizacao, acesso administrativo e indices da tabela.
- Integrar um drain/servico de observabilidade caso o volume ultrapasse o que o
  Supabase e o painel interno conseguem atender com simplicidade.

## Consulta inicial no Supabase

```sql
select
  reference_id,
  context,
  error_message,
  path,
  platform,
  diagnostics,
  git_commit_sha,
  created_at
from public.client_error_events
order by created_at desc
limit 100;
```
