const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('puppeteer-core');

const ROOT = path.resolve(__dirname, '..');
const ARTIFACTS_DIR = path.join(ROOT, 'artifacts', 'e2e');
const DEFAULT_BASE_URL = 'https://optcgbh.vercel.app';

const ROUTES = [
  {
    name: 'home',
    hash: '#/home',
    title: 'OPTCG BH | Card games, marketplace e semanais',
    content: ['SEMANAIS STOP TCG', 'One Piece', 'Pokemon'],
  },
  {
    name: 'weeklies',
    hash: '#/weeklies',
    title: 'Semanais STOP TCG | OPTCG BH',
    content: ['Semanais STOP TCG', 'One Piece Card Game', 'Pokemon TCG'],
  },
  {
    name: 'pokemon-weekly',
    hash: '#/weeklies/pokemon',
    title: 'Semanal Pokemon | OPTCG BH',
    content: ['Semanal Pokemon', 'LIGA DE QUINTA-FEIRA', 'LIGA DE SABADO'],
  },
  {
    name: 'one-piece-weekly',
    hash: '#/weeklies/one-piece',
    title: 'Semanal One Piece | OPTCG BH',
    content: [
      'Semanal One Piece',
      'Ranking mensal dos piratas',
    ],
  },
  {
    name: 'login',
    hash: '#/login',
    title: 'Entrar | OPTCG BH',
    content: ['Entrar', 'Criar conta'],
  },
  {
    name: 'register',
    hash: '#/register',
    title: 'Criar conta | OPTCG BH',
    content: ['Criar conta'],
  },
  {
    name: 'library',
    hash: '#/library',
    title: 'Biblioteca One Piece | OPTCG BH',
    content: ['Biblioteca One Piece', 'Liga:'],
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

    const title = await page.title();
    const accessibleText = await readAccessibleText(page);
    const normalizedText = normalizeText(accessibleText);
    const ignoredLocalApiErrors = baseUrl.startsWith('http://127.0.0.1')
      ? consoleErrors.filter((error) => error.includes('/api/'))
      : [];
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
