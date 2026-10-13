# Ground contact dust

`Scripts/player_ground_dust.gd` supplies the same short, world-anchored dust
bursts for the local avatar and remote movement snapshots. Only a real takeoff
or a downward landing emits dust; spawning, teleports, idle floor jitter,
swimming, noclip and death do not. Remote bursts wait for the avatar's
interpolation delay. The effect caps particles and stops processing when empty.

Dust uses avatar-relative layer 20. Layer 5 could leave the front foot's
equipment or split trouser leg above the cloud while dust covered the rear
foot. Layer 20 covers both lower legs, including shoes and pants, and remains
below the torso's authored layer 30. It does not change avatar sprite ordering.

Verification:

- `tests/player_ground_dust_test.gd` drives actual floor collisions and the
  remote snapshot handler, including held jump, air jump, water, teleport,
  repeated snapshots, world anchoring and cleanup.
- `tests/player_ground_dust_render_test.gd` uses the main scene's foot placement
  with equipped shoes and checks rendered dust coverage over each foot while
  facing left and right at two points in the landing burst. Run with a rendered
  viewport, using either Mobile or GL Compatibility. The optional user argument
  `--old-dust-layer` reproduces the original layer and should fail the front
  shoe coverage check.
