const WebSocket = require('ws');

const socket = new WebSocket('ws://127.0.0.1:8080/client-ws');

socket.on('open', () => {
  console.log('Mock Roblox client connected to Helper Server.');
});

socket.on('message', (data) => {
  console.log('Received message:', data.toString());
  try {
    const msg = JSON.parse(data.toString());
    const response = { id: msg.id };
    
    if (msg.action === 'get_children') {
      if (msg.path === 'game') {
        response.ok = true;
        response.children = [
          { Name: 'Workspace', ClassName: 'Workspace', Path: 'game.Workspace', HasChildren: true },
          { Name: 'Players', ClassName: 'Players', Path: 'game.Players', HasChildren: true }
        ];
      } else if (msg.path === 'game.Workspace') {
        response.ok = true;
        response.children = [
          { Name: 'Baseplate', ClassName: 'Part', Path: 'game.Workspace.Baseplate', HasChildren: false },
          { Name: 'Camera', ClassName: 'Camera', Path: 'game.Workspace.Camera', HasChildren: false }
        ];
      } else if (msg.path === 'game.Players') {
        response.ok = true;
        response.children = [
          { Name: 'LocalPlayer', ClassName: 'Player', Path: 'game.Players.LocalPlayer', HasChildren: true }
        ];
      } else {
        response.ok = true;
        response.children = [];
      }
    } else if (msg.action === 'get_properties') {
      response.ok = true;
      response.properties = [
        { Name: 'Name', Value: msg.path.split('.').pop(), Type: 'string' },
        { Name: 'ClassName', Value: 'Part', Type: 'string' },
        { Name: 'Parent', Value: 'Workspace', Type: 'string' },
        { Name: 'Archivable', Value: 'true', Type: 'boolean' },
        { Name: 'Size', Value: '2048, 16, 2048', Type: 'Vector3' },
        { Name: 'Color', Value: '163, 162, 165', Type: 'Color3' }
      ];
    } else if (msg.action === 'set_property') {
      response.ok = true;
      console.log(`Set property ${msg.name} on ${msg.path} to ${msg.value}`);
    } else if (msg.action === 'run_script') {
      response.ok = true;
      console.log(`Executing code in context ${msg.path}:\n${msg.source}`);
    }
    
    socket.send(JSON.stringify(response));
    console.log('Sent response:', JSON.stringify(response));
  } catch (e) {
    console.error('Error handling message:', e);
  }
});

socket.on('close', () => {
  console.log('Connection closed.');
});

socket.on('error', (err) => {
  console.error('Socket error:', err);
});
