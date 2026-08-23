import {createReadStream} from 'node:fs';
import {stat} from 'node:fs/promises';
import {createServer, request as createProxyRequest} from 'node:http';
import {extname, join, normalize, resolve} from 'node:path';

const root = '/demo/current';
const port = 8080;
const contentTypes = new Map([
  ['.css', 'text/css; charset=utf-8'],
  ['.html', 'text/html; charset=utf-8'],
  ['.ico', 'image/x-icon'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.svg', 'image/svg+xml'],
  ['.txt', 'text/plain; charset=utf-8'],
  ['.webmanifest', 'application/manifest+json; charset=utf-8'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
]);

function proxyApi(request, response) {
  const upstream = createProxyRequest(
    {
      hostname: 'doubtfire-api',
      port: 3000,
      method: request.method,
      path: request.url,
      headers: {...request.headers, host: request.headers.host},
    },
    (upstreamResponse) => {
      response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
      upstreamResponse.pipe(response);
    },
  );

  upstream.on('error', () => {
    response.writeHead(502, {'content-type': 'text/plain; charset=utf-8'});
    response.end('The OnTrack API is unavailable.');
  });
  request.pipe(upstream);
}

async function staticPath(pathname) {
  const decoded = decodeURIComponent(pathname);
  const candidate = resolve(root, `.${normalize(decoded)}`);
  if (candidate !== root && !candidate.startsWith(`${root}/`)) {
    return null;
  }

  try {
    const details = await stat(candidate);
    return details.isDirectory() ? join(candidate, 'index.html') : candidate;
  } catch {
    return join(root, 'index.html');
  }
}

createServer(async (request, response) => {
  const url = new URL(request.url ?? '/', 'http://localhost');
  if (url.pathname.startsWith('/api/')) {
    proxyApi(request, response);
    return;
  }

  const file = await staticPath(url.pathname);
  if (!file) {
    response.writeHead(400, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Invalid path.');
    return;
  }

  try {
    const details = await stat(file);
    response.writeHead(200, {
      'cache-control': 'no-cache',
      'content-length': details.size,
      'content-type': contentTypes.get(extname(file)) ?? 'application/octet-stream',
    });
    if (request.method === 'HEAD') {
      response.end();
    } else {
      createReadStream(file).pipe(response);
    }
  } catch {
    response.writeHead(404, {'content-type': 'text/plain; charset=utf-8'});
    response.end('Not found.');
  }
}).listen(port, '0.0.0.0', () => {
  process.stdout.write(`PWA update demo listening on ${port}\n`);
});
