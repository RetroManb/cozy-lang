

draw_sprite_stretched_ext(sprite_index,isHovered and !isMouseDown,x - sprite_width/2,y - sprite_height/2,sprite_width,sprite_height,image_blend,image_alpha);

if (iconAlpha > 0)
{
	var iconX = 0;
	var iconY = 0;

	switch (iconHAlign)
	{
		case fa_left:
			iconX = x + iconXOffset - sprite_width/2 + sprite_get_width(icon)/2;
			break;
		case fa_center:
			iconX = x + iconXOffset;
			break;
		case fa_right:
			iconX = x + iconXOffset + sprite_width/2 - sprite_get_width(icon)/2;
			break;
	}
	switch (iconVAlign)
	{
		case fa_top:
			iconY = y + iconYOffset - sprite_height/2 + sprite_get_height(icon)/2;
			break;
		case fa_middle:
			iconY = y + iconYOffset;
			break;
		case fa_bottom:
			iconY = y + iconYOffset + sprite_height/2 - sprite_get_height(icon)/2;
			break;
	}

	draw_sprite_ext(icon,0,iconX,iconY,iconScale,iconScale,0,active ? c_white : c_gray,iconAlpha * image_alpha);
}

if (textAlpha > 0)
{
	var textX = x+textXOffset;
	var textY = y+textYOffset;
	
	draw_set_halign(textHAlign);
	draw_set_valign(textVAlign);
	draw_set_color(active ? c_white : c_gray);
	draw_set_alpha(textAlpha * image_alpha);
	draw_set_font(textFont);
	
	draw_text_transformed(textX,textY,text,textScale,textScale,0);
	
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_color(c_white);
	draw_set_alpha(1);
}