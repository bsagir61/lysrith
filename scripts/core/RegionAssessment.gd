class_name RegionAssessment
extends RefCounted
## Runtime-only assessment derived exclusively from intelligence the player has.


static func assess(region: Dictionary) -> Dictionary:
	if region.is_empty():
		return {"id": "under_observed", "text_key": "assessment.under_observed"}
	var stability: int = int(region.get("stability", 0))
	var intel_level: int = int(region.get("intel_level", 0))
	if bool(region.get("collapsed", false)) or stability <= Balance.ASSESS_CRITICAL_STABILITY_AT:
		return _result("critical", true)
	if stability < Balance.ASSESS_UNSTABLE_STABILITY_AT:
		return _result("unstable", true)
	if intel_level >= 1 and int(region.get("rival_influence", 0)) >= Balance.ASSESS_CONTESTED_RIVAL_AT:
		return _result("contested", true)
	if intel_level >= 2 and int(region.get("opportunity", 0)) >= Balance.ASSESS_PROMISING_OPPORTUNITY_AT:
		return _result("promising", false)
	if intel_level < 2:
		return _result("under_observed", false)
	if stability >= Balance.ASSESS_STABLE_STABILITY_AT and int(region.get("rival_influence", 100)) < Balance.ASSESS_STABLE_RIVAL_BELOW:
		return _result("stable", false)
	return _result("contested", false)


static func situation_key(region: Dictionary) -> String:
	if region.is_empty():
		return "region.summary.unavailable"
	var stability: int = int(region.get("stability", 0))
	var intel_level: int = int(region.get("intel_level", 0))
	if bool(region.get("collapsed", false)):
		return "region.summary.collapsed"
	if intel_level == 0:
		return "region.summary.low_stability_limited" if stability < Balance.ASSESS_UNSTABLE_STABILITY_AT else "region.summary.limited"
	var rival: int = int(region.get("rival_influence", 0))
	var surveillance: int = int(region.get("surveillance", 0))
	if rival >= Balance.ASSESS_CONTESTED_RIVAL_AT and stability < Balance.ASSESS_STABLE_STABILITY_AT:
		return "region.summary.rival_deteriorating"
	if surveillance >= Balance.ADVISOR_SURVEILLANCE_AT:
		return "region.summary.surveillance"
	if intel_level >= 2 and int(region.get("public_pressure", 0)) >= Balance.ADVISOR_PRESSURE_AT:
		return "region.summary.pressure"
	if intel_level >= 2 and int(region.get("opportunity", 0)) >= Balance.ASSESS_PROMISING_OPPORTUNITY_AT:
		return "region.summary.opportunity"
	return "region.summary.stable"


static func _result(id: String, urgent: bool) -> Dictionary:
	return {"id": id, "text_key": "assessment.%s" % id, "urgent": urgent}
