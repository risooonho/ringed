extends Node2D

export var smooth = 8.0
var target
var maps = []
var default_screen_size = Vector2(1024, 768)
var min_screen_size = default_screen_size/2
var quick_adapt = false
var history = []
var thread = Thread.new()

# ACTIONS inputs
const INPUT_ACTIONS = ["left","right","up","down","run","dodge","shot"] # This array will give us the order and action name in UI too

func _ready():
	get_viewport().connect("size_changed", self, "size_changed") # Update the sizes of different objects
	set_process(true)

	# Connect the menu
	target = get_node("Menu/SubMenus/Main")
	get_node("Menu/SubMenus/Main/Join").connect("pressed", self, "move_menu", ["Join"])
	get_node("Menu/SubMenus/Main/Host").connect("pressed", self, "move_menu", ["Host"])
	get_node("Menu/SubMenus/Main/Options").connect("pressed", self, "move_menu", ["Options"])

	# Menu "Options"
	get_node("Menu/SubMenus/Options/Controls").connect("pressed", self, "move_menu", ["Controls"])
	get_node("Menu/SubMenus/Options/Graphics").connect("pressed", self, "move_menu", ["Graphics"])
	
	get_node("Menu/SubMenus/Join/Enter").connect("pressed", self, "join")
	get_node("Menu/SubMenus/Host/Host").connect("pressed", self, "host")
	
	# Maps
	var dir = Directory.new()
	dir.open("res://maps/")
	dir.list_dir_begin()
	var name = dir.get_next()
	while(name):
		if(name.length() > 2):
			if(!dir.current_is_dir()):
				maps.append("res://maps/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	
	maps.sort_custom(self, "sort_by_filename")
	
	var mapsList = get_node("Menu/SubMenus/Host/Map/OptionButton")
	mapsList.connect("item_selected",self,"chose_map_list")
	for map in maps:
		var item_name = snake_case_to_readable_name(map.get_file().basename())
		mapsList.add_item(item_name)
		
	var menu_node = get_node("Menu/SubMenus")
	for i in range(0, menu_node.get_child_count()): # Loop through all the screens
		var screen = menu_node.get_child(i)
		if(screen extends Control):
			var screen_pos = screen.get_pos() / default_screen_size # Get the screen pos in [0..1] coordinates
			screen.set_meta("position", Vector2(round(screen_pos.x), round(screen_pos.y))) # Round so hand-placing of menus is easier
			
	
			# The back buttons in the menus
			var back_button = screen.get_node("Back")
			if(back_button && back_button extends BaseButton):
				back_button.connect("pressed", self, "back")
	
	size_changed() # Update the position of various menus
	

func size_changed():
	var new_size = get_viewport().get_visible_rect().size # The new size
	var subscreen_size = Vector2(max(min_screen_size.x, new_size.x), max(min_screen_size.y, new_size.y))
	
#	var background_region = Rect2(0, 0, subscreen_size.x * 5, subscreen_size.y * 5) # Resize the grass background
#	get_node("Background/Sprite").set_region_rect(background_region)
#	get_node("Background/Sprite").set_offset(-2*new_size)
	
	var menu_node = get_node("Menu/SubMenus")
	var menu_childs = get_node("Menu").get_children()
	for c_menu in menu_childs:
		resize_menu(c_menu)
#	resize_menu(get_node("Menu/PressEnter"))
	
	# Move sub-menus
	for i in range(0, menu_node.get_child_count()):
		var screen = menu_node.get_child(i)
		if(screen extends Control):
			var screen_pos = screen.get_meta("position") # Get the old position
			screen.set_pos(screen_pos * subscreen_size) # Multiply coordinates in range [0..1] with coordinates in range [0..new_size]
			
	quick_adapt = true # Cause the screen to quickly move to target pos

func resize_menu(menu):
	if(menu.get_type() == "Control"):
		var new_size = get_viewport().get_visible_rect().size # The new size
		menu.set_margin( MARGIN_RIGHT, new_size.x) # Resize the menu on X
		menu.set_margin( MARGIN_BOTTOM, new_size.y) # Resize the menu on Y

func _process(delta):
	var target_pos = -target.get_pos()
	var c_pos = get_pos()
	if(quick_adapt):
		quick_adapt = false
		set_pos(target_pos)
	elif(c_pos.distance_squared_to(target_pos) > 2):
		var new_pos = c_pos + (target_pos - c_pos)/smooth
		set_pos(new_pos)

func move_menu(to):
	var el = history.find(to)
	if(el >= 0):
		if(el != 0):
			to = history[el - 1]
			history.resize(el - 1) # Go back when "cyclical" link are present
		else:
			return
	history.push_back(target.get_name())
	target = get_node("Menu/SubMenus/" + to)

func back():
	var el = history.size() - 1
	var to = "Main"
	
	if(el >= 0):
		to = history[el]
		history.remove(el)
	
	target = get_node("Menu/SubMenus/" + to)
	

func join():
	play("res://maps/forest_1.xml")
	
func host():
	play(maps[get_node("Menu/SubMenus/Host/Map/OptionButton").get_selected_ID()])

func play(map):
	get_node("/root/autoload").map_scene = load(map)
	print(map)
	get_tree().change_scene("res://scenes/game.xml")

func snake_case_to_readable_name(snake):
	var splitted = snake.split("_")
	var readable = ""
	
	for part in splitted:
		readable += part.capitalize() + ""
	
	return readable

func sort_by_filename(a, b):
	return a.get_file() < b.get_file()

func chose_map_list(id):
	var mapsList = get_node("Menu/SubMenus/Host/Map/OptionButton")
	print(get_node("Menu/SubMenus/Host/Map/Image").get_texture().get_path())
	var path = "res://maps/images/"+mapsList.get_item_text(id)+".png"
	if (thread.is_active()):
		#already working
		return
	thread.start(self,"preview_load",path)

func preview_load(path):
	#load the resource
	var tex = ResourceLoader.load(path)
	#call preview_load_done on main thread	
	call_deferred("preview_load_done")
	return tex #return it

func preview_load_done():
	#wait for the thread to complete, get the returned value
	var tex = thread.wait_to_finish()
	#set to the sprite
	get_node("Menu/SubMenus/Host/Map/Image").set_texture(tex)