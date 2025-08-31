hoveringInstance = noone;

mouseDeltaX = 0;
mouseDeltaY = 0;

mousePrevX = 0;
mousePrevY = 0;

minUIDepth = function() {
	var d = infinity;
	
	with (prt_ui_element)
		d = min(d,depth);
	
	return d;
}
showWindow = function() {
	var window = instance_create_depth(room_width/2,room_height/2,minUIDepth()-1,obj_ui_window);
	window.image_xscale = 16;
	window.image_yscale = 8;
	
	var button = instance_create_depth(window.sprite_width/2,window.sprite_height-24,window.depth-1,obj_ui_btn);
	button.textAlpha = 1;
	button.iconAlpha = 1;
	button.textFont = fnt_code_italic;
	button.text = "OK";
	
	button.onClick = method({window:window,button:button},function() {
		instance_destroy(window);
		instance_destroy(button);
	});
	
	array_push(window.children,button);
	button.parent = window;
	
	return [window,button];
}