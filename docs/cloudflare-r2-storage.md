# Cloudflare R2 Storage

Este projeto usa o Supabase para Auth e banco de dados. Arquivos pesados, como imagens de cartas e caches visuais, devem ficar no Cloudflare R2 para preservar o plano gratis do Supabase.

## Arquitetura

- Supabase guarda dados pequenos e relacionais.
- R2 guarda arquivos e imagens.
- As tabelas do Supabase guardam apenas URLs publicas das imagens.
- O app carrega imagens por um dominio CDN, por exemplo `https://cdn.optcgmanager.com`.

## Criar o Bucket

1. Abra o painel da Cloudflare.
2. Va em `R2 Object Storage`.
3. Crie um bucket chamado `card-images`.
4. Mantenha o bucket privado para escrita.
5. Configure acesso publico por um dominio proprio, como `cdn.optcgmanager.com`.

## Criar Chaves R2

1. Em R2, abra `Manage R2 API Tokens`.
2. Crie uma chave com permissao de leitura e escrita no bucket `card-images`.
3. Guarde:
   - Account ID
   - Access Key ID
   - Secret Access Key

Nunca coloque `R2_SECRET_ACCESS_KEY` no Flutter, no navegador ou em arquivos commitados.

## Variaveis Locais

Preencha no `.env` local:

```env
R2_ACCOUNT_ID=<cloudflare-account-id>
R2_BUCKET=card-images
R2_ENDPOINT_URL=https://<cloudflare-account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=<access-key-id>
R2_SECRET_ACCESS_KEY=<secret-access-key>
R2_REGION=auto
CARD_IMAGE_PUBLIC_BASE_URL=https://cdn.optcgmanager.com
```

## Testar Upload

Instale o SDK S3 usado pelo script:

```bash
python -m pip install boto3
```

Gere ou atualize o cache local de imagens:

```bash
python scripts/generate_visual_fingerprints.py --workers 6
```

Teste com poucos arquivos:

```bash
python scripts/sync_s3_card_images.py --limit 10
```

Se funcionar, rode o upload completo:

```bash
python scripts/sync_s3_card_images.py
```

## Atualizar URLs do App

Depois do upload, gere o catalogo visual apontando para o dominio R2:

```bash
python scripts/generate_visual_fingerprints.py --public-base-url https://cdn.optcgmanager.com --workers 6
```

Depois rode:

```bash
flutter analyze
flutter build web --release
```

## Deploy

Apos validar, faca commit e deploy na Vercel.

## Limpeza do Supabase Storage

So apague imagens antigas do Supabase depois de confirmar que:

- As imagens carregam pelo dominio R2.
- O app em producao esta usando o novo catalogo.
- Nao existem URLs antigas do Supabase sendo gravadas em novos registros.

Para seguranca, mantenha os arquivos antigos por alguns dias antes de remover.
