extends RefCounted

# All deadlines use the local monotonic clock. No wall-clock synchronization is
# required, and missed application probes are not labeled TCP packet loss.
const CONNECT_TIMEOUT_MS := 15000
const AUTH_TIMEOUT_MS := 20000
const HEARTBEAT_INTERVAL_MS := 5000
const HEARTBEAT_TIMEOUT_MS := 30000
const MAX_RETRY_SECONDS := 30.0

var phase := "DISCONNECTED"
var phase_started_ms := 0
var next_ping_ms := 0
var pending_ping_id := ""
var pending_ping_ms := 0
var retry_attempt := 0
var rtt_ms := 0.0
var smoothed_rtt_ms := 0.0
var jitter_ms := 0.0
var pong_samples := 0
var missed_probes := 0

func start_attempt(now: int) -> void:
	phase = "CONNECTING"
	phase_started_ms = now
	reset_probe(now)
	rtt_ms = 0.0
	smoothed_rtt_ms = 0.0
	jitter_ms = 0.0
	pong_samples = 0

func opened(now: int) -> void:
	phase = "CONNECTED"
	phase_started_ms = now
	reset_probe(now)

func authenticating(now: int) -> void:
	if phase != "AUTHENTICATING":
		phase = "AUTHENTICATING"
		phase_started_ms = now

func authenticated(now: int) -> void:
	opened(now)
	retry_attempt = 0

func reset_probe(now: int) -> void:
	pending_ping_id = ""
	pending_ping_ms = 0
	next_ping_ms = now

func ping_due(now: int) -> bool:
	return pending_ping_id == "" and now >= next_ping_ms

func sent_ping(id: String, now: int) -> void:
	pending_ping_id = id
	pending_ping_ms = now
	next_ping_ms = now + HEARTBEAT_INTERVAL_MS

func received_pong(id: String, now: int) -> bool:
	if id == "" or id != pending_ping_id:
		return false
	var sample := float(maxi(0, now - pending_ping_ms))
	if pong_samples > 0:
		jitter_ms = lerpf(jitter_ms, absf(sample - rtt_ms), 0.2)
		smoothed_rtt_ms = lerpf(smoothed_rtt_ms, sample, 0.2)
	else:
		smoothed_rtt_ms = sample
	rtt_ms = sample
	pong_samples += 1
	pending_ping_id = ""
	return true

func timeout_reason(now: int) -> String:
	if phase == "CONNECTING" and now - phase_started_ms >= CONNECT_TIMEOUT_MS:
		return "connect_timeout"
	if phase == "AUTHENTICATING" and now - phase_started_ms >= AUTH_TIMEOUT_MS:
		return "authentication_timeout"
	if pending_ping_id != "" and now - pending_ping_ms >= HEARTBEAT_TIMEOUT_MS:
		return "heartbeat_timeout"
	return ""

func retry_delay_seconds(jitter_factor: float = 1.0) -> float:
	var delay := minf(MAX_RETRY_SECONDS, pow(2.0, mini(retry_attempt, 5)))
	retry_attempt += 1
	return minf(MAX_RETRY_SECONDS, delay * clampf(jitter_factor, 0.8, 1.2))
