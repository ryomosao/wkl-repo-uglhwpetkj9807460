const http = require('http');

const PORT = process.env.PORT || 80;

const server = http.createServer((req, res) => {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // Default route
    if (req.url === '/' || req.url === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Simple Node.js App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: #000;
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            text-align: center;
            max-width: 600px;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            font-weight: 300;
        }
        p {
            font-size: 1.2rem;
            color: #ccc;
            margin-bottom: 2rem;
        }
        .info {
            background: #111;
            padding: 2rem;
            border-radius: 8px;
            margin-top: 2rem;
        }
        .info-item {
            margin: 1rem 0;
            padding: 0.5rem;
            border-bottom: 1px solid #222;
        }
        .info-item:last-child {
            border-bottom: none;
        }
        .label {
            color: #888;
            font-size: 0.9rem;
        }
        .value {
            color: #fff;
            font-size: 1.1rem;
            margin-top: 0.3rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Simple Node.js Application</h1>
        <p>Running in a Docker container on Azure App Service</p>
        <div class="info">
            <div class="info-item">
                <div class="label">Server</div>
                <div class="value">Node.js ${process.version}</div>
            </div>
            <div class="info-item">
                <div class="label">Port</div>
                <div class="value">${PORT}</div>
            </div>
            <div class="info-item">
                <div class="label">Platform</div>
                <div class="value">${process.platform}</div>
            </div>
            <div class="info-item">
                <div class="label">Uptime</div>
                <div class="value">${Math.floor(process.uptime())} seconds</div>
            </div>
        </div>
    </div>
</body>
</html>
        `);
    } else if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
            status: 'healthy', 
            timestamp: new Date().toISOString(),
            uptime: process.uptime()
        }));
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Node.js version: ${process.version}`);
});

