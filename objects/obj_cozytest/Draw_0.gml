draw_sprite_tiled_ext(spr_bg,0,bgX,bgY,1,1,bgColor,0.25);

draw_set_font(fnt_code_italic);

draw_text_ext(32,24,$"Current file: {file_exists(currentPath) ? filename_name(currentPath) : "NONE"}",20,304);

draw_text(320,24,"File contents:");

draw_set_font(fnt_code);

var x_ = 320;
var y_ = 64;

draw_set_alpha(0.5);
draw_rectangle_color(x_,y_,room_width,room_height,c_black,c_black,c_black,c_black,false);
draw_set_alpha(1);

if (cozylang_is_callable(fn))
{
	switch (fileView)
	{
		default:
			var prevScissor = gpu_get_scissor();
			
			var h = string_height(" ");
			var lineCount = string_height(sourceCode)/h;
			if (syntaxHighlighting)
			{
				var surf = getSourceCodeSurface();
				
				gpu_set_scissor(x_,y_,room_width-x_,room_height-y_);
				draw_surface(surf,320,64);
			}
			else
			{
				gpu_set_scissor(x_,y_,room_width-x_,room_height-y_);
				draw_text(x_,y_,sourceCode);
			}
			
			gpu_set_scissor(x_-128,y_,128,room_height-y_);
			
			draw_set_color(c_gray);
			draw_set_halign(fa_right);
			for (var i = 0; i < lineCount; i++)
				draw_text(x_-4,y_+i*h,i+1);
			
			draw_set_halign(fa_left);
			draw_set_color(c_white);
			
			gpu_set_scissor(prevScissor);
			break;
		case COZYTEST_VIEWING.TOKENS:
			for (var i = 0, n = array_length(tokens); i < n; i++)
			{
				var token = tokens[i];
				
				draw_text(x_,y_,string(token));
				
				y_ += 20;
			}
			break;
		case COZYTEST_VIEWING.AST:
			/// temporary
			var astStr = string(ast);
			astStr = string_replace_all(astStr,"\t","    ");
			
			draw_text(x_,y_,astStr);
			
			//draw_text(x_,y_,"Not implemented currently");
			break;
		case COZYTEST_VIEWING.BYTECODE:
			var disassembly = __cozylang_debug_disassemble(bytecode);
			disassembly = string_replace_all(disassembly,"\t","    ");
			
			draw_text(x_,y_,disassembly);
			break;
	}
}

draw_set_font(fnt_code);

var x_ = 320;
var y_ = 64;

draw_text(32,room_height/2-40,"Output");

draw_set_alpha(0.5);
draw_rectangle_color(0,room_height/2,319,room_height,c_black,c_black,c_black,c_black,false);
draw_set_alpha(1);

var h = string_height(" ");

var y_ = room_height/2;

for (var i = 0, n = array_length(output); i < n; i++)
{
	var line = output[i];
	var col = line[0];
	var txt = line[1];
	
	draw_set_color(col);
	draw_text_ext(0,y_,txt,h,320);
	
	y_ += string_height_ext(txt,h,320);
}

draw_set_color(c_white);

if (executionTime >= 0)
{
	draw_text(32,192,$"Execution took {executionTime}ms");
}