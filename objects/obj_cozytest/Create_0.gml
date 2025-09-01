bgX = 0;
bgY = 0;
bgColor = #61D1FF;

currentPath = "";

sourceCode = "";
env = new CozyEnvironment();
tokens = undefined;
ast = undefined;
bytecode = undefined;
fn = undefined;
executionTime = -1;

env.stdoutFlush = function(stdout) {
	show_debug_message($"[OUT] {stdout}");
	array_push(output,[
		c_white,
		$"[OUT] {stdout}"
	]);
}
env.stderrFlush = function(stderr) {
	show_debug_message($"[ERR] {stderr}");
	array_push(output,[
		c_red,
		$"[ERR] {stderr}"
	]);
}

syntaxHighlighting = true;

sourceCodeSurface = undefined;
sourceCodeSurfaceNeedsChanged = false;

output = [];

getSourceCodeSurface = function(font=fnt_code) {
	if (!sourceCodeSurfaceNeedsChanged)
	{
		if (surface_exists(sourceCodeSurface))
			return sourceCodeSurface;
	}
	
	draw_set_font(font);
	
	if (!surface_exists(sourceCodeSurface))
		sourceCodeSurface = surface_create(string_width(sourceCode),string_height(sourceCode));
	else
		surface_resize(sourceCodeSurface,string_width(sourceCode),string_height(sourceCode));
	
	gpu_set_blendmode_ext_sepalpha(
		bm_inv_dest_color,
		bm_one,
		bm_one,
		bm_inv_src_alpha
	);
	
	surface_set_target(sourceCodeSurface);
	
	if (sourceCodeSurfaceNeedsChanged)
		draw_clear_alpha(c_black,0);
	
	var w = string_width(" ");
	var h = string_height(" ");
			
	var lineCount = 0;
			
	for (var i = 0, n = array_length(tokens); i < n; i++)
	{
		var token = tokens[i];
				
		var noDraw = false;
				
		lineCount = max(token.line,lineCount);
				
		var txt = token.value;
		var color = c_white;
		font = fnt_code;
		switch (token.type)
		{
			case COZY_TOKEN.EOL:
			case COZY_TOKEN.EOF:
				noDraw = true;
				break;
			case COZY_TOKEN.IDENTIFIER:
				if (txt == COZY_SELF_NAME)
				{
					color = #B76FFF;
					font = fnt_code_bold;
				}
				break;
			case COZY_TOKEN.OPERATOR:
				color = c_silver;
				break;
			case COZY_TOKEN.MODIFIER:
				color = #0DE7F2;
				font = fnt_code_bold;
				break;
			case COZY_TOKEN.COMMENT:
				color = #2EAF27;
				font = fnt_code_italic;
				txt = string_replace_all(txt,"\t","    ");
				break;
			case COZY_TOKEN.DIRECTIVE:
				txt = $"#{txt}";
				color = c_gray;
				font = fnt_code_bold_italic;
				break;
			case COZY_TOKEN.LITERAL:
				if (is_string(txt))
				{
					txt = string_replace_all(txt,"\t","    ");
					txt = $"\"{txt}\"";
					color = #EFE025;
					break;
				}
				if (is_infinity(txt))
				{
					txt = "infinity";
					color = #B76FFF;
					font = fnt_code_bold;
					break;
				}
						
				txt = string(txt);
				color = #B76FFF;
				break;
			case COZY_TOKEN.LAMBDA_OPERATOR:
				txt = "=>";
				break;
			default:
				var name = structGetName(env.lexer.charTokens,token.type);
				if (is_string(name))
				{
					txt = name;
					if (name == "@" or name == "#")
					{
						color = #0DE7F2;
						font = fnt_code_bold;
					}
					else
						color = c_silver;
					break;
				}
						
				var name = structGetName(env.lexer.identifierTokens,token.type);
				if (is_string(name))
				{
					txt = name;
					color = #0DE7F2;
					font = fnt_code_bold;
					break;
				}
						
				txt = "???";
				color = c_red;
				break;
		}
				
		if (noDraw)
			continue;
				
		draw_set_color(color);
		draw_set_font(font);
		draw_text((token.col - 1) * w,(token.line - 1) * h,txt);
	}
	draw_set_font(fnt_code);
	
	surface_reset_target();
	
	gpu_set_blendmode(bm_normal);
	
	sourceCodeSurfaceNeedsChanged = false;
	
	return sourceCodeSurface;
}

structGetName = function(struct,value) {
	var names = struct_get_names(struct);
	for (var i = 0, n = array_length(names); i < n; i++)
	{
		var name = names[i];
		if (struct[$ name] == value)
			return name;
	}
	
	return undefined;
}

enum COZYTEST_VIEWING {
	FILE = 0,
	BYTECODE = 1,
	AST = 2,
	TOKENS = 3,
	__SIZE__ = 4
}

fileView = COZYTEST_VIEWING.FILE;

returnValues = [];

loadFile = function(fname,resetState=true) {
	if (!file_exists(fname))
		return "File doesn't exist";
	
	var errType = 0;
	var buffer = undefined;
	
	try {
		env.lexer.tokenizeFile(fname);
		errType++;
		tokens = variable_clone(env.lexer.tokens,1);
		ast = env.parser.parse(env.lexer);
		errType++;
		bytecode = env.compiler.compile(ast);
		errType++;
		
		fn = new CozyFunction(filename_name(fname),bytecode);
		
		if (resetState)
			env.resetState();
		
		currentPath = fname;
		
		sourceCode = "/// Couldn't load source code";
		
		buffer = buffer_load(currentPath);
		sourceCode = buffer_read(buffer,buffer_string);
		buffer_delete(buffer);
		
		sourceCode = string_replace_all(sourceCode,"\t","    ");
		sourceCodeSurfaceNeedsChanged = true;
		
		executionTime = -1;
		fileView = COZYTEST_VIEWING.FILE;
	}
	catch (e) {
		var txt = e;
		if (is_struct(e))
			txt = $"GM Error\nMessage: {e.message}\nScript: {e.script}\nLine: {e.line}";
		
		var type = "";
		switch (errType)
		{
			case 0:
				type = "Lex";
				break;
			case 1:
				type = "Parse";
				break;
			case 2:
				type = "Compile";
				break;
			case 3:
				type = "Unknown";
				break;
		}
		
		txt = $"{type} error: {txt}";
		
		env.stderrWriteLine(txt);
		
		if (buffer_exists(buffer))
			buffer_delete(buffer);
		
		return txt;
	}
	
	return "";
}
loadCompiled = function(fname,resetState=true) {
	if (!file_exists(fname))
		return "File doesn't exist";
	
	var errType = 0;
	var buffer = undefined;
	
	try {
		tokens = [
			new CozyToken(
				COZY_TOKEN.COMMENT,
				"/// Compiled code, view bytecode"
			),
			new CozyToken(
				COZY_TOKEN.EOF,
				undefined
			)
		];
		ast = new CozyNode(
			COZY_NODE.ROOT,
			undefined
		);
		buffer = buffer_load(fname);
		var bytecodeStruct = new CozyBytecode();
		bytecodeStruct.fromBuffer(buffer);
		bytecode = bytecodeStruct.bytecode;
		buffer_delete(buffer);
		errType++;
		
		fn = new CozyFunction(filename_name(fname),bytecode);
		
		if (resetState)
			env.resetState();
		
		currentPath = fname;
		
		sourceCode = "/// Compiled code, view bytecode";
		sourceCodeSurfaceNeedsChanged = true;
		
		executionTime = -1;
		fileView = COZYTEST_VIEWING.BYTECODE;
	}
	catch (e) {
		var txt = e;
		if (is_struct(e))
			txt = $"GM Error\nMessage: {e.message}\nScript: {e.script}\nLine: {e.line}";
		
		var type = "";
		switch (errType)
		{
			case 0:
				type = "Load";
				break;
			case 1:
				type = "Unknown";
				break;
		}
		
		txt = $"{type} error: {txt}";
		
		env.stderrWriteLine(txt);
		
		if (buffer_exists(buffer))
			buffer_delete(buffer);
		
		return txt;
	}
	
	return "";
}
run = function(resetState=true) {
	if (!cozylang_is_callable(fn))
		return "File not loaded";
	
	if (resetState)
		env.resetState();
	
	try {
		var start = get_timer();
		var result = cozylang_execute(fn,[],env.state);
		executionTime = (get_timer()-start)/1000;
		
		array_resize(returnValues,0);
		if (!result[0])
			return "";
	
		array_copy(returnValues,0,result,1,array_length(result)-1);
	}
	catch (e) {
		var txt = e;
		if (is_struct(e))
			txt = $"GM Error\nMessage: {e.message}\nScript: {e.script}\nLine: {e.line}";
		
		txt = $"Runtime error: {txt}";
		
		env.stderrWriteLine(txt);
		
		return txt;
	}
	
	return "";
}
saveCompiled = function(fname) {
	if (!cozylang_is_callable(fn))
		return "File not loaded";
	
	var buffer = undefined;
	
	try {
		buffer = buffer_create(1,buffer_grow,1);
		var bytecodeStruct = new CozyBytecode();
		bytecodeStruct.bytecode = bytecode;
		bytecodeStruct.intoBuffer(buffer);
		
		if (file_exists(fname))
			file_rename(fname,$"{fname}.bak");
		
		show_debug_message(fname);
		
		buffer_resize(buffer,buffer_tell(buffer));
		
		buffer_save(buffer,fname);
		buffer_delete(buffer);
	}
	catch (e) {
		var txt = e;
		if (is_struct(e))
			txt = $"GM Error\nMessage: {e.message}\nScript: {e.script}\nLine: {e.line}";
		
		if (buffer_exists(buffer))
			buffer_delete(buffer);
		
		txt = $"Save error: {txt}";
		
		env.stderrWriteLine(txt);
		
		return txt;
	}
	
	return "";
}
loadCustomLibraries = function() {
	var libraries = env.newLibrariesInDirectory("libraries");
	show_debug_message(libraries);
	
	for (var i = 0, n = array_length(libraries); i < n; i++)
	{
		var library = libraries[i];
		
		env.addLibrary(library.name,library);
		
		env.stdoutWriteLine($"Added library {library.name}");
	}
}

//alarm_set(0,10);