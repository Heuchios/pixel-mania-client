const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const godot = process.env.GODOT_BIN || path.resolve(root, '../Godot/Godot_v4.7.1-stable_win64_console.exe');
const output = process.env.PERF_OUTPUT_DIR || path.join(root, 'tmp/runtime-regressions');
fs.mkdirSync(output, { recursive: true });
const tests = process.argv.slice(2);
if (!tests.length) tests.push('runtime_performance_probe', 'break_sync_test', 'snow_storm_event_delivery_test',
  'block_placement_reconciliation_test', 'authoritative_special_block_prediction_test',
  'mobile_single_tap_input_test', 'mobile_controls_layout_test', 'websocket_snapshot_buffer_test',
  'network_batch_protocol_test', 'inventory_incremental_refresh_test', 'world_rejoin_visual_reconciliation_test',
  'event_queue_latency_test', 'chunk_edit_performance_test', 'runtime_profiler_test', 'block_break_renderer_test',
  'corner_contact_test', 'mobile_inventory_layout_test', 'mobile_punch_reach_test', 'mobile_zoom_test', 'device_ui_scaling_test',
  'seed_prediction_test', 'growing_tree_break_hits_test', 'remote_equipment_performance_test', 'movement_encoding_probe');
let failed = 0;
for (const test of tests) {
  const result = spawnSync(godot, ['--headless', '--path', root, '--log-file', path.join(output, `${test}-engine.log`),
    '--script', `res://tests/${test}.gd`, '--', '--check-only'], { cwd: root, encoding: 'utf8', timeout: 60000, windowsHide: true });
  const log = `${result.stdout || ''}${result.stderr || ''}`;
  fs.writeFileSync(path.join(output, `${test}.log`), log);
  const ok = result.status === 0 && !/SCRIPT ERROR:|Assertion failed|Failed to load script/.test(log);
  if (!ok) failed++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${test}${result.error ? `: ${result.error.message}` : ''}`);
  if (!ok) console.log(log.slice(-2500));
}
process.exitCode = failed ? 1 : 0;
