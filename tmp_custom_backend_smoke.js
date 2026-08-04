const WebSocket = require('ws');

const PORT = 18080;
const ws = new WebSocket(`ws://127.0.0.1:${PORT}`);
const profile = `DevTest_${Date.now() % 100000}`;
const toLog = [];

function send(payload) {
  const text = JSON.stringify(payload);
  console.log('SEND', text);
  ws.send(text);
}

function onMessage(event) {
  try {
    const data = JSON.parse(event.data);
    const t = data.type || data.action || 'unknown';
    console.log('RECV', t, data);

    if (data.type === 'account_auth_ok' && data.action === 'dev_backend_login') {
      send({
        type: 'custom_trusted_player_state',
        request_id: 'trust-1',
        movement_mode: 'CUSTOM_AUTHORITATIVE',
        world: 'NETFOX_TEST',
        world_id: 'NETFOX_TEST',
        x: 320,
        y: 350,
        velocity_x: 0,
        velocity_y: 0,
        facing: 1,
        peer_id: 111,
        tick: 1,
        player_node_path: '/root/local',
      });
      setTimeout(() => {
        send({
          type: 'world_block_update',
          request_id: 'block-1',
          action: 'place',
          layer: 'foreground',
          x: 32,
          y: 10,
          block_type: 'dirt',
          world: 'NETFOX_TEST',
          action_source: 'smoke-test',
        });
      }, 200);
    }

    if (data.type === 'world_update' || data.type === 'world_block_update' || data.type === 'action_rejected') {
      process.exit(0);
    }
  } catch (error) {
    console.error('parse-error', error.message);
  }
}

ws.on('open', () => {
  console.log('OPEN');
  send({
    type: 'dev_backend_login',
    request_id: 'login-1',
    username: profile,
    world: 'NETFOX_TEST',
    client_platform: 'smoke',
    client_version: '1.0.1',
  });
});

ws.on('message', onMessage);
ws.on('error', (error) => {
  console.error('SOCK_ERROR', error.message);
  process.exit(1);
});
ws.on('close', (code, reason) => {
  console.log('CLOSE', code, reason.toString());
  process.exit(0);
});

setTimeout(() => {
  console.error('TIMEOUT waiting for world update/reject');
  process.exit(1);
}, 7000);
