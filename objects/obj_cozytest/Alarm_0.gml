/*var env = new CozyEnvironment();

env.lexer.tokenizeFile($"singleton.cozy");
show_debug_message(env.lexer.tokens);

var ast = env.parser.parse(env.lexer);
show_debug_message(ast);

var bytecode = env.compiler.compile(ast);
show_debug_message(bytecode);

show_debug_message(__cozylang_debug_disassemble(bytecode));

var func = new CozyFunction("program",bytecode);
var start = get_timer();
env.state.runFunction(func);

//show_debug_message(__cozylang_debug_disassemble(env.state.globals.Singleton.statics.GetInstance.bytecode));

show_debug_message(env.state.globals);
var timeTaken = (get_timer()-start)/1000;
show_debug_message($"execution took {timeTaken}ms ({timeTaken/(1000/60)*100}% of total frame time)");

//env.lexer.tokenizeString(@'print("Hello, World!");');

//show_debug_message(env.lexer.tokens);

/*var state = new CozyState();

/*
	if (1 + 1 == 2)
	{
	    return "Hello, World!";
	}
	else if (1 + 2 == 3)
	{
	    return "Goodbye, World!";
	}
	
	# if
	# 1 + 1
	$0000 - PUSH_CONST 1
	$0002 - PUSH_CONST 1
	$0004 - ADD
	# == 2
	$0005 - PUSH_CONST 2
	$0007 - EQUALS
	$0008 - JUMP_IF_FALSE $0010
	# return "Hello, World!"
		$000A - PUSH_CONST "Hello, World!"
		$000C - RETURN 1
		$000E - JUMP $0020
	# else if
	# 1 + 2
	$0010 - PUSH_CONST 1
	$0012 - PUSH_CONST 2
	$0014 - ADD
	# == 3
	$0015 - PUSH_CONST 3
	$0017 - EQUALS
	$0018 - JUMP_IF_FALSE $0020
	# return "Goodbye, World!"
		$001A - PUSH_CONST "Goodbye, World!"
		$001C - RETURN 1
		$001E - JUMP $0020
	$0020 - RETURN 0

var code = [
	COZY_INSTR.JUMP,0,
	COZY_INSTR.HALT,
];/*[
	// if
	// 1 + 1
	COZY_INSTR.PUSH_CONST,1,
	COZY_INSTR.PUSH_CONST,1,
	COZY_INSTR.ADD,
	// == 2
	COZY_INSTR.PUSH_CONST,2,
	COZY_INSTR.EQUALS,
	COZY_INSTR.JUMP_IF_FALSE,16,
	// return "Hello, World!"
		COZY_INSTR.PUSH_CONST,"Hello, World!",
		COZY_INSTR.RETURN,1,
		COZY_INSTR.JUMP,32,
	// else if
	// 1 + 2
	COZY_INSTR.PUSH_CONST,1,
	COZY_INSTR.PUSH_CONST,2,
	COZY_INSTR.ADD,
	// == 3
	COZY_INSTR.PUSH_CONST,3,
	COZY_INSTR.EQUALS,
	COZY_INSTR.JUMP_IF_FALSE,32,
	// return "Hello, World!"
		COZY_INSTR.PUSH_CONST,"Goodbye, World!",
		COZY_INSTR.RETURN,1,
		COZY_INSTR.JUMP,32,
	COZY_INSTR.HALT,
];

var n = state.runFunction(new CozyFunction("program",code));

show_debug_message(n);
show_debug_message(state.stack);
show_debug_message(state.popStack());