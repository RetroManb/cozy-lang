icon = spr_btn_load;
textAlpha = 1;
text = "Load compiled code";
iconXOffset = 8;

onClick = function() {
	var filename = get_open_filename_ext("Compiled cozy file (*.cz)|*.cz|All types (*.*)|*",filename_change_ext(filename_name(obj_cozytest.currentPath),".cz"),"","Load compiled code");
	if (!file_exists(filename))
		return;
	
	var err = obj_cozytest.loadCompiled(filename);
	if (string_length(err) > 0)
	{
		var arr = obj_ui.showWindow();
		var window = arr[0];
		var button = arr[1];
		
		window.title = "Error while loading";
		window.contentText = err;
	}
}