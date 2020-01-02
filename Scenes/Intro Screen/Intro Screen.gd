extends Control

# New Game start
var world_map = load("res://Scenes/World Map/World Map Screen.tscn")
var level1 = load("res://Scenes/Battlefield/Battlefield.tscn")

# No text background
var no_text_background = preload("res://assets/intro screen/intro background no text.jpg")

enum {INTRO, GAME_SELECT, WAIT}
var current_state = INTRO

var options = ["New Game", "Load Game", "Options Screen"]
var current_option
var current_option_number = 0

func _ready():
	# Start music
	$"Intro Song".play(0)
	
	current_state = INTRO
	
	current_option = options[current_option_number]
	
	# Anim signal
	$"Anim".connect("animation_finished", self, "allow_selection")

func _input(event):
	match current_state:
		INTRO:
			# Any key
			if event is InputEventKey and event.is_pressed():
				$"Anim".play("Options Fade In")
				$"Intro Background".texture = no_text_background
				current_state = WAIT
		GAME_SELECT:
			if Input.is_action_just_pressed("ui_up"):
				current_option_number -= 1
				$"Options/Hand Selector".rect_position.y -= 18
				if current_option_number < 0:
					current_option_number = 0
					current_option = options[current_option_number]
					$"Options/Hand Selector".rect_position.y += 18
				current_option = options[current_option_number]
				$"Options/Hand Selector/Move".play(0)
			if Input.is_action_just_pressed("ui_down"):
				current_option_number += 1
				$"Options/Hand Selector".rect_position.y += 18
				if current_option_number > options.size() - 1:
					current_option_number = options.size() - 1
					current_option = options[current_option_number]
					$"Options/Hand Selector".rect_position.y -= 18
				current_option = options[current_option_number]
				$"Options/Hand Selector/Move".play(0)
			if Input.is_action_just_pressed("ui_accept"):
				$"Options/Hand Selector/Accept".play(0)
				process_selection()

func allow_selection(anim_name):
	current_state = GAME_SELECT
	

func process_selection():
	match current_option:
		"New Game":
			$"Anim".play("music fade out")
			set_process_input(false)
			# Clear battlefield
			BattlefieldInfo.clear()
			
			# Scene change
			SceneTransition.connect("scene_changed", self, "clean_up")
			SceneTransition.change_scene(world_map, 0.1)

func clean_up():
	$"Intro Song".stop()
	SceneTransition.disconnect("scene_changed", self, "clean_up")
	queue_free()