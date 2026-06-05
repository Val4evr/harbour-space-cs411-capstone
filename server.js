// CS411 capstone — same JSON contract as the Go service from the homework challenges
// ({"Name","Description","Url"} on :4444), re-implemented in Node.js with no framework.
// Plain node:http keeps the image small and the dependency surface zero.
const http = require('http');

const PORT = process.env.PORT || 4444;

const server = http.createServer((req, res) => {
  // Health endpoint for container/k8s probes — cheap, no JSON marshalling.
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok\n');
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    Name: 'Hello',
    Description: 'World',
    Url: req.headers.host || `localhost:${PORT}`,
  }) + '\n');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server started on port ${PORT}`);
});

// Containers stop with SIGTERM; without this handler node would be killed hard
// after docker's 10s grace period instead of closing the listener cleanly.
process.on('SIGTERM', () => server.close(() => process.exit(0)));
