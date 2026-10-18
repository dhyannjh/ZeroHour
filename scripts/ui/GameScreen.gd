extends Control
const Flow = preload("res://scripts/system/ChallengeFlow.gd")
const Radar = preload("res://scripts/ui/RadarDisplay.gd")
const BG=Color("#050a12")
const PANEL=Color("#0b1421")
const LINE=Color("#20364a")
const TEXT=Color("#e8f3fa")
const MUTED=Color("#8ba2b5")
const CYAN=Color("#6af0d0")
const AMBER=Color("#ffbb62")
const RED=Color("#ff5d72")
const GRACE_SECONDS=6.0

class PerkBadge extends Control:
	var perk_id := ""
	func set_perk(value: String) -> void:
		perk_id = value
		queue_redraw()
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.43
		var accent := Color("#6af0d0")
		if perk_id == "time_buffer":
			accent = Color("#ffbb62")
		elif perk_id == "signal_scrubber":
			accent = Color("#ff5d72")
		elif perk_id == "ghost_protocol":
			accent = Color("#bd8cff")
		elif perk_id == "cache_spike":
			accent = Color("#ffd166")
		draw_circle(center, radius, Color("#0a1420"))
		draw_arc(center, radius, 0.0, TAU, 48, accent, 2.0, true)
		draw_arc(center, radius * 0.72, 0.0, TAU, 36, accent * 0.28, 1.0, true)
		match perk_id:
			"intel_ping":
				draw_arc(center, radius * 0.42, 0.0, TAU, 24, accent, 1.8, true)
				draw_line(center + Vector2(0, -radius * 0.66), center + Vector2(0, radius * 0.66), accent, 1.5, true)
				draw_line(center + Vector2(-radius * 0.66, 0), center + Vector2(radius * 0.66, 0), accent, 1.5, true)
			"time_buffer":
				draw_line(center + Vector2(-radius * 0.34, -radius * 0.58), center + Vector2(radius * 0.34, -radius * 0.58), accent, 2.0, true)
				draw_line(center + Vector2(-radius * 0.34, radius * 0.58), center + Vector2(radius * 0.34, radius * 0.58), accent, 2.0, true)
				draw_line(center + Vector2(-radius * 0.30, -radius * 0.50), center + Vector2(radius * 0.26, 0), accent, 1.8, true)
				draw_line(center + Vector2(radius * 0.26, 0), center + Vector2(-radius * 0.30, radius * 0.50), accent, 1.8, true)
				draw_line(center + Vector2(radius * 0.30, -radius * 0.50), center + Vector2(-radius * 0.26, 0), accent, 1.8, true)
				draw_line(center + Vector2(-radius * 0.26, 0), center + Vector2(radius * 0.30, radius * 0.50), accent, 1.8, true)
			"signal_scrubber":
				for row in range(3):
					var y := center.y + float(row - 1) * radius * 0.32
					draw_line(Vector2(center.x - radius * 0.58, y), Vector2(center.x - radius * 0.20, y), accent, 1.8, true)
					draw_line(Vector2(center.x - radius * 0.20, y), Vector2(center.x, y - radius * 0.16), accent, 1.8, true)
					draw_line(Vector2(center.x, y - radius * 0.16), Vector2(center.x + radius * 0.20, y + radius * 0.16), accent, 1.8, true)
					draw_line(Vector2(center.x + radius * 0.20, y + radius * 0.16), Vector2(center.x + radius * 0.58, y), accent, 1.8, true)
			"ghost_protocol":
				draw_arc(center, radius * 0.48, -PI * 0.82, PI * 0.82, 28, accent, 2.0, true)
				draw_line(center + Vector2(0, -radius * 0.45), center + Vector2(0, radius * 0.45), accent, 2.0, true)
			"cache_spike":
				var spike := PackedVector2Array([center + Vector2(0, -radius * 0.58), center + Vector2(radius * 0.14, -radius * 0.12), center + Vector2(radius * 0.50, -radius * 0.12), center + Vector2(radius * 0.20, radius * 0.12), center + Vector2(radius * 0.30, radius * 0.50), center, center + Vector2(-radius * 0.30, radius * 0.50), center + Vector2(-radius * 0.20, radius * 0.12), center + Vector2(-radius * 0.50, -radius * 0.12), center + Vector2(-radius * 0.14, -radius * 0.12)])
				draw_colored_polygon(spike, accent)
var flow=Flow.new()
var timer:Timer
var meter:ProgressBar
var risk_value:Label
var risk_band_label:Label
var risk_odds:Label
var hud_depth:Label
var hud_score:Label
var hud_credits:Label
var screen_root:Control
var intro:VBoxContainer
var instructions:VBoxContainer
var stats_screen:VBoxContainer
var armory:VBoxContainer
var boss_briefing:VBoxContainer
var challenge:VBoxContainer
var decision:VBoxContainer
var results:VBoxContainer
var challenge_header:Label
var prompt:Label
var answer:LineEdit
var clock_label:Label
var challenge_status:Label
var decision_text:Label
var decision_outcome:Label
var decision_status:Label
var decision_banner:PanelContainer
var results_text:Label
var radar:Control
var memory_phase=false
var memory_response_prompt=""
var base_limit=12.0
var timer_exposure_band := ""
var challenge_resolved=false
var displayed_risk_band=""
var screen_panels:Array[Control]=[]
var mission_kicker:Label
var screen_title:Label
var scanline:ColorRect
var audio_player:AudioStreamPlayer
var audio_playback
var backdrop:Control
var ping_samples:=PackedVector2Array()
var displayed_risk=-1.0
var displayed_risk_integer=-1
var displayed_depth=-1
var displayed_score=-1
var displayed_credits=-1
var displayed_clock_seconds=-1
var displayed_clock_text=""
var displayed_clock_phase=-1
var boss_is_active := false
var armory_balance:Label
var purchase_feedback:Label
var purchase_labels:Dictionary={}
var armory_stock_labels:Dictionary={}
var armory_buy_buttons:Dictionary={}
var perk_bar:HFlowContainer
var perk_feedback:Label
var perk_use_buttons:Dictionary={}
var perk_count_labels:Dictionary={}
var perk_badges:Dictionary={}
var used_perks_this_challenge:Dictionary={}

func _ready():
	_setup_audio()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	add_child(flow)
	timer=Timer.new()
	timer.one_shot=true
	add_child(timer)
	timer.timeout.connect(_timeout)
	GameManager.state_changed.connect(_refresh)
	_show_panel(intro)
	_update_risk()

func _process(delta):
	if scanline:
		scanline.position.y=fposmod(scanline.position.y+delta*42.0,maxf(size.y,1.0))
	if GameManager.game_state=="playing" and timer:
		GameManager.advance_risk(delta)
		_update_risk()
		var current_band := str(GameManager.get_detection_profile().get("band", "GREEN"))
		if not memory_phase and current_band != timer_exposure_band and not challenge_resolved:
			timer_exposure_band = current_band
			base_limit = flow.sync_time_to_exposure()
			var elapsed := float(Time.get_ticks_msec() - flow.question_start_time) / 1000.0
			var remaining := maxf(base_limit + GRACE_SECONDS - elapsed, 0.01)
			timer.start(remaining)
			challenge_status.text="EXPOSURE %s  /  TIMER ADJUSTED TO %d SEC" % [current_band, int(base_limit)]
		if not memory_phase:
			var rem=timer.time_left
			if rem>GRACE_SECONDS:
				var seconds=int(ceil(rem-GRACE_SECONDS))
				if displayed_clock_phase!=0 or displayed_clock_seconds!=seconds:
					displayed_clock_seconds=seconds
					displayed_clock_text="%02d" % seconds
					clock_label.text=displayed_clock_text
				if displayed_clock_phase!=0:
					clock_label.add_theme_color_override("font_color",CYAN)
					displayed_clock_phase=0
			else:
				# Retain the original formatter's rounding at tenth-second boundaries.
				var clock_text="+%.1f" % (GRACE_SECONDS-rem)
				if displayed_clock_text!=clock_text:
					displayed_clock_text=clock_text
					clock_label.text=clock_text
				if displayed_clock_phase!=1:
					clock_label.add_theme_color_override("font_color",RED)
					challenge_status.text="OVERTIME  /  signal exposure rising +1.0% per second"
					displayed_clock_phase=1

func _build_ui():
	var bg=preload("res://scripts/ui/DynamicBackdrop.gd").new()
	backdrop=bg
	bg.name="DynamicBackdrop"
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var outer=MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left",24)
	outer.add_theme_constant_override("margin_right",24)
	outer.add_theme_constant_override("margin_top",14)
	outer.add_theme_constant_override("margin_bottom",14)
	add_child(outer)
	var shell=VBoxContainer.new()
	shell.add_theme_constant_override("separation",8)
	outer.add_child(shell)
	_build_header(shell)
	var div=ColorRect.new()
	div.color=LINE
	div.custom_minimum_size.y=1
	shell.add_child(div)
	var cols=HBoxContainer.new()
	cols.size_flags_vertical=Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation",14)
	shell.add_child(cols)
	var main=VBoxContainer.new()
	main.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	main.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation",10)
	cols.add_child(main)
	_build_stage(main)
	_build_sidebar(cols)
	_build_footer(shell)

func _build_header(parent):
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var brand=VBoxContainer.new()
	brand.custom_minimum_size.x=190
	brand.add_theme_constant_override("separation",0)
	row.add_child(brand)
	brand.add_child(_label("ZERO//HOUR",25,TEXT))
	brand.add_child(_label("COVERT NETWORK OPERATIONS",9,CYAN))
	var gap=Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	hud_depth=_label("DEPTH  --",10,TEXT)
	hud_depth.custom_minimum_size.x=88
	hud_score=_label("SCORE  000000",10,TEXT)
	hud_score.custom_minimum_size.x=112
	hud_credits=_label("CREDITS  000",10,TEXT)
	hud_credits.custom_minimum_size.x=112
	row.add_child(_chip(hud_depth))
	row.add_child(_chip(hud_score))
	row.add_child(_chip(hud_credits))
	var live=_label("SYSTEM LIVE",10,CYAN)
	live.custom_minimum_size.x=88
	row.add_child(live)

func _build_stage(parent):
	mission_kicker=_label("MISSION CONTROL   /   BRIEFING",10,CYAN)
	parent.add_child(mission_kicker)
	var card=_panel(PANEL,LINE,12)
	card.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var inset=MarginContainer.new()
	for k in ["margin_left","margin_right"]:
		inset.add_theme_constant_override(k,25)
	inset.add_theme_constant_override("margin_top",22)
	inset.add_theme_constant_override("margin_bottom",22)
	card.add_child(inset)
	screen_root=Control.new()
	screen_root.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	screen_root.size_flags_vertical=Control.SIZE_EXPAND_FILL
	screen_root.custom_minimum_size=Vector2(0,0)
	inset.add_child(screen_root)
	intro=_new_panel()
	instructions=_new_panel()
	stats_screen=_new_panel()
	armory=_new_panel()
	boss_briefing=_new_panel()
	challenge=_new_panel()
	decision=_new_panel()
	results=_new_panel()
	screen_panels=[intro,instructions,stats_screen,armory,boss_briefing,challenge,decision,results]
	for p in screen_panels:
		p.visible=false
	_build_intro()
	_build_instructions()
	_build_stats()
	_build_armory()
	_build_boss_briefing()
	_build_challenge()
	_build_decision()
	_build_results()

func _build_sidebar(parent):
	var rail=VBoxContainer.new()
	rail.custom_minimum_size.x=260
	rail.add_theme_constant_override("separation",11)
	parent.add_child(rail)
	var card=_panel(Color("#101e2d"),LINE,9)
	rail.add_child(card)
	var pad=_pad(card,14,12)
	var stack=VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	pad.add_child(stack)
	var row=HBoxContainer.new()
	var exposure_label=_label("EXPOSURE",11,MUTED)
	exposure_label.custom_minimum_size.x=95
	row.add_child(exposure_label)
	var gap=Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	risk_band_label=_label("GREEN",12,CYAN)
	risk_band_label.custom_minimum_size.x=72
	row.add_child(risk_band_label)
	stack.add_child(row)
	risk_value=_label("00%",44,CYAN)
	stack.add_child(risk_value)
	meter=ProgressBar.new()
	meter.custom_minimum_size.y=11
	meter.max_value=100
	meter.show_percentage=false
	var back=StyleBoxFlat.new()
	back.bg_color=Color("#1a2938")
	_round(back,6)
	meter.add_theme_stylebox_override("background",back)
	var fill=StyleBoxFlat.new()
	fill.bg_color=CYAN
	_round(fill,6)
	meter.add_theme_stylebox_override("fill",fill)
	stack.add_child(meter)
	risk_odds=_label("DETECTION ROLL / 0%",12,MUTED)
	risk_odds.custom_minimum_size.x=200
	stack.add_child(risk_odds)
	var radar_card=_panel(PANEL,LINE,9)
	radar_card.custom_minimum_size.y=180
	rail.add_child(radar_card)
	var rbox=VBoxContainer.new()
	rbox.add_child(_label("SIGNAL SWEEP",9,MUTED))
	radar=Radar.new()
	radar.custom_minimum_size=Vector2(220,148)
	radar.size_flags_vertical=Control.SIZE_EXPAND_FILL
	rbox.add_child(radar)
	radar.contact_swept.connect(_play_ping)
	radar_card.add_child(rbox)
	var note=_panel(Color("#111724"),Color("#39293a"),8)
	rail.add_child(note)
	var npad=_pad(note,12,12)
	var nbox=VBoxContainer.new()
	nbox.add_child(_label("FIELD NOTE  /  HIGH RISK, HIGH REWARD",9,AMBER))
	nbox.add_child(_label("Correct answers grow your cache. Extract to lock it in.",11,TEXT))
	npad.add_child(nbox)

func _build_footer(parent):
	var row=HBoxContainer.new()
	parent.add_child(row)
	var left=_label("ENCRYPTED LINK  /  NODE 07",9,MUTED)
	left.custom_minimum_size.x=180
	left.autowrap_mode=TextServer.AUTOWRAP_OFF
	left.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(left)
	var gap=Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var right=_label("ZERO HOUR  |  VERSION 4.2",9,MUTED)
	right.custom_minimum_size.x=164
	right.autowrap_mode=TextServer.AUTOWRAP_OFF
	right.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(right)
func _new_panel():
	var p=VBoxContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_theme_constant_override("separation",11)
	screen_root.add_child(p)
	return p

func _build_intro():
	intro.add_child(_label("OPERATION NIGHTFALL",11,AMBER))
	intro.add_child(_label("Get in. Go deep. Get out.",36,TEXT))
	intro.add_child(_label("Crack security challenges, build your cache, and decide when to escape.",15,MUTED))
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	intro.add_child(gap)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	intro.add_child(row)
	_tile(row,"01 / SOLVE","Beat the clock to keep exposure down.",CYAN)
	_tile(row,"02 / EARN","Correct answers build your unbanked cache.",AMBER)
	_tile(row,"03 / EXTRACT","Bank your credits before detection.",RED)
	var bottom_gap=Control.new()
	bottom_gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	intro.add_child(bottom_gap)
	var btns=HBoxContainer.new()
	btns.add_theme_constant_override("separation",10)
	intro.add_child(btns)
	_button(btns,"INITIATE OPERATION",_begin_mission,true)
	_button(btns,"MISSION BRIEFING",_open_instructions,false)
	_button(btns,"PERK SHOP",_open_armory,false)
	_button(btns,"OPERATOR STATS",_open_stats,false)

func _build_instructions():
	instructions.add_child(_label("MISSION BRIEFING  /  READ BEFORE DEPLOYMENT",11,AMBER))
	instructions.add_child(_label("Your objective",29,TEXT))
	instructions.add_child(_label("Solve challenges to move deeper into the network. Every correct answer adds credits to your exposed cache. Choose when to leave and secure them.",14,MUTED))
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	instructions.add_child(gap)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	instructions.add_child(row)
	_tile(row,"01 / SOLVE","Beat the clock. You get 6 seconds of overtime grace, but exposure rises faster during it.",CYAN)
	_tile(row,"02 / MANAGE EXPOSURE","Exposure rises while you play. Wrong answers add risk; quick correct answers can reduce it.",AMBER)
	var row2=HBoxContainer.new()
	row2.add_theme_constant_override("separation",10)
	instructions.add_child(row2)
	_tile(row2,"03 / CHOOSE YOUR EXIT","PUSH DEEPER for more rewards or EXTRACT & BANK to keep your cache.",CYAN)
	_tile(row2,"04 / KNOW THE STAKES","Detection permanently wipes unbanked credits. Already banked credits are safe.",RED)
	instructions.add_child(_label("DETECTION LEVELS",11,CYAN))
	var bands=HBoxContainer.new()
	bands.add_theme_constant_override("separation",7)
	instructions.add_child(bands)
	_tile(bands,"GREEN  /  0-49%","0% detection roll",CYAN)
	_tile(bands,"YELLOW  /  50-64%","1% detection roll",Color("#f4dc61"))
	_tile(bands,"ORANGE  /  65-79%","5% detection roll",AMBER)
	_tile(bands,"RED  /  80-94%","25% detection roll",RED)
	_tile(bands,"CRITICAL  /  95-100%","65% detection roll",Color("#ff2f59"))
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	instructions.add_child(actions)
	_button(actions,"START OPERATION",_begin_mission,true)
	_button(actions,"OPTIONAL  /  PERK SHOP",_open_armory,false)
	_button(actions,"BACK TO BRIEFING",_back_to_intro,false)

func _build_stats():
	stats_screen.add_child(_label("PERSONNEL FILE  /  LOCAL SAVE",10,CYAN))
	stats_screen.add_child(_label("Operator record",32,TEXT))
	stats_screen.add_child(_label("Performance stored on this device.",13,MUTED))
	var body=_label("",15,TEXT)
	body.name="StatsBody"
	stats_screen.add_child(body)
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stats_screen.add_child(gap)
	var row=HBoxContainer.new()
	stats_screen.add_child(row)
	_button(row,"BACK TO BRIEFING",_back_to_intro,false)

func _build_armory():
	armory.add_child(_label("PERK SHOP  /  PRE-MISSION LOADOUT",10,CYAN))
	armory.add_child(_label("Acquire exploits",30,TEXT))
	armory.add_child(_label("Buy single-use perks with secured credits. They stay in your inventory until activated.",13,MUTED))
	purchase_feedback=_label("",12,CYAN)
	purchase_feedback.visible=false
	armory.add_child(purchase_feedback)
	armory_balance=_label("",13,AMBER)
	armory.add_child(armory_balance)
	armory.add_child(_label("SCROLL THE PERK LIST TO VIEW ALL ITEMS",9,MUTED))
	var cards_scroll=ScrollContainer.new()
	cards_scroll.custom_minimum_size.y=185
	cards_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	cards_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	armory.add_child(cards_scroll)
	var card_list=VBoxContainer.new()
	card_list.add_theme_constant_override("separation",8)
	card_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cards_scroll.add_child(card_list)
	var cards=HBoxContainer.new()
	cards.add_theme_constant_override("separation",8)
	cards.custom_minimum_size.y=205
	card_list.add_child(cards)
	_add_armory_card(cards,"intel_ping","INTEL PING","Reveal a tailored hint for a challenge.","225 CREDITS",CYAN)
	_add_armory_card(cards,"time_buffer","TIME BUFFER","Add 5 seconds to a challenge.","300 CREDITS",AMBER)
	_add_armory_card(cards,"signal_scrubber","SIGNAL SCRUBBER","Cut current exposure by 8 points.","450 CREDITS",RED)
	var cards2=HBoxContainer.new()
	cards2.add_theme_constant_override("separation",8)
	cards2.custom_minimum_size.y=205
	card_list.add_child(cards2)
	_add_armory_card(cards2,"ghost_protocol","GHOST PROTOCOL","Cancel the next detection event.","750 CREDITS",Color("#bd8cff"))
	_add_armory_card(cards2,"cache_spike","CACHE SPIKE","Add 50 credits after your next correct answer.","525 CREDITS",Color("#ffd166"))
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	armory.add_child(actions)
	_button(actions,"DEPLOY WITH LOADOUT",_begin_mission,true)
	_button(actions,"BACK TO BRIEFING",_back_to_intro,false)

func _build_boss_briefing() -> void:
	boss_briefing.add_child(_label("INCOMING  /  HIGH-SECURITY NODE",11,Color("#bd8cff")))
	boss_briefing.add_child(_label("BOSS NODE: THE BLACK ICE",30,TEXT))
	boss_briefing.add_child(_label("Every eight regular challenges, the network deploys a multi-step arithmetic or layered pattern problem. Perks are disabled during boss questions. Engage or bypass.",14,MUTED))
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	boss_briefing.add_child(row)
	_tile(row,"ENGAGE  /  DYNAMIC TIMER","A multi-step boss problem gets up to 48 seconds at low exposure or 28 at critical, plus 6 seconds of grace. The timer updates if your exposure band changes.",CYAN)
	_tile(row,"CORRECT  /  +150 CREDITS","Earn 150 bonus unbanked credits, plus the question's normal reward, and reduce exposure by 10 percentage points.",Color("#ffd166"))
	var row2=HBoxContainer.new()
	row2.add_theme_constant_override("separation",10)
	boss_briefing.add_child(row2)
	_tile(row2,"WRONG  /  +15 EXPOSURE","Exposure rises by 15 percentage points and there is no boss bonus.",RED)
	_tile(row2,"BYPASS  /  +5 EXPOSURE","Skip the boss question and exposure rises by 5 percentage points.",AMBER)
	boss_briefing.add_child(_label("A detection roll happens after an engaged boss answer using your resulting exposure. Detection can still wipe your unbanked cache; secured wallet credits remain safe. Boss questions do not count toward the next set of eight.",12,TEXT))
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	boss_briefing.add_child(gap)
	var actions=HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	boss_briefing.add_child(actions)
	_button(actions,"ENGAGE BOSS NODE",_engage_boss,true)
	_button(actions,"BYPASS NODE  /  +5 EXPOSURE",_skip_boss,false)

func _add_armory_card(parent: Control, perk_id: String, title: String, description: String, cost_text: String, accent: Color) -> void:
	var card=_panel(Color("#0a1420"),LINE,8)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var stack=VBoxContainer.new()
	stack.add_theme_constant_override("separation",7)
	card.add_child(stack)
	var badge=PerkBadge.new()
	badge.custom_minimum_size=Vector2(72,72)
	badge.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	badge.set_perk(perk_id)
	stack.add_child(badge)
	stack.add_child(_label(title,12,accent))
	var desc=_label(description,10,TEXT)
	desc.custom_minimum_size.y=44
	stack.add_child(desc)
	var stock=_label("OWNED  /  0",10,MUTED)
	armory_stock_labels[perk_id]=stock
	stack.add_child(stock)
	var confirmation=_label("",10,CYAN)
	confirmation.name="PurchaseConfirmation"
	confirmation.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	purchase_labels[perk_id]=confirmation
	stack.add_child(confirmation)
	var buy_button=_button(stack,"BUY  /  "+cost_text,Callable(self,"_buy_perk").bind(perk_id),false)
	armory_buy_buttons[perk_id]=buy_button

func _build_challenge():
	challenge_header=_label("",11,CYAN)
	challenge_header.custom_minimum_size.y=22
	challenge_header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	challenge.add_child(challenge_header)
	var row=HBoxContainer.new()
	row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.alignment=BoxContainer.ALIGNMENT_END
	clock_label=_label("12",24,CYAN)
	clock_label.custom_minimum_size.x=82
	clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(clock_label)
	challenge.add_child(row)
	challenge.add_child(_rule())
	var flex=Control.new()
	flex.size_flags_vertical=Control.SIZE_EXPAND_FILL
	challenge.add_child(flex)
	prompt=_label("",26,TEXT)
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	challenge.add_child(prompt)
	challenge_status=_label("Solve the challenge.",11,MUTED)
	challenge_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	challenge.add_child(challenge_status)
	perk_feedback=_label("",11,CYAN)
	perk_feedback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	perk_feedback.visible=false
	challenge.add_child(perk_feedback)
	perk_bar=HFlowContainer.new()
	perk_bar.alignment=FlowContainer.ALIGNMENT_CENTER
	perk_bar.add_theme_constant_override("separation",6)
	for perk_id in ["intel_ping","time_buffer","signal_scrubber","ghost_protocol","cache_spike"]:
		var slot=VBoxContainer.new()
		slot.custom_minimum_size.x=132
		slot.add_theme_constant_override("separation",2)
		var badge=PerkBadge.new()
		badge.custom_minimum_size=Vector2(38,38)
		badge.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		badge.set_perk(perk_id)
		perk_badges[perk_id]=badge
		slot.add_child(badge)
		var titles={"intel_ping":"INTEL","time_buffer":"TIME +5","signal_scrubber":"SCRUBBER","ghost_protocol":"GHOST","cache_spike":"CACHE +50"}
		var title=titles[perk_id]
		var action_button=_button(slot,"USE "+title,Callable(self,"_activate_perk").bind(perk_id),false)
		action_button.custom_minimum_size.x=126
		action_button.add_theme_font_size_override("font_size",9)
		perk_use_buttons[perk_id]=action_button
		var count_label=_label("x0",9,MUTED)
		count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		perk_count_labels[perk_id]=count_label
		slot.add_child(count_label)
		perk_bar.add_child(slot)
	perk_bar.visible=false
	challenge.add_child(perk_bar)
	answer=LineEdit.new()
	answer.custom_minimum_size.y=50
	answer.placeholder_text="TYPE YOUR ANSWER"
	answer.alignment=HORIZONTAL_ALIGNMENT_CENTER
	answer.add_theme_font_size_override("font_size",16)
	answer.add_theme_color_override("font_color",TEXT)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("#07101b")
	style.border_color=Color("#2d5161")
	style.set_border_width_all(1)
	_round(style,7)
	answer.add_theme_stylebox_override("normal",style)
	answer.add_theme_stylebox_override("focus",style)
	answer.text_submitted.connect(_submit_text)
	challenge.add_child(answer)
	var buttons=HBoxContainer.new()
	buttons.alignment=BoxContainer.ALIGNMENT_CENTER
	challenge.add_child(buttons)
	_button(buttons,"TRANSMIT ANSWER",_submit,true)
	var flex2=Control.new()
	flex2.size_flags_vertical=Control.SIZE_EXPAND_FILL
	challenge.add_child(flex2)

func _build_decision():
	decision.add_child(_label("CHALLENGE DEBRIEF",10,CYAN))
	decision_banner=_panel(Color("#25131a"),RED,8)
	decision.add_child(decision_banner)
	var banner_pad=_pad(decision_banner,14,10)
	decision_outcome=_label("INCORRECT  /  NO REWARD",23,RED)
	banner_pad.add_child(decision_outcome)
	decision_status=_label("SIGNAL HELD  /  Your run continues. Choose your next move.",16,TEXT)
	decision.add_child(decision_status)
	decision_text=_label("",14,MUTED)
	decision.add_child(decision_text)
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	decision.add_child(gap)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",9)
	decision.add_child(row)
	_button(row,"PUSH DEEPER",_continue,true)
	_button(row,"EXTRACT & BANK",_extract,false)
	decision.add_child(_label("Choose when ready. This decision will not time out.",10,MUTED))

func _build_results():
	results.add_child(_label("OPERATION REPORT  /  FINAL",10,AMBER))
	var title=_label("Run complete",33,TEXT)
	title.name="ResultTitle"
	results.add_child(title)
	results_text=_label("",15,MUTED)
	results.add_child(results_text)
	var gap=Control.new()
	gap.size_flags_vertical=Control.SIZE_EXPAND_FILL
	results.add_child(gap)
	var row=HBoxContainer.new()
	results.add_child(row)
	_button(row,"RUN IT BACK",_open_instructions,true)
	_button(row,"OPERATOR STATS",_open_stats,false)

func _label(value,size,color):
	var l=Label.new()
	l.text=value

	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return l

func _panel(color,border,radius):
	var p=PanelContainer.new()
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.border_color=border
	s.set_border_width_all(1)
	_round(s,radius)
	s.content_margin_left=11
	s.content_margin_right=11
	s.content_margin_top=11
	s.content_margin_bottom=11
	p.add_theme_stylebox_override("panel",s)
	return p

func _round(s,r):
	s.corner_radius_top_left=r
	s.corner_radius_top_right=r
	s.corner_radius_bottom_left=r
	s.corner_radius_bottom_right=r

func _pad(parent,h,v):
	var m=MarginContainer.new()
	m.add_theme_constant_override("margin_left",h)
	m.add_theme_constant_override("margin_right",h)
	m.add_theme_constant_override("margin_top",v)
	m.add_theme_constant_override("margin_bottom",v)
	parent.add_child(m)
	return m

func _chip(label):
	var p=_panel(Color("#0a1420"),LINE,5)
	_pad(p,9,6).add_child(label)
	return p

func _tile(parent,title,body,accent):
	var p=_panel(Color("#0a1420"),LINE,7)
	p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var box=VBoxContainer.new()
	box.add_theme_constant_override("separation",5)
	p.add_child(box)
	box.add_child(_label(title,10,accent))
	box.add_child(_label(body,11,TEXT))

func _button(parent,text,action,primary):
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(180,46)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",11)
	var n=StyleBoxFlat.new()
	n.bg_color=Color("#1a3539") if primary else Color("#101d2a")
	n.border_color=Color("#4b9f92") if primary else Color("#2a4154")
	n.set_border_width_all(1)
	_round(n,6)
	var h=n.duplicate()
	h.bg_color=Color("#23534f") if primary else Color("#182b3c")
	b.add_theme_stylebox_override("normal",n)
	b.add_theme_stylebox_override("hover",h)
	b.add_theme_stylebox_override("pressed",h)
	b.add_theme_color_override("font_color",TEXT)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _rule():
	var r=ColorRect.new()
	r.color=LINE
	r.custom_minimum_size.y=1
	return r

func _show_panel(panel):
	for p in screen_panels:
		p.visible=p==panel
	panel.modulate.a=0.0
	var tw=create_tween()
	tw.tween_property(panel,"modulate:a",1.0,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if panel==intro:
		mission_kicker.text="MISSION CONTROL  /  BRIEFING"
	elif panel==instructions:
		mission_kicker.text="MISSION CONTROL  /  DEPLOYMENT BRIEFING"
	elif panel==stats_screen:
		mission_kicker.text="ARCHIVE  /  OPERATOR RECORD"
	elif panel==armory:
		mission_kicker.text="PRE-MISSION  /  PERK SHOP"
	elif panel==boss_briefing:
		mission_kicker.text="LIVE OPERATION  /  BOSS NODE BRIEFING"
	elif panel==challenge:
		mission_kicker.text="LIVE OPERATION  /  NODE ACCESS"
	elif panel==decision:
		mission_kicker.text="TACTICAL DECISION  /  CACHE EXPOSED"
	else:
		mission_kicker.text="MISSION CONTROL  /  AFTER ACTION"

func _open_instructions():
	_show_panel(instructions)

func _open_armory():
	_refresh_armory()
	_show_panel(armory)

func _buy_perk(perk_id: String) -> void:
	if GameManager.buy_perk(perk_id):
		purchase_feedback.text="PURCHASE CONFIRMED  /  %s added to your loadout" % perk_id.replace("_", " ").to_upper()
		purchase_feedback.visible=true
		purchase_labels[perk_id].text="ACQUIRED  /  +1 STOCK"
		purchase_labels[perk_id].add_theme_color_override("font_color",CYAN)
		var badge:Control=armory_stock_labels[perk_id].get_parent().get_node("PurchaseConfirmation").get_parent().get_child(0)
		badge.scale=Vector2(0.75,0.75)
		var pulse=create_tween()
		pulse.tween_property(badge,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_refresh_armory()
		_update_risk()

func _refresh_armory() -> void:
	if not is_instance_valid(armory_balance):
		return
	armory_balance.text="SECURED CREDITS  /  %d" % GameManager.get_credit_wallet()
	for perk_id in armory_stock_labels:
		armory_stock_labels[perk_id].text="OWNED  /  %d" % GameManager.get_perk_count(perk_id)
		armory_buy_buttons[perk_id].disabled=GameManager.get_credit_wallet() < int(GameManager.PERK_COSTS[perk_id])

func _refresh_perk_controls() -> void:
	if not is_instance_valid(perk_bar):
		return
	var any_available := false
	for perk_id in perk_use_buttons:
		var count := GameManager.get_perk_count(perk_id)
		var carries_into_boss: bool = GameManager.normal_questions_since_boss >= 7 and (perk_id == "ghost_protocol" or perk_id == "cache_spike")
		var available: bool = count > 0 and not boss_is_active and not carries_into_boss and not used_perks_this_challenge.has(perk_id) and not memory_phase and not challenge_resolved
		perk_use_buttons[perk_id].visible=count > 0
		perk_use_buttons[perk_id].disabled=not available
		perk_use_buttons[perk_id].tooltip_text="This perk affects the next question, which is a boss question." if carries_into_boss else ""
		perk_count_labels[perk_id].text="x%d" % count
		any_available = any_available or available
	perk_bar.visible=any_available and not boss_is_active and GameManager.game_state=="playing"

func _activate_perk(perk_id: String) -> void:
	if GameManager.game_state!="playing" or boss_is_active or GameManager.current_challenge_is_boss or challenge_resolved or memory_phase or used_perks_this_challenge.has(perk_id):
		return
	if not GameManager.consume_perk(perk_id):
		return
	used_perks_this_challenge[perk_id]=true
	match perk_id:
		"intel_ping":
			var hint := flow.get_current_hint()
			perk_feedback.text="INTEL PING  /  "+hint
			perk_feedback.visible=true
			challenge_status.text="FIELD INTEL DECRYPTED"
		"time_buffer":
			flow.add_time_buffer(5.0)
			base_limit+=5.0
			timer.start(timer.time_left+5.0)
			challenge_status.text="TIME BUFFER ACTIVE  /  +5 SECONDS"
		"signal_scrubber":
			GameManager.risk=maxf(GameManager.risk-8.0,0.0)
			challenge_status.text="SIGNAL SCRUBBED  /  EXPOSURE REDUCED BY 8"
		"ghost_protocol":
			GameManager.arm_ghost_protocol()
			challenge_status.text="GHOST PROTOCOL ARMED  /  NEXT DETECTION BLOCKED"
		"cache_spike":
			GameManager.arm_cache_spike()
			challenge_status.text="CACHE SPIKE ARMED  /  +50 ON NEXT CORRECT ANSWER"
	_play_perk_vfx(perk_id)
	_refresh_perk_controls()
	_update_risk()

func _play_perk_vfx(perk_id: String) -> void:
	var accent := CYAN
	if perk_id=="time_buffer":
		accent=AMBER
	elif perk_id=="signal_scrubber":
		accent=RED
	elif perk_id=="ghost_protocol":
		accent=Color("#bd8cff")
	elif perk_id=="cache_spike":
		accent=Color("#ffd166")
	var badge=perk_badges.get(perk_id)
	if is_instance_valid(badge):
		badge.scale=Vector2(0.72,0.72)
		var badge_tween=create_tween()
		badge_tween.tween_property(badge,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if perk_id=="intel_ping":
		var sweep=ColorRect.new()
		sweep.color=accent
		sweep.modulate.a=0.88
		sweep.size=Vector2(90.0,3.0)
		sweep.position=Vector2(-100.0,size.y*0.46)
		sweep.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(sweep)
		var scan=create_tween()
		scan.tween_property(sweep,"position:x",size.x+100.0,0.48)
		scan.parallel().tween_property(sweep,"modulate:a",0.0,0.48)
		scan.finished.connect(sweep.queue_free)
	else:
		var flash=ColorRect.new()
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.color=accent
		flash.modulate.a=0.0
		flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var flash_tween=create_tween()
		flash_tween.tween_property(flash,"modulate:a",0.17,0.08)
		flash_tween.tween_property(flash,"modulate:a",0.0,0.30)
		flash_tween.finished.connect(flash.queue_free)

func _begin_mission():
	memory_phase=false
	flow.reset_run()
	GameManager.start_mission()
	_begin_challenge()

func _begin_challenge(is_boss: bool = false):
	challenge_resolved=false
	boss_is_active=is_boss
	displayed_clock_phase=-1
	used_perks_this_challenge.clear()
	perk_feedback.text=""
	perk_feedback.visible=false
	var q=flow.start_challenge(is_boss)
	if q.is_empty():
		_show_panel(results)
		results_text.text="QUESTION BANK UNAVAILABLE OR EXHAUSTED\nStart a new mission to reshuffle."
		return
	challenge_header.text="%s  /  DEPTH %02d  /  %s  /  TIER %d" % ["BOSS NODE" if is_boss else "CHALLENGE",GameManager.mission_depth,str(q.get("category","CHALLENGE")).to_upper(),int(q.get("difficulty",1))]
	answer.clear()
	base_limit=float(q.get("time_limit_seconds",12.0))
	timer_exposure_band=str(GameManager.get_detection_profile().get("band","GREEN"))
	memory_phase=q.has("stimulus")
	answer.editable=not memory_phase
	memory_response_prompt=str(q.get("response_prompt",q.get("prompt","")))
	if memory_phase:
		prompt.text=str(q["stimulus"])
		challenge_status.text="MEMORIZE THE SEQUENCE"
		perk_bar.visible=false
		timer.start(float(q.get("display_duration_seconds",2.0)))
	else:
		prompt.text=str(q["prompt"])
		challenge_status.text="BOSS  /  PERKS DISABLED  /  %d SEC AT %s EXPOSURE  /  +6 SEC GRACE" % [int(base_limit), timer_exposure_band] if is_boss else "BASE TIMER  /  %d SEC AT %s EXPOSURE  /  +6 SEC GRACE" % [int(base_limit), timer_exposure_band]
		timer.start(base_limit+GRACE_SECONDS)
		_refresh_perk_controls()
	_show_panel(challenge)
	_update_risk()
	if not memory_phase:
		answer.grab_focus()

func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo and not memory_phase and GameManager.game_state=="playing" and answer.has_focus() and (event.keycode==KEY_ENTER or event.keycode==KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		_submit()

func _submit():
	if not memory_phase and not challenge_resolved:
		_resolve(answer.text)

func _submit_text(value):
	if not memory_phase and not challenge_resolved:
		_resolve(value)

func _timeout():
	if memory_phase:
		memory_phase=false
		prompt.text=memory_response_prompt
		answer.editable=true
		base_limit=flow.sync_time_to_exposure()
		timer_exposure_band=str(GameManager.get_detection_profile().get("band","GREEN"))
		challenge_status.text="MEMORY TEST  /  %d SEC AT %s EXPOSURE  /  +6 SEC GRACE" % [int(base_limit), timer_exposure_band]
		flow.begin_response_phase()
		timer.start(base_limit+GRACE_SECONDS)
		_refresh_perk_controls()
		answer.grab_focus()
		return
	_resolve("",true)

func _resolve(value,timed_out=false):
	if GameManager.game_state!="playing" or challenge_resolved:
		return
	challenge_resolved=true
	timer.stop()
	memory_phase=false
	perk_bar.visible=false
	var result=flow.submit_answer(value,timed_out)
	if not result.get("resolved",false):
		challenge_resolved=false
		return
	_refresh()
	_show_panel(decision if GameManager.game_state=="decision" else results)

func _continue():
	GameManager.continue_mission()
	if GameManager.game_state=="boss_briefing":
		_show_panel(boss_briefing)
	else:
		_begin_challenge()

func _engage_boss() -> void:
	GameManager.begin_boss_challenge()
	_begin_challenge(true)

func _skip_boss() -> void:
	GameManager.skip_boss()
	boss_is_active=false
	_begin_challenge(false)

func _extract():
	GameManager.extract()
	_refresh()
	_show_panel(results)

func _open_stats():
	_refresh_stats()
	_show_panel(stats_screen)

func _back_to_intro():
	_show_panel(intro)

func _refresh_stats():
	var s=GameManager.get_stats()
	var total=int(s["questions_answered"])
	var accuracy=100.0*float(s["correct_answers"])/maxf(float(total),1.0)
	var average=float(s["total_answer_seconds"])/maxf(float(total),1.0)
	var body:Label=stats_screen.get_node("StatsBody")
	body.text="MISSIONS COMPLETED       %d\nCHALLENGES CLEARED       %d\nACCURACY                  %.1f%%\nAVERAGE RESPONSE          %.1f sec\nCREDITS AVAILABLE         %d\nLIFETIME BANKED           %d\nUNBANKED CREDITS LOST     %d\nEXTRACTED RUNS            %d\nDETECTED RUNS             %d\nBEST SCORE / DEPTH        %d / %d" % [s["games_played"],total,accuracy,average,s.get("credits_wallet",0),s["banked_credits_total"],s["lost_unbanked_credits_total"],s["extracted_runs"],s["detected_runs"],s["best_score"],s["best_depth"]]

func _update_risk():
	if not is_instance_valid(meter):
		return
	var depth=maxi(GameManager.mission_depth,0)
	if displayed_depth!=depth:
		displayed_depth=depth
		hud_depth.text="DEPTH  %02d" % depth
	if displayed_score!=GameManager.score:
		displayed_score=GameManager.score
		hud_score.text="SCORE  %06d" % displayed_score
	var credits=GameManager.get_credit_wallet()+GameManager.unbanked_rewards
	if displayed_credits!=credits:
		displayed_credits=credits
		hud_credits.text="CREDITS  %03d" % credits
	if displayed_risk==GameManager.risk:
		return
	displayed_risk=GameManager.risk
	meter.value=displayed_risk
	radar.set_exposure(displayed_risk)
	backdrop.set_exposure(displayed_risk)
	var risk_integer=int(displayed_risk)
	# All band boundaries are whole numbers; no band change is possible here.
	if displayed_risk_integer==risk_integer:
		return
	displayed_risk_integer=risk_integer
	risk_value.text="%02d%%" % risk_integer
	var info=GameManager.get_detection_profile()
	var band=str(info["band"])
	if band==displayed_risk_band:
		return
	displayed_risk_band=band
	risk_band_label.text=band
	risk_odds.text="DETECTION ROLL  /  %.0f%%" % float(info["chance"])
	var accent=CYAN
	match band:
		"YELLOW":accent=Color("#f4dc61")
		"ORANGE":accent=AMBER
		"RED":accent=RED
		"CRITICAL":accent=Color("#ff2f59")
	risk_value.add_theme_color_override("font_color",accent)
	risk_band_label.add_theme_color_override("font_color",accent)
	var fill:StyleBoxFlat=meter.get_theme_stylebox("fill")
	fill.bg_color=accent

func _refresh():
	_update_risk()
	_refresh_armory()
	_refresh_perk_controls()
	if not is_instance_valid(decision_text):
		return
	if GameManager.game_state=="decision":
		var r=GameManager.last_resolution
		var correct=bool(r.get("correct",false))
		var accent=CYAN if correct else RED
		decision_outcome.text="CORRECT  /  CACHE REWARDED" if correct else "INCORRECT  /  NO REWARD"
		decision_outcome.add_theme_color_override("font_color",accent)
		var banner_style:StyleBoxFlat=decision_banner.get_theme_stylebox("panel")
		banner_style.border_color=accent
		banner_style.bg_color=Color("#10251f") if correct else Color("#25131a")
		decision_status.text="SIGNAL HELD  /  Your run continues. Choose your next move."
		decision_status.add_theme_color_override("font_color",TEXT)
		var late="OVERTIME  /  %.1f SEC  /  +%.1f RISK" % [r.get("overtime_seconds",0.0),float(r.get("overtime_seconds",0.0))*1.0] if float(r.get("overtime_seconds",0.0))>0.0 else "ON TIME  /  NO OVERTIME EXPOSURE"
		var boss_summary=""
		if bool(r.get("is_boss",false)):
			boss_summary="BOSS NODE  /  "+("SUCCESS  /  +150 BONUS CREDITS  /  EXPOSURE -10 POINTS" if correct else "FAILED  /  EXPOSURE +15 POINTS")+"\n"
		if bool(r.get("blocked_by_ghost_protocol",false)):
			boss_summary+="GHOST PROTOCOL  /  DETECTION EVENT BLOCKED\n"
		if int(r.get("cache_spike_bonus",0))>0:
			boss_summary+="CACHE SPIKE  /  +%d CREDITS\n" % int(r["cache_spike_bonus"])
		decision_text.text=boss_summary+late+"\n\n"+str(r.get("explanation",""))+"\n\nCURRENT EXPOSURE  %d%%     DETECTION ROLL  %.0f%%\nUNBANKED CACHE  %d CREDITS" % [int(GameManager.risk),float(r.get("detection_chance",0.0)),GameManager.unbanked_rewards]
	if GameManager.game_state=="results":
		var title:Label=results.get_node("ResultTitle")
		if GameManager.run_result=="detected":
			title.text="Your signal was found."
			title.add_theme_color_override("font_color",RED)
			results_text.text="OPERATION COMPROMISED\n\nScore: %d\nUnbanked cache lost: %d\nLifetime banked credits: %d\nReached depth: %d" % [GameManager.score,GameManager.run_credits_lost,GameManager.banked_rewards,GameManager.mission_depth]
		else:
			title.text="Clean extraction."
			title.add_theme_color_override("font_color",CYAN)
			results_text.text="CACHE SECURED\n\nScore: %d\nBanked this run: %d\nLifetime banked credits: %d\nReached depth: %d" % [GameManager.score,GameManager.run_credits_banked,GameManager.banked_rewards,GameManager.mission_depth]
func _setup_audio():
	_build_ping_samples()
	var stream=AudioStreamGenerator.new()
	stream.mix_rate=22050
	stream.buffer_length=0.15
	audio_player=AudioStreamPlayer.new()
	audio_player.stream=stream
	audio_player.volume_db=-15.0
	add_child(audio_player)
	audio_player.play()
	audio_playback=audio_player.get_stream_playback()

func _play_ping():
	if audio_playback==null:
		return
	audio_playback.push_buffer(ping_samples)

func _build_ping_samples():
	var rate:=22050.0
	var count:=1500
	ping_samples.resize(count)
	for i in range(count):
		var t:=float(i)/rate
		var envelope:=pow(1.0-float(i)/float(count),3.0)
		var sample:=sin(TAU*(920.0-430.0*float(i)/float(count))*t)*envelope*0.16
		ping_samples[i]=Vector2(sample,sample)
