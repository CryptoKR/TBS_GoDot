extends Node2D
class_name Cursor

# Signal for camera and other UI elements to update
signal cursorMoved

# Turn off UI elements when the unit starts moving
signal turn_off_ui
signal turn_on_ui

# Holds current unit selected
#var BattlefieldInfo.current_Unit_Selected

# Which mode is the cursor in
enum {MOVE, SELECT_MOVE_TILE, WAIT}
var cursor_state

func _ready():
	# Start cursor animation
	$"AnimatedCursor/AnimationPlayer".play("Moving")
	
	# Intial enum
	cursor_state = WAIT
	
	# Connect to Movement
	get_parent().get_node("Action Selector Screen").connect("selected_wait", self, "enable_standard")
	
	# Connec to turn transition
	BattlefieldInfo.turn_manager.connect("play_transition", self, "disable_standard")
	
	# Cursor to battlefield
	BattlefieldInfo.cursor = self
	
func _input(event):
	# Do not process if cursor is in wait mode
	if cursor_state == WAIT:
		return
	
	# Move Cursor by x pixels
	if Input.is_action_pressed("ui_left"):
		self.position.x -= Cell.CELL_SIZE
		updateCursorData()
		$"MoveSound".play()
		emit_signal("cursorMoved", "left", self.position)
	elif Input.is_action_pressed("ui_right"):
		self.position.x += Cell.CELL_SIZE
		updateCursorData()
		$"MoveSound".play()
		emit_signal("cursorMoved", "right", self.position)
	elif Input.is_action_pressed("ui_down"):
		self.position.y += Cell.CELL_SIZE
		updateCursorData()
		$"MoveSound".play()
		emit_signal("cursorMoved", "down", self.position)
	elif Input.is_action_pressed("ui_up"):
		self.position.y -= Cell.CELL_SIZE
		updateCursorData()
		$"MoveSound".play()
		emit_signal("cursorMoved", "up", self.position)
	elif Input.is_action_just_pressed("ui_accept"):
		updateCursorData()
		acceptButton()
	elif Input.is_action_just_pressed("ui_cancel"):
		cancel_Button()
	elif Input.is_action_just_pressed("L button"):
		updateCursorData()
		l_button()
	
	if Input.is_action_just_pressed("debug"):
		debug()

# Update cursor
func updateCursorData() -> void:
	# Clamp the cursor
	self.position.x = clamp(self.position.x, 0, (BattlefieldInfo.map_width * Cell.CELL_SIZE) - Cell.CELL_SIZE)
	self.position.y = clamp(self.position.y, 0, (BattlefieldInfo.map_height * Cell.CELL_SIZE) - Cell.CELL_SIZE)
	
	# Move Mode
	match cursor_state:
		MOVE:
			# Set Animation status of unit if not null -> This is if you go from one cell to another and both are adj and occupied
			if BattlefieldInfo.current_Unit_Selected != null:
					BattlefieldInfo.current_Unit_Selected.get_node("Animation").current_animation = "Idle"
					set_animation_status(true)
					# Remove Global Unit
					BattlefieldInfo.current_Unit_Selected = null
			
			# check if the cell if occupied
			if BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit != null:
				BattlefieldInfo.current_Unit_Selected = BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit
				
				# Set Global Variable
				BattlefieldInfo.current_Unit_Selected = BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit
				
				# Check if this unit is an ally
				if BattlefieldInfo.current_Unit_Selected.UnitMovementStats.is_ally && BattlefieldInfo.current_Unit_Selected.UnitActionStatus.get_current_action() != Unit_Action_Status.DONE:
					BattlefieldInfo.current_Unit_Selected.get_node("Animation").current_animation = "Selected"
					# Stop Cursor animation
					set_animation_status(false)
				
			else:
				# Do we have a unit selected right now?
				if BattlefieldInfo.current_Unit_Selected != null:
					BattlefieldInfo.current_Unit_Selected.get_node("Animation").current_animation = "Idle"
					BattlefieldInfo.current_Unit_Selected = null
					
					# Remove Global Unit
					BattlefieldInfo.current_Unit_Selected = null
					
					# Start animation of the cursor again
					set_animation_status(true)
		

# Accept Button
func acceptButton() -> void:
	match cursor_state:
		MOVE:
		# Open end turn window # Send a signal out here -> Or if you pressed a unit that is done
			if BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit == null || BattlefieldInfo.current_Unit_Selected.UnitActionStatus.get_current_action() == Unit_Action_Status.DONE:
				# Play accept sound
				$"AcceptSound".play()
				
				# Activate the end turn window
				get_parent().get_node("End Turn").start()
				
				# Turn this off
				enable(false, WAIT)
				
				# Turn UI Off
				emit_signal("turn_off_ui")
				return
			
			# Set current unit to the global unit selector
			BattlefieldInfo.current_Unit_Selected = BattlefieldInfo.current_Unit_Selected
			
			# Set Selected Animation to current unit
			if BattlefieldInfo.current_Unit_Selected.UnitMovementStats.is_ally:
				BattlefieldInfo.current_Unit_Selected.get_node("Animation").current_animation = "Highlighted"
			
			# Highlight ranges
			BattlefieldInfo.movement_calculator.calculatePossibleMoves(BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit, BattlefieldInfo.grid)
			
			# Set Cursor to the move status
			cursor_state = SELECT_MOVE_TILE
			
			# Set previous camera location so we can move back to it
			BattlefieldInfo.previous_camera_position = get_parent().get_node("GameCamera").position
			
			# Set animation back to true
			set_animation_status(true)
			
			# Sound
			$"SelectUnitSound".play()
			
			# Turn off UI
			emit_signal("turn_off_ui")
			
		SELECT_MOVE_TILE:
			# Validate that this is an ally
			if !BattlefieldInfo.current_Unit_Selected.UnitMovementStats.is_ally:
				cancel_Button()
				return
			
			# Validate if tile is in the list
			if BattlefieldInfo.movement_calculator.check_if_move_is_valid(BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE], BattlefieldInfo.current_Unit_Selected):
				# Set the old position so that we can go back if needed
				BattlefieldInfo.previous_position = BattlefieldInfo.current_Unit_Selected.UnitMovementStats.currentTile.position
				
				# Get the path to the tile
				BattlefieldInfo.movement_calculator.get_path_to_destination(BattlefieldInfo.current_Unit_Selected, BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE], BattlefieldInfo.grid)
				
				# Check if we are going to the same tile
				if BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE] == BattlefieldInfo.current_Unit_Selected.UnitMovementStats.currentTile:
					BattlefieldInfo.current_Unit_Selected.UnitMovementStats.movement_queue.push_front(BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE])
				
				# Remove the unit's occupied status on the grid
				BattlefieldInfo.current_Unit_Selected.UnitMovementStats.currentTile.occupyingUnit = null
				
				# Play Accept
				$"AcceptSound".play()
				
				# Move Camera back to original spot first
				BattlefieldInfo.main_game_camera.position = (BattlefieldInfo.current_Unit_Selected.position + Vector2(-112, -82))
				BattlefieldInfo.main_game_camera.smoothing_speed = 2
				
				# Start moving the unit
				BattlefieldInfo.unit_movement_system.is_moving = true
				
				# Turn off Cursor
				enable(false, WAIT)
				
			else:
				$"InvalidSound".play()

# Cancel Button
func cancel_Button() -> void:
	match cursor_state:
		SELECT_MOVE_TILE:
			# Clear all highlighted tiles
			BattlefieldInfo.movement_calculator.turn_off_all_tiles(BattlefieldInfo.current_Unit_Selected, BattlefieldInfo.grid)
			
			# Set Cursor back to Move status and clear current unit if needed
			updateCursorData()
			cursor_state = MOVE
			updateCursorData()
			
			# Play Cancel sound
			$"BackSound".play()
			
			# Turn on the UI if not on
			emit_signal("turn_on_ui")

# L Button -> Go to next unit that is available
func l_button() ->  void:
	for ally_unit in BattlefieldInfo.ally_units:
		if ally_unit.UnitActionStatus.get_current_action() == Unit_Action_Status.MOVE:
			var move_to_back = BattlefieldInfo.ally_units.pop_front()
			BattlefieldInfo.main_game_camera.position = (ally_unit.position + Vector2(-112, -82))
			BattlefieldInfo.main_game_camera.clampCameraPosition()
			BattlefieldInfo.cursor.position = ally_unit.position
			BattlefieldInfo.ally_units.append(move_to_back)
			updateCursorData()
			emit_signal("cursorMoved", "left", self.position)
			break

# Set animations state
func set_animation_status(State: bool):
	if State:
		get_node("AnimatedCursor").visible = true
		get_node("StaticCursor").visible = false
	if !State:
		get_node("AnimatedCursor").visible = false
		get_node("StaticCursor").visible = true

# Enable or disable visibility
func enable(status, next_cursor_state):
	visible = status
	cursor_state = next_cursor_state
	updateCursorData()

# Standard enable
func enable_standard():
	visible = true
	$Timer.start(0)
	emit_signal("turn_on_ui")

func disable_standard(transition_type):
	visible = false
	cursor_state = WAIT
	emit_signal("turn_off_ui")

func back_to_move():
	if BattlefieldInfo.turn_manager.turn == Turn_Manager.PLAYER_TURN:
		enable(true, MOVE)
		is_inside_tree()

func debug() -> void:
	print(BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].toString())
	print("Cursor is at: ", self.position)
	if BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit != null:
		print("Unit Name: ", BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit.UnitStats.name)
		print("Unit Status: ", BattlefieldInfo.grid[self.position.x / Cell.CELL_SIZE][self.position.y / Cell.CELL_SIZE].occupyingUnit.UnitActionStatus.get_current_action())

# Prevent this scene from automatically starting the event input
func _on_Timer_timeout():
	if BattlefieldInfo.turn_manager.turn != Turn_Manager.ENEMY_TURN && BattlefieldInfo.turn_manager.turn != Turn_Manager.WAIT:
		cursor_state = MOVE