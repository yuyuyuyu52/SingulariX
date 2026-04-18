const os = require('os');
const http = require('http');
const fs = require('fs');
const path = require('path');
const net = require('net');
const { spawn } = require('child_process');
const { randomUUID } = require('crypto');
const { Server, createWebSocketStream } = require('ws');

const START_SCRIPT = path.join(__dirname, 'start.sh');
const subtxt = path.join(process.env.HOME || os.homedir(), 'agsbx', 'jh.txt');
const NAME = process.env.NAME || os.hostname();
const PORT = process.env.PORT || 3000;
const uuid = process.env.uuid || randomUUID();
const DOMAIN = process.env.DOMAIN || 'YOUR.DOMAIN';
const vlessInfo = `vless://${uuid}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&fp=chrome&type=ws&host=${DOMAIN}&path=%2F#Vl-ws-tls-${NAME}`;
console.log(`vless-ws-tls节点分享: ${vlessInfo}`);

fs.chmod(START_SCRIPT, 0o755, (err) => {
    if (err) {
        console.error(`start.sh empowerment failed: ${err}`);
        return;
    }
    console.log(`start.sh empowerment successful`);
    const child = spawn('sh', [START_SCRIPT]);
    child.stdout.on('data', (data) => console.log(data));
    child.stderr.on('data', (data) => console.error(data));
    child.on('close', (code) => {
        console.log(`child process exited with code ${code}`);
        console.log(`App is running`);
    });
});

const server = http.createServer((req, res) => {
    if (req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('🟢恭喜！SingulariX小钢炮脚本-nodejs版部署成功！\n\n查看节点信息路径：/你的uuid');
        return;
    }

    if (req.url === `/${uuid}`) {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        if (fs.existsSync(subtxt)) {
            fs.readFile(subtxt, 'utf8', (err, data) => {
                if (err) {
                    console.error(err);
                    res.end(`${vlessInfo}`);
                } else {
                    res.end(`${vlessInfo}\n${data}`);
                }
            });
        } else {
            res.end(`${vlessInfo}`);
        }
        return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('404 Not Found');
});

server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

const wss = new Server({ server });
const uuidkey = uuid.replace(/-/g, "");
wss.on('connection', ws => {
    ws.once('message', msg => {
        const [VERSION] = msg;
        const id = msg.slice(1, 17);
        if (!id.every((v, i) => v === parseInt(uuidkey.substr(i * 2, 2), 16))) return;
        let i = msg.slice(17, 18).readUInt8() + 19;
        const port = msg.slice(i, i += 2).readUInt16BE(0);
        const ATYP = msg.slice(i, i += 1).readUInt8();
        const host = ATYP === 1 ? msg.slice(i, i += 4).join('.') :
            (ATYP === 2 ? new TextDecoder().decode(msg.slice(i + 1, i += 1 + msg.slice(i, i + 1).readUInt8())) :
                (ATYP === 3 ? msg.slice(i, i += 16)
                    .reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), [])
                    .map(b => b.readUInt16BE(0).toString(16)).join(':') : ''));
        ws.send(new Uint8Array([VERSION, 0]));
        const duplex = createWebSocketStream(ws);
        net.connect({ host, port }, function () {
            this.write(msg.slice(i));
            duplex.on('error', () => { }).pipe(this).on('error', () => { }).pipe(duplex);
        }).on('error', () => { });
    }).on('error', () => { });
});
