

draw_sprite_stretched_ext(sprite_index,0,x - sprite_width/2,y - sprite_height/2,sprite_width,sprite_height,image_blend,image_alpha * 0.5);

draw_set_halign(fa_center);
draw_set_valign(fa_top);
draw_set_alpha(image_alpha);
draw_set_font(fnt_code_bold);
draw_set_color(c_white);
	
draw_text_transformed(x,y-sprite_height/2+8,title,titleScale,titleScale,0);

draw_text_transformed(x,y-sprite_height/2+32,contentText,1,1,0);

draw_set_halign(fa_left);

draw_set_alpha(1);