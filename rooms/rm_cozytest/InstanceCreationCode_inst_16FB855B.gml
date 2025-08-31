icon = spr_btn_save;
textAlpha = 1;
text = "Save compiled code";
iconXOffset = 8;

onClick = function() {
	var filename = get_save_filename_ext("Compiled cozy file (*.cz)|*.cz",filename_change_ext(filename_name(obj_cozytest.currentPath),".cz"),"","Compile cozy code");
	
	var err = obj_cozytest.saveCompiled(filename);
	if (string_length(err) > 0)
	{
		var arr = obj_ui.showWindow();
		var window = arr[0];
		var button = arr[1];
		
		window.title = "Error while saving";
		window.contentText = err;
	}
}