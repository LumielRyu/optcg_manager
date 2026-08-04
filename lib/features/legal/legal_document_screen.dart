import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/privacy/cookie_consent.dart';
import '../../core/widgets/app_page_shell.dart';
import '../../core/widgets/legal_footer.dart';

enum LegalDocumentType { privacy, cookies, terms, contact }

class LegalDocumentScreen extends ConsumerWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = _documentFor(type);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(document.title),
        actions: [
          IconButton(
            tooltip: 'Página inicial',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: AppPageShell(
        maxWidth: 920,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      document.icon,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      document.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(document.introduction),
                    const SizedBox(height: 8),
                    Text(
                      'Última atualização: 4 de agosto de 2026.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            for (final section in document.sections) ...[
              _LegalSection(section: section),
              const SizedBox(height: 14),
            ],
            if (type == LegalDocumentType.cookies) ...[
              FilledButton.icon(
                onPressed: () => showCookiePreferencesDialog(context, ref),
                icon: const Icon(Icons.tune),
                label: const Text('Gerenciar preferências de privacidade'),
              ),
              const SizedBox(height: 20),
            ],
            if (type == LegalDocumentType.contact) ...[
              FilledButton.icon(
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Falar com o TCG BH pelo WhatsApp'),
              ),
              const SizedBox(height: 20),
            ],
            const LegalFooter(),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/5531993533860?text=${Uri.encodeComponent('Olá! Preciso falar com o TCG BH sobre o site.')}',
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final _LegalDocumentSection section;

  const _LegalSection({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            for (final paragraph in section.paragraphs) ...[
              Text(paragraph),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalDocument {
  final String title;
  final String introduction;
  final IconData icon;
  final List<_LegalDocumentSection> sections;

  const _LegalDocument({
    required this.title,
    required this.introduction,
    required this.icon,
    required this.sections,
  });
}

class _LegalDocumentSection {
  final String title;
  final List<String> paragraphs;

  const _LegalDocumentSection({required this.title, required this.paragraphs});
}

_LegalDocument _documentFor(LegalDocumentType type) => switch (type) {
  LegalDocumentType.privacy => _privacyDocument,
  LegalDocumentType.cookies => _cookiesDocument,
  LegalDocumentType.terms => _termsDocument,
  LegalDocumentType.contact => _contactDocument,
};

const _privacyDocument = _LegalDocument(
  title: 'Política de Privacidade',
  introduction:
      'Esta política explica como o TCG BH trata dados pessoais usados para fornecer contas, coleções, rankings, marketplace e demais recursos da plataforma.',
  icon: Icons.privacy_tip_outlined,
  sections: [
    _LegalDocumentSection(
      title: 'Dados que podemos tratar',
      paragraphs: [
        'No cadastro e no perfil, podemos tratar e-mail, nick ou nome público, telefone/WhatsApp, foto de perfil e identificadores técnicos da conta.',
        'Quando você usa a plataforma, armazenamos os dados que decide cadastrar, como coleções, decks, listas, anúncios, cartas procuradas e participações em recursos da comunidade.',
        'Registros técnicos mínimos podem ser processados para segurança, prevenção de abuso, diagnóstico de erros e funcionamento do serviço.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Finalidades',
      paragraphs: [
        'Usamos os dados para autenticar usuários, salvar preferências, entregar as funcionalidades solicitadas, permitir contato entre participantes do marketplace, proteger a plataforma e responder solicitações de suporte.',
        'Medição de audiência e publicidade personalizada somente poderão ser ativadas de acordo com a preferência registrada no painel de privacidade.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Fornecedores e compartilhamento',
      paragraphs: [
        'A infraestrutura utiliza fornecedores de hospedagem, autenticação, banco de dados e armazenamento, incluindo Vercel e Supabase. APIs de card games são consultadas para exibir catálogos e informações das cartas.',
        'Dados públicos escolhidos pelo usuário, como anúncios de venda e listas compartilhadas, podem ser vistos por outras pessoas. Não comercializamos os dados pessoais cadastrados pelos usuários.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Retenção, segurança e direitos',
      paragraphs: [
        'Mantemos os dados enquanto a conta ou a finalidade correspondente estiver ativa, observadas necessidades de segurança, auditoria e obrigações aplicáveis.',
        'Você pode solicitar acesso, correção ou exclusão dos seus dados pelo canal indicado na página de Contato. Algumas informações podem ser conservadas quando houver obrigação ou motivo legítimo aplicável.',
      ],
    ),
  ],
);

const _cookiesDocument = _LegalDocument(
  title: 'Política de Cookies e Armazenamento Local',
  introduction:
      'O TCG BH utiliza armazenamento no navegador para manter a sessão e preferências. Recursos opcionais permanecem sob controle do usuário.',
  icon: Icons.cookie_outlined,
  sections: [
    _LegalDocumentSection(
      title: 'Necessários',
      paragraphs: [
        'São usados para login, segurança, tema, preferências de visualização, funcionamento offline e atualização dos arquivos do aplicativo. Sem eles, partes essenciais podem não funcionar corretamente.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Medição e analytics',
      paragraphs: [
        'A estrutura permite registrar uma preferência para medição de audiência. Nenhuma ferramenta opcional de analytics foi ativada nesta etapa.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Publicidade',
      paragraphs: [
        'A estrutura permite escolher publicidade personalizada. O TCG BH ainda não carrega anúncios nem cookies de publicidade; qualquer ativação futura deverá respeitar a escolha registrada.',
        'Anúncios não personalizados ainda podem utilizar armazenamento limitado para frequência, segurança e medição, conforme o provedor que vier a ser contratado.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Como alterar sua escolha',
      paragraphs: [
        'Você pode recusar recursos opcionais no primeiro acesso e revisar a decisão a qualquer momento pelo link “Gerenciar privacidade” disponível no rodapé.',
      ],
    ),
  ],
);

const _termsDocument = _LegalDocument(
  title: 'Termos de Uso',
  introduction:
      'Ao utilizar o TCG BH, você concorda em usar a plataforma de forma lícita, respeitosa e compatível com a comunidade de card games.',
  icon: Icons.gavel_outlined,
  sections: [
    _LegalDocumentSection(
      title: 'Contas e conteúdo do usuário',
      paragraphs: [
        'Você é responsável pelas informações cadastradas e pela segurança da sua conta. Não publique dados falsos, conteúdo ilegal, ofensivo ou que viole direitos de terceiros.',
        'Podemos limitar ou remover conteúdo e contas em caso de abuso, fraude, risco à segurança ou violação destes termos.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Marketplace e contatos',
      paragraphs: [
        'O TCG BH aproxima interessados por meio de anúncios e contatos externos. A plataforma não recebe o pagamento nem garante preço, entrega, autenticidade, conservação ou conclusão das negociações entre usuários.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Preços e informações de terceiros',
      paragraphs: [
        'Preços exibidos são referências coletadas de fontes externas e podem estar desatualizados, indisponíveis ou divergir das condições reais de mercado. Confira os valores antes de negociar.',
        'Nomes, marcas, imagens e propriedades dos card games pertencem aos seus respectivos titulares. O TCG BH é uma plataforma independente e não representa oficialmente essas empresas.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Disponibilidade e alterações',
      paragraphs: [
        'Podemos atualizar, suspender ou descontinuar funcionalidades por manutenção, segurança, mudanças de fornecedores ou evolução do projeto. Estes termos podem ser atualizados, com indicação da data da versão vigente.',
      ],
    ),
  ],
);

const _contactDocument = _LegalDocument(
  title: 'Contato e Privacidade',
  introduction:
      'Use este canal para suporte, dúvidas comerciais, produtos personalizados ou solicitações relacionadas aos seus dados.',
  icon: Icons.contact_support_outlined,
  sections: [
    _LegalDocumentSection(
      title: 'Canal de atendimento',
      paragraphs: [
        'WhatsApp: +55 31 99353-3860. Informe no início da mensagem se o assunto é suporte, privacidade, publicidade ou produtos personalizados.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Solicitações de privacidade',
      paragraphs: [
        'Para localizar sua conta com segurança, podemos solicitar confirmação de identidade antes de fornecer, corrigir ou excluir dados. Nunca envie sua senha pelo WhatsApp.',
      ],
    ),
    _LegalDocumentSection(
      title: 'Publicidade e patrocínio',
      paragraphs: [
        'Lojas, organizadores e marcas da comunidade podem entrar em contato para consultar futuros espaços de patrocínio. Conteúdo patrocinado será identificado de forma clara no site.',
      ],
    ),
  ],
);
