const WebSocket = require('ws');

console.log('Connecting to dashboard-ws...');
const ws = new WebSocket('ws://localhost:8080/dashboard-ws');

ws.on('open', () => {
  console.log('Connected to dashboard-ws successfully!');
  // Let's send a request
  const req = {
    id: 'test_1',
    action: 'get_children',
    path: 'game'
  };
  ws.send(JSON.stringify(req));
  console.log('Sent get_children request.');
});

ws.on('message', (data) => {
  console.log('Received message:', data.toString());
});

ws.on('close', (code, reason) => {
  console.log(`Connection closed: code=${code}, reason=${reason}`);
});

ws.on('error', (err) => {
  console.error('WS Error:', err);
});
