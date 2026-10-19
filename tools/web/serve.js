// Servidor estático mínimo para testar a exportação Web localmente:
//   node tools/web/serve.js [pasta] [porta]   (padrão: build/web 8089)
const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve(process.argv[2] || 'build/web');
const port = Number(process.argv[3] || 8089);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
http.createServer((req, res) => {
  const file = path.join(root, req.url.split('?')[0] === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end('404'); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(res);
}).listen(port, () => console.log(`servindo ${root} em http://localhost:${port}`));
