const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('puppeteer-core');

const ROOT = path.resolve(__dirname, '..');
const ARTIFACTS_DIR = path.join(ROOT, 'artifacts', 'e2e');
const DEFAULT_BASE_URL = 'https://tcgbh.vercel.app';

const ROUTES = [
  {
    name: 'home',
    hash: '#/home',
    title: 'TCG BH | Card games, marketplace e produtos',
    content: ['SEMANAIS STOP TCG', 'One Piece', 'Pokemon'],
  },
  {
    name: 'weeklies',
    hash: '#/weeklies',
    title: 'Semanais STOP TCG | TCG BH',
    content: ['Semanais STOP TCG', 'One Piece Card Game', 'Pokemon TCG'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'pokemon-weekly',
    hash: '#/weeklies/pokemon',
    title: 'Semanal Pokemon | TCG BH',
    content: ['Semanal Pokemon', 'LIGA DE QUINTA-FEIRA', 'LIGA DE SABADO'],
  },
  {
    name: 'one-piece-weekly',
    hash: '#/weeklies/one-piece',
    title: 'Semanal One Piece | TCG BH',
    content: [
      'Semanal One Piece',
      'Ranking mensal dos piratas',
    ],
  },
  {
    name: 'login',
    hash: '#/login',
    title: 'Entrar | TCG BH',
    content: ['Entrar', 'Criar conta'],
    backTarget: '#/home',
  },
  {
    name: 'register',
    hash: '#/register',
    title: 'Criar conta | TCG BH',
    content: ['Criar conta'],
    backTarget: '#/home',
  },
  {
    name: 'library',
    hash: '#/library',
    title: 'Biblioteca One Piece | TCG BH',
    content: ['Biblioteca One Piece', 'Liga:'],
    backTarget: '#/home/one-piece',
  },
  {
    name: 'pokemon-hub',
    hash: '#/pokemon',
    title: 'Pokemon | TCG BH',
    content: ['Pokemon', 'Biblioteca', 'Colecao'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'pokemon-library',
    hash: '#/pokemon/library',
    title: 'Biblioteca Pokemon | TCG BH',
    content: ['Biblioteca Pokemon'],
    backTarget: '#/pokemon',
    ignoredConsoleErrorIncludes: ['api.pokemontcg.io'],
  },
  {
    name: 'pokemon-collection-guest',
    hash: '#/pokemon/collection',
    title: 'Coleção Pokemon | TCG BH',
    content: ['Minha colecao Pokemon', 'necessario entrar'],
    backTarget: '#/pokemon',
  },
  {
    name: 'digimon-hub',
    hash: '#/digimon',
    title: 'Digimon | TCG BH',
    content: ['Digimon', 'Biblioteca', 'Colecao'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'digimon-library',
    hash: '#/digimon/library',
    title: 'Biblioteca Digimon | TCG BH',
    content: ['Biblioteca Digimon', 'Adicionar à coleção'],
    backTarget: '#/digimon',
    waitForContent: 'Adicionar à coleção',
  },
  {
    name: 'digimon-collection-guest',
    hash: '#/digimon/collection',
    title: 'Coleção Digimon | TCG BH',
    content: ['Minha colecao Digimon', 'necessario entrar'],
    backTarget: '#/digimon',
  },
  {
    name: 'magic-hub',
    hash: '#/magic',
    title: 'Magic | TCG BH',
    content: ['Magic', 'Biblioteca', 'Colecao'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'magic-library',
    hash: '#/magic/library',
    title: 'Biblioteca Magic | TCG BH',
    content: ['Biblioteca Magic', 'Adicionar à coleção'],
    backTarget: '#/magic',
    waitForContent: 'Adicionar à coleção',
  },
  {
    name: 'magic-collection-guest',
    hash: '#/magic/collection',
    title: 'Coleção Magic | TCG BH',
    content: ['Minha colecao Magic', 'necessario entrar'],
    backTarget: '#/magic',
  },
  {
    name: 'riftbound-hub',
    hash: '#/riftbound',
    title: 'Riftbound | TCG BH',
    content: ['Riftbound', 'Biblioteca', 'Colecao'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'riftbound-library',
    hash: '#/riftbound/library',
    title: 'Biblioteca Riftbound | TCG BH',
    content: ['Biblioteca Riftbound', 'Adicionar à coleção'],
    backTarget: '#/riftbound',
    waitForContent: 'Adicionar à coleção',
  },
  {
    name: 'riftbound-collection-guest',
    hash: '#/riftbound/collection',
    title: 'Coleção Riftbound | TCG BH',
    content: ['Minha colecao Riftbound', 'necessario entrar'],
    backTarget: '#/riftbound',
  },
  {
    name: 'yugioh-hub',
    hash: '#/yugioh',
    title: 'Yu-Gi-Oh | TCG BH',
    content: ['Yu-Gi-Oh', 'Biblioteca', 'Colecao'],
    backTarget: '#/home',
    backButtonLabel: 'Voltar ao Home',
  },
  {
    name: 'yugioh-library',
    hash: '#/yugioh/library',
    title: 'Biblioteca Yu-Gi-Oh | TCG BH',
    content: [
      'Biblioteca Yu-Gi-Oh',
      'Escolher edição e adicionar à coleção',
    ],
    backTarget: '#/yugioh',
    waitForContent: 'Escolher edição e adicionar à coleção',
  },
  {
    name: 'yugioh-collection-guest',
    hash: '#/yugioh/collection',
    title: 'Coleção Yu-Gi-Oh | TCG BH',
    content: ['Minha colecao Yu-Gi-Oh', 'necessario entrar'],
    backTarget: '#/yugioh',
  },
  {
    name: 'products',
    hash: '#/products',
    title: 'Produtos personalizados | TCG BH',
    // Flutter CanvasKit does not expose text until browser accessibility is
    // enabled. This route is still checked for first frame, title, errors and
    // desktop/mobile screenshots; widget tests cover its interactive content.
    content: [],
    backTarget: '#/home',
    backCoordinates: { x: 28, y: 28 },
  },
  {
    name: 'admin-price-guard',
    hash: '#/admin/liga-prices',
    title: 'Monitor de preços da Liga | TCG BH',
    content: ['Entrar', 'Criar conta'],
  },
];

function parseArguments(argv) {
  const options = {
    baseUrl: process.env.E2E_BASE_URL || DEFAULT_BASE_URL,
    headed: false,
    skipApi: false,
    route: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--url') {
      options.baseUrl = argv[index + 1];
      index += 1;
    } else if (argument === '--headed') {
      options.headed = true;
    } else if (argument === '--skip-api') {
      options.skipApi = true;
    } else if (argument === '--route') {
      options.route = argv[index + 1];
      index += 1;
    } else if (argument === '--help') {
      console.log(
        'Uso: node scripts/e2e_smoke.js [--url URL] [--headed] [--skip-api] [--route NOME]',
      );
      process.exit(0);
    } else {
      throw new Error(`Argumento desconhecido: ${argument}`);
    }
  }

  if (!options.baseUrl) {
    throw new Error('A URL base nao pode ficar vazia.');
  }

  options.baseUrl = options.baseUrl.replace(/\/$/, '');
  return options;
}

function findChrome() {
  const candidates = [
    process.env.PUPPETEER_EXECUTABLE_PATH,
    process.env.CHROME_PATH,
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean);

  const executable = candidates.find((candidate) => fs.existsSync(candidate));
  if (!executable) {
    throw new Error(
      'Chrome nao encontrado. Defina PUPPETEER_EXECUTABLE_PATH com o executavel.',
    );
  }
  return executable;
}

function normalizeText(value) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

async function enableFlutterSemantics(page) {
  await page.evaluate(() => {
    const placeholder = document.querySelector('flt-semantics-placeholder');
    if (placeholder instanceof HTMLElement) {
      placeholder.click();
    }
  });
  await new Promise((resolve) => setTimeout(resolve, 750));
}

async function readAccessibleText(page) {
  return page.evaluate(() => {
    const semantics = Array.from(document.querySelectorAll('flt-semantics'));
    const semanticText = semantics.flatMap((element) => [
      element.textContent || '',
      element.getAttribute('aria-label') || '',
      element.getAttribute('value') || '',
      element.getAttribute('placeholder') || '',
    ]);
    return [document.body.innerText, ...semanticText].filter(Boolean).join(' ');
  });
}

async function clickFlutterButton(page, label) {
  const rect = await page.$$eval(
    'flt-semantics[role="button"]',
    (elements, expectedLabel) => {
      const element = elements.find(
        (item) =>
          (item.getAttribute('aria-label') || item.textContent || '').trim() ===
          expectedLabel,
      );
      if (!element) return null;
      const bounds = element.getBoundingClientRect();
      return {
        x: bounds.left + bounds.width / 2,
        y: bounds.top + bounds.height / 2,
      };
    },
    label,
  );
  if (!rect) throw new Error(`Botao Flutter nao encontrado: ${label}.`);
  await page.mouse.click(rect.x, rect.y);
}

async function saveFailureArtifacts(page, name, details) {
  fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
  if (page && !page.isClosed()) {
    await page.screenshot({
      path: path.join(ARTIFACTS_DIR, `${name}.png`),
      fullPage: true,
    });
  }
  fs.writeFileSync(
    path.join(ARTIFACTS_DIR, `${name}.json`),
    `${JSON.stringify(details, null, 2)}\n`,
    'utf8',
  );
}

async function checkApis(baseUrl) {
  const healthResponse = await fetch(`${baseUrl}/api/health`, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(30_000),
  });
  const health = await healthResponse.json();
  if (!healthResponse.ok || health.status !== 'ok') {
    throw new Error(
      `Health check invalido (${healthResponse.status}): ${JSON.stringify(health)}`,
    );
  }
  console.log(`PASS api-health (${healthResponse.status}, ${health.status})`);

  const blockedResponse = await fetch(`${baseUrl}/api/client-errors`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      origin: 'https://origem-nao-autorizada.invalid',
    },
    body: JSON.stringify({ message: 'e2e-origin-check' }),
    signal: AbortSignal.timeout(30_000),
  });
  if (blockedResponse.status !== 403) {
    throw new Error(
      `Protecao de origem retornou ${blockedResponse.status}; esperado 403.`,
    );
  }
  console.log('PASS api-origin-protection (403)');
}

async function checkRoute(browser, baseUrl, route) {
  const page = await browser.newPage();
  const consoleErrors = [];
  const pageErrors = [];

  page.on('console', (message) => {
    if (message.type() === 'error') {
      const location = message.location().url;
      consoleErrors.push(
        location ? `${message.text()} @ ${location}` : message.text(),
      );
    }
  });
  page.on('pageerror', (error) => pageErrors.push(error.message));

  try {
    await page.setViewport({
      width: route.name === 'pokemon-weekly' ? 1920 : 1440,
      height: route.name === 'pokemon-weekly' ? 1080 : 1000,
      deviceScaleFactor: 1,
    });
    const response = await page.goto(`${baseUrl}/${route.hash}`, {
      waitUntil: 'networkidle2',
      timeout: 60_000,
    });
    if (!response || (!response.ok() && response.status() !== 304)) {
      throw new Error(`Documento retornou HTTP ${response?.status() ?? 'sem resposta'}.`);
    }

    await page.waitForSelector('flutter-view', { timeout: 30_000 });
    await page.waitForFunction(
      () => document.getElementById('app-loader')?.classList.contains('hidden'),
      { timeout: 30_000 },
    );
    await enableFlutterSemantics(page);
    if (route.waitForContent) {
      await page.waitForFunction(
        (expected) =>
          Array.from(document.querySelectorAll('flt-semantics')).some((item) =>
            [
              item.textContent || '',
              item.getAttribute('aria-label') || '',
            ].some((value) => value.includes(expected)),
          ),
        { timeout: 60_000 },
        route.waitForContent,
      );
    }
    if (route.name === 'pokemon-weekly') {
      await page.waitForFunction(
        () =>
          Array.from(
            document.querySelectorAll('flt-semantics[role="button"]'),
          ).some(
            (item) =>
              (item.getAttribute('aria-label') || item.textContent || '').trim() ===
              'Modo TV',
          ),
        { timeout: 30_000 },
      );
    }
    if (route.name === 'library') {
      await page.waitForFunction(
        () =>
          Array.from(document.querySelectorAll('flt-semantics')).some((item) =>
            (item.getAttribute('aria-label') || item.textContent || '').includes(
              'Liga:',
            ),
          ),
        { timeout: 60_000 },
      );
    }
    if (route.name === 'products') {
      fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
      await page.screenshot({
        path: path.join(ARTIFACTS_DIR, 'products-desktop.png'),
        fullPage: true,
      });
      await page.setViewport({
        width: 390,
        height: 844,
        deviceScaleFactor: 1,
        isMobile: true,
      });
      await new Promise((resolve) => setTimeout(resolve, 750));
      await page.screenshot({
        path: path.join(ARTIFACTS_DIR, 'products-mobile.png'),
        fullPage: true,
      });
    }

    const title = await page.title();
    const accessibleText = await readAccessibleText(page);
    const normalizedText = normalizeText(accessibleText);
    const ignoredConsoleErrorIncludes = [
      ...(baseUrl.startsWith('http://127.0.0.1') ? ['/api/'] : []),
      ...(route.ignoredConsoleErrorIncludes || []),
    ];
    const ignoredLocalApiErrors = consoleErrors.filter((error) =>
      ignoredConsoleErrorIncludes.some((fragment) => error.includes(fragment)),
    );
    const actionableConsoleErrors = consoleErrors.filter(
      (error) => !ignoredLocalApiErrors.includes(error),
    );
    const missingContent = route.content.filter(
      (expected) => !normalizedText.includes(normalizeText(expected)),
    );

    const details = {
      route: route.hash,
      url: page.url(),
      httpStatus: response.status(),
      title,
      expectedTitle: route.title,
      missingContent,
      consoleErrors,
      ignoredLocalApiErrors,
      pageErrors,
      accessibleText: accessibleText.slice(0, 8_000),
    };

    if (title !== route.title) {
      throw Object.assign(
        new Error(`Titulo incorreto: "${title}"; esperado "${route.title}".`),
        { details },
      );
    }
    if (missingContent.length > 0) {
      throw Object.assign(
        new Error(`Conteudo ausente: ${missingContent.join(', ')}.`),
        { details },
      );
    }
    if (route.name === 'one-piece-weekly') {
      await clickFlutterButton(page, 'Arquivos importados');
      await new Promise((resolve) => setTimeout(resolve, 500));
      await clickFlutterButton(page, 'Modo TV');
      await page.waitForFunction(
        () =>
          Array.from(document.querySelectorAll('flt-semantics')).some((item) =>
            (item.getAttribute('aria-label') || item.textContent || '').includes(
              'Fechar modo TV',
            ),
        ),
        { timeout: 30_000 },
      );
    }
    if (route.name === 'pokemon-weekly') {
      await clickFlutterButton(page, 'Modo TV');
      await page.waitForFunction(
        () =>
          Array.from(document.querySelectorAll('flt-semantics')).some((item) =>
            (item.getAttribute('aria-label') || item.textContent || '').includes(
              'Fechar modo TV Pokemon',
            ),
        ),
        { timeout: 30_000 },
      );
      await new Promise((resolve) => setTimeout(resolve, 750));
      fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
      await page.screenshot({
        path: path.join(ARTIFACTS_DIR, 'pokemon-tv-1920x1080.png'),
      });
    }
    if (route.name === 'library') {
      fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
      await page.screenshot({
        path: path.join(ARTIFACTS_DIR, 'library-prices.png'),
        fullPage: true,
      });
    }
    if (route.backTarget) {
      if (route.backCoordinates) {
        await page.mouse.click(
          route.backCoordinates.x,
          route.backCoordinates.y,
        );
      } else {
        await clickFlutterButton(
          page,
          route.backButtonLabel || 'Voltar',
        );
      }
      await page.waitForFunction(
        (expectedHash) => window.location.hash === expectedHash,
        { timeout: 30_000 },
        route.backTarget,
      );
    }
    if (actionableConsoleErrors.length > 0 || pageErrors.length > 0) {
      throw Object.assign(new Error('A pagina gerou erros no navegador.'), {
        details,
      });
    }

    console.log(`PASS ${route.name} (${response.status()}, ${route.title})`);
  } catch (error) {
    const details = error.details || {
      route: route.hash,
      url: page.url(),
      message: error.message,
      consoleErrors,
      pageErrors,
    };
    await saveFailureArtifacts(page, route.name, details);
    throw new Error(`${route.name}: ${error.message}`);
  } finally {
    await page.close();
  }
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const executablePath = findChrome();
  console.log(`E2E: ${options.baseUrl}`);
  console.log(`Chrome: ${executablePath}`);

  if (!options.skipApi) {
    await checkApis(options.baseUrl);
  }

  const browser = await puppeteer.launch({
    executablePath,
    headless: !options.headed,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });

  try {
    const routes = options.route
      ? ROUTES.filter((route) => route.name === options.route)
      : ROUTES;
    if (routes.length === 0) {
      throw new Error(`Rota E2E desconhecida: ${options.route}`);
    }
    for (const route of routes) {
      await checkRoute(browser, options.baseUrl, route);
    }
  } finally {
    await browser.close();
  }

  console.log(`E2E aprovado: ${options.route ? 1 : ROUTES.length} fluxos publicos validados.`);
}

main().catch((error) => {
  console.error(`E2E falhou: ${error.message}`);
  process.exitCode = 1;
});
