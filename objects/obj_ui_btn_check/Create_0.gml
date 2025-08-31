event_inherited();

icon = spr_btn_check;
iconAlpha = 0;
toggled = false;

onChange = function() {}
onClick = function() {
	toggled = !toggled;
	onChange();
}