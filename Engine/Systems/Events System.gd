extends Node

class_name Event_System

signal all_events_completed

enum {starting_events, middle_events, ending_events}
var current_state = starting_events

# Event Queue
var queue_of_events = []
var current_event

func _ready():
	BattlefieldInfo.event_system = self
	
# Start the events
func start_events_queue():
	# If the event queue is empty, we are done processing events
	if queue_of_events.empty():
		print("FROM EVENT SYSTEM: Event queue is empty!")
		# Clear the final event
		current_event.queue_free()
		current_event = null
		emit_signal("all_events_completed")
		# Start/Resume/End depending on state
		match current_state:
			starting_events:
				start_level()
			middle_events:
				resume_gameplay()
			ending_events:
				end_level()
		return
	
	# Take first event and start it -> Register to it
	if current_event != null:
		current_event.queue_free()
	current_event = queue_of_events.pop_front()
	current_event.connect("event_done", self, "start_events_queue")
	print("FROM EVENT SYSTEM: Current event processing: ", current_event.event_name, " Part: ", current_event.event_part)
	current_event.start()

# Add an event to the queue
func add_event(event: Event_Base):
	queue_of_events.append(event)

# Remove an event from the queue
func remove_event(event: Event_Base):
	queue_of_events.erase(event)

# Resumes gameplay -> Modify this later for custom starts
func resume_gameplay():
	pass

# Starts the level -> Use this for events that take place at the beginning of the level
func start_level():
	BattlefieldInfo.turn_manager.turn = Turn_Manager.WAIT
	BattlefieldInfo.start_level()
	current_state = middle_events

# Ends the level and goes to the next level
func end_level():
	pass