extends Node
## Balance.gd - every tuning constant for LYSRITH lives here.
## Nothing outside this file should hardcode balance numbers.

# ---------- Difficulty ----------
enum Difficulty { ROOKIE, STANDARD, BLACK_ROOM }

const DIFFICULTY_NAMES: Array[String] = ["Rookie Desk", "Standard Watch", "Black Room"]
const DIFFICULTY_DESCS: Array[String] = [
	"Forgiving. More funds, slower exposure, gentler events.",
	"The intended experience. Balanced pressure.",
	"Unforgiving. Thin resources, fast rival spread, harsh failures.",
]

# Per-difficulty tables indexed by Difficulty enum.
const START_FUNDS: Array[int] = [140, 100, 70]
const START_INTEL: Array[int] = [25, 20, 12]
const START_TRUST: Array[int] = [75, 70, 60]
const START_HEAT: Array[int] = [5, 10, 15]
const START_COVER: Array[int] = [35, 30, 20]
const CHANCE_MOD: Array[int] = [8, 0, -8]              # flat success chance modifier
const EXPOSURE_RATE: Array[float] = [0.7, 1.0, 1.25]   # global exposure growth multiplier
const RIVAL_SPREAD_RATE: Array[float] = [0.8, 1.0, 1.4]
const HEAT_PENALTY_RATE: Array[float] = [0.8, 1.0, 1.3]
const EVENT_SEVERITY: Array[float] = [0.7, 1.0, 1.2]   # scales negative event effects
const FAIL_PENALTY_RATE: Array[float] = [0.75, 1.0, 1.25]

# ---------- Success chance formula weights ----------
const W_SKILL: float = 4.0          # per skill point (1..10)
const W_FATIGUE: float = 0.35       # per fatigue point (0..100)
const W_SURVEILLANCE: float = 0.22  # per surveillance point, covert ops only
const W_RIVAL: float = 0.15         # per rival influence point, covert ops only
const W_NETWORK: float = 0.22       # per local network point
const W_INTEL_LEVEL: float = 5.0    # per region intel level (0..3)
const CHANCE_MIN: int = 5
const CHANCE_MAX: int = 95

# ---------- UI warning thresholds ----------
const UI_TRUST_DANGER_AT: int = 25
const UI_HEAT_WARNING_AT: int = 60
const UI_HEAT_DANGER_AT: int = 80
const UI_GLOBAL_EXPOSURE_DANGER_AT: int = 70
const UI_COLLAPSED_DANGER_AT: int = 3
const UI_RIVAL_MOMENTUM_WARNING_AT: int = 70

# ---------- Operation risk thresholds ----------
const RISK_FAVORABLE_MIN: int = 75
const RISK_UNCERTAIN_MIN: int = 55
const RISK_RISKY_MIN: int = 35
const CONFIRM_CHANCE_BELOW: int = 35
const CONFIRM_HEAT_AT: int = 80
const CONFIRM_TRUST_AT: int = 10
const AGENT_EXHAUSTED_FATIGUE: int = 90

# Trait modifiers
const TRAIT_EXPENSIVE_CHANCE: int = 10
const TRAIT_EXPENSIVE_COST_MULT: float = 1.5
const TRAIT_RISK_AVERSE_CHANCE: int = 8
const TRAIT_RISK_AVERSE_EFFECT_MULT: float = 0.8
const TRAIT_LOW_PROFILE_HEAT_MULT: float = 0.6
const TRAIT_FAST_ANALYST_INTEL_MULT: float = 1.35
const TRAIT_CALM_FAIL_MULT: float = 0.7
const TRAIT_UNSTABLE_EFFECT_MULT: float = 1.25
const TRAIT_UNSTABLE_EVENT_BONUS: float = 0.12

# ---------- Region identity modifiers ----------
# Modifier order is enforced in TurnResolver:
# chance: base -> skill -> fatigue -> network -> intel -> local penalties ->
# difficulty -> agent trait -> region identity -> clamp.
# effect: base -> agent trait -> region identity -> near miss -> round -> clamp.
# cost: base -> agent trait -> region identity -> round -> positive minimum.
# Heat: base -> difficulty -> agent trait -> region identity -> round.
const TAG_TRADE_HUB_INCOME: int = 2
const TAG_TRADE_HUB_INCOME_CAP: int = 6
const TAG_MEDIA_REDUCE_HEAT_MULT: float = 1.25
const TAG_BORDER_EFFECT_MULT: float = 1.15
const TAG_RESEARCH_MAP_INTEL_MULT: float = 1.25
const TAG_RESEARCH_DEEP_INTEL_DISCOUNT: int = 2
const TAG_FINANCIAL_FUNDS_MULT: float = 0.85
const TAG_CIVIL_STABILITY_MULT: float = 1.20
const TAG_CIVIL_PRESSURE_MULT: float = 1.15
const TAG_SIGNAL_TRACE_CHANCE: int = 8
const TAG_SIGNAL_MAP_CHANCE: int = 4
const TAG_OLD_ALLIANCE_TRUST_MULT: float = 1.25
const TAG_OLD_ALLIANCE_STABILIZE_CHANCE: int = 4
const TAG_BLACK_MARKET_NETWORK_MULT: float = 1.25
const TAG_BLACK_MARKET_HEAT: int = 2
const TAG_DIPLOMATIC_CHANCE: int = 6
const TAG_DIPLOMATIC_AUDIT_FUNDS_DISCOUNT: int = 2
const TAG_DISCOVERY_INTEL_REWARD: int = 2
const MIN_POSITIVE_COST: int = 1

# ---------- Region assessment / advisor ----------
const ASSESS_CRITICAL_STABILITY_AT: int = 25
const ASSESS_UNSTABLE_STABILITY_AT: int = 45
const ASSESS_CONTESTED_RIVAL_AT: int = 60
const ASSESS_PROMISING_OPPORTUNITY_AT: int = 65
const ASSESS_STABLE_STABILITY_AT: int = 65
const ASSESS_STABLE_RIVAL_BELOW: int = 40
const ADVISOR_STABILITY_AT: int = 45
const ADVISOR_RIVAL_AT: int = 55
const ADVISOR_SURVEILLANCE_AT: int = 60
const ADVISOR_PRESSURE_AT: int = 60
const ADVISOR_LOW_NETWORK_BELOW: int = 35
const ADVISOR_TRACE_NETWORK_AT: int = 50
const ADVISOR_HIGH_HEAT_AT: int = 60
const ADVISOR_MAX_RECOMMENDATIONS: int = 3
const OUTLOOK_ACTIVITY_MODERATE_AT: int = 35
const OUTLOOK_ACTIVITY_HIGH_AT: int = 70

# ---------- Operation effect magnitudes ----------
const OP_MAP_SIGNALS_INTEL: int = 8
const OP_BUILD_NETWORK_GAIN: int = 22
const OP_COUNTER_INFLUENCE_REDUCE: int = 20
const OP_STABILIZE_GAIN: int = 18
const OP_STABILIZE_PRESSURE_CUT: int = 12
const OP_REDUCE_HEAT_AMOUNT: int = 16
const OP_REDUCE_HEAT_COVER: int = 6
const OP_TRACE_EXPOSURE_BASE: int = 12
const OP_TRACE_EXPOSURE_NETWORK_BONUS: float = 0.08  # + local_network * this
const OP_TRACE_RIVAL_CUT: int = 8
const OP_CONTAIN_STABILITY: int = 30
const OP_CONTAIN_RIVAL_CUT: int = 12
const OP_QUIET_AUDIT_TRUST: int = 8
const OP_QUIET_AUDIT_PRESSURE_CUT: int = 15
const OP_FAIL_STABILITY_HIT: int = 6
const OP_FAIL_HEAT_BONUS: int = 5
const OP_FAIL_TRUST_HIT: int = 3
const OP_FAIL_COVER_ABSORB: int = 8   # cover spent to soften a failure
const OP_PARTIAL_EFFECT_MULT: float = 0.4  # near-miss keeps a little value

# ---------- Turn upkeep ----------
const BASE_INCOME: int = 8
const INCOME_TRUST_DIVISOR: int = 12       # + trust / this
const AGENT_UPKEEP: int = 2                # per agent per turn
const HEAT_DECAY_PER_TURN: int = 2
const FATIGUE_RECOVERY_PER_TURN: int = 8   # for agents that did not act
const FATIGUE_STRAINED_THRESHOLD: int = 75

# Global exposure growth: heat/HEAT_TO_EXPOSURE + momentum/MOMENTUM_TO_EXPOSURE per turn.
const HEAT_TO_EXPOSURE: float = 22.0
const MOMENTUM_TO_EXPOSURE: float = 30.0
const COLLAPSE_EXPOSURE_SPIKE: int = 8

# Rival behavior
const RIVAL_MOMENTUM_START: int = 20
const RIVAL_MOMENTUM_GROWTH: float = 1.2       # per turn
const RIVAL_MOMENTUM_MAX: int = 100
const RIVAL_SPREAD_TARGETS: int = 2            # regions touched per turn
const RIVAL_SPREAD_BASE: float = 4.0           # influence added, scaled by momentum
const RIVAL_STABILITY_EROSION_THRESHOLD: int = 55  # rival influence above this erodes stability
const RIVAL_STABILITY_EROSION: int = 4
const RIVAL_PRESSURE_GAIN: int = 3

# Region collapse
const COLLAPSE_STABILITY_THRESHOLD: int = 1    # stability below this -> collapse
const COLLAPSE_LIMIT: int = 5                  # loss condition
const COLLAPSE_NEIGHBOR_STABILITY_HIT: int = 6

# ---------- Events ----------
const EVENT_BASE_CHANCE: float = 0.30
const EVENT_HEAT_FACTOR: float = 0.004         # + heat * this
const EVENT_CHANCE_MAX: float = 0.65
const EVENT_COOLDOWN_TURNS: int = 6            # same event cannot repeat within this window

# ---------- Win / loss ----------
const WIN_RIVAL_EXPOSURE: int = 100
const LOSS_GLOBAL_EXPOSURE: int = 100
const LOSS_TRUST: int = 0

# ---------- Agents ----------
const XP_SUCCESS: int = 8
const XP_FAIL: int = 4
const XP_PER_LEVEL: int = 30
const LEVEL_MAX: int = 5
const SKILL_MAX: int = 10

# ---------- Region generation ----------
const GEN_STABILITY_MIN: int = 45
const GEN_STABILITY_MAX: int = 85
const GEN_SURVEILLANCE_MIN: int = 15
const GEN_SURVEILLANCE_MAX: int = 65
const GEN_RIVAL_MIN: int = 5
const GEN_RIVAL_MAX: int = 40
const GEN_PRESSURE_MIN: int = 10
const GEN_PRESSURE_MAX: int = 45
const GEN_OPPORTUNITY_MIN: int = 20
const GEN_OPPORTUNITY_MAX: int = 80
const GEN_SEED_RIVAL_HOTSPOTS: int = 3         # regions that start with elevated rival influence
const GEN_HOTSPOT_RIVAL_BONUS: int = 25


func difficulty_name(d: int) -> String:
	return DIFFICULTY_NAMES[clampi(d, 0, 2)]
