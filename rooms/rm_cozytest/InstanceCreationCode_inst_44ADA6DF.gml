icon = spr_btn_load;
textAlpha = 1;
text = "Load source file";
iconXOffset = 8;

onClick = function() {
	var filename = get_open_filename_ext("Cozy source files (*.cozy)|*.cozy|All types (*.*)|*",filename_change_ext(filename_name(obj_cozytest.currentPath),".cozy"),"","Load source file");
	if (!file_exists(filename))
		return;
	
	var err = obj_cozytest.loadFile(filename);
	if (string_length(err) > 0)
	{
		var arr = obj_ui.showWindow();
		var window = arr[0];
		var button = arr[1];
		
		window.title = "Error while loading";
		window.contentText = err;
	}
}