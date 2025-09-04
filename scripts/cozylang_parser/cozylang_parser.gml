
enum COZY_NODE {
	LITERAL = 0,
	BIN_OPERATOR = 1,
	PRE_OPERATOR = 2,
	POST_OPERATOR = 3,
	BODY = 4,
	ROOT = 5,
	IDENTIFIER = 6,
	LOCAL_VARIABLE = 7,
	IF = 8,
	WHILE = 9,
	FOR = 10,
	DO_WHILE = 11,
	RETURN = 12,
	CONTINUE = 13,
	BREAK = 14,
	SWITCH = 15,
	CASE = 16,
	CASE_DEFAULT = 17,
	ARRAY_LITERAL = 18,
	STRUCT_LITERAL = 19,
	FUNC_DECLARATION = 20,
	FUNC_EXPRESSION = 21,
	LOCAL_FUNC = 22,
	IMPORTS = 23,
	IMPORT = 24,
	CALL = 25,
	FUNC_ARGS = 26,
	ARGUMENT = 27,
	ARGUMENT_PARAMS = 28,
	DIRECTIVES = 29,
	DIRECTIVE = 30,
	CLASS_STRICT = 31,
	CONST_VARIABLE = 32,
	CONST_FUNC = 33,
	LOCAL_CONST_VARIABLE = 34,
	LOCAL_CONST_FUNC = 35,
	CLASS = 36,
	CLASS_CONSTRUCTOR = 37,
	CLASS_DESTRUCTOR = 38,
	CLASS_PROPERTY = 39,
	CLASS_FUNC = 40,
	TOKEN = 41,
	LOCAL_CLASS = 42,
	CONST_CLASS = 43,
	CLASS_PROPERTY_GETTER = 44,
	CLASS_PROPERTY_SETTER = 45,
	NEW_OBJECT = 46,
	LOCAL_CONST_CLASS = 47,
	MODIFIERS = 48,
	MODIFIER = 49,
	CLASS_OPERATOR = 50,
	IMPORTONLY = 51,
	IF_EXPRESSION = 52,
	__SIZE__ = 53,
}

function CozyNode(type,value=undefined) constructor {
	self.type = type;
	self.value = value;
	self.children = [];
	
	/// @param {Struct.CozyNode} node
	static addChild = function(node) {
		if (!is_struct(node) or !is_instanceof(node,CozyNode))
			return;
		
		array_push(self.children,node);
	}
	
	/// @returns {Array<Any>}
	static getAllChildrenValues = function() {
		var values = [];
		
		for (var i = 0, n = array_length(self.children); i < n; i++)
			array_push(values,self.children[i].value);
		
		return values;
	}
	
	static toString = function(pref="") {
		var str = "(";
		
		var q = is_string(self.value) ? "\"" : "";
		
		str += $"{self.type},\t{q}{self.value}{q},\t[";
		for (var i = 0; i < array_length(self.children); i++)
		{
			var childStr = is_struct(self.children[i]) ?
				self.children[i].toString(pref+"\t") :
				string(self.children[i]);
			str += $"\n{pref}\t{childStr}";
		}
		str += "\n"+pref+"]";
		
		return str+")";
	}
}

/// @ignore
/// @param {Struct.CozyParser} parser
/// @param {Struct.CozyLexer} lexer
/// @param {Struct.CozyNode} directiveNode
function __cozylang_directive_define_parse(parser,lexer,directiveNode) {
	var identifier = lexer.nextWithNewline();
	if (identifier.type != COZY_TOKEN.IDENTIFIER)
		throw $"Malformed define directive @ line: {identifier.line} col: {identifier.col}";
	
	var tokenNodes = [];
	
	var parsingDefine = true;
	while (parsingDefine)
	{
		var next = lexer.nextWithNewline();
		switch (next.type)
		{
			default:
				array_push(tokenNodes,new CozyNode(
					COZY_NODE.TOKEN,
					next
				));
				break;
			case COZY_TOKEN.BACKSLASH:
				var next = lexer.nextWithNewline();
				if (next.type != COZY_TOKEN.EOL)
					throw $"Malformed define directive @ line: {identifier.line} col: {identifier.col}";
				break;
			case COZY_TOKEN.EOL:
				parsingDefine = false;
				break;
		}
	}
	
	directiveNode.addChild(new CozyNode(
		COZY_NODE.IDENTIFIER,
		identifier.value
	));
	for (var i = 0, n = array_length(tokenNodes); i < n; i++)
		directiveNode.addChild(tokenNodes[i]);
}

/// @ignore
/// @param {Struct.CozyNode} directiveNode
/// @param {Struct.CozyLexer} lexer
function __cozylang_directive_define_modifyTokens(directiveNode,lexer) {
	var directiveName = directiveNode.children[0].value;
	
	var modifyingTokens = true;
	while (modifyingTokens)
	{
		var next = lexer.next();
		switch (next.type)
		{
			case COZY_TOKEN.IDENTIFIER:
				if (next.value == directiveName)
				{
					array_delete(lexer.tokens,lexer.tokenIndex-1,1);
					
					for (var i = 1, n = array_length(directiveNode.children); i < n; i++)
						array_insert(lexer.tokens,lexer.tokenIndex+i-2,directiveNode.children[i].value);
					
					lexer.tokenIndex += array_length(directiveNode.children)-2;
				}
				break;
			case COZY_TOKEN.EOF:
				modifyingTokens = false;
				break;
		}
	}
	
	//show_debug_message("after modification");
	//show_debug_message(lexer.tokens);
}

/// @ignore
/// @param {Struct.CozyParser} parser
/// @param {Struct.CozyLexer} lexer
/// @param {Struct.CozyNode} directiveNode
function __cozylang_directive_include_parse(parser,lexer,directiveNode) {
	var stringLiteral = lexer.nextWithNewline();
	if (stringLiteral.type != COZY_TOKEN.LITERAL or !is_string(stringLiteral.value))
		throw $"Malformed include directive @ line: {stringLiteral.line} col: {stringLiteral.col}";
	
	directiveNode.addChild(new CozyNode(
		COZY_NODE.LITERAL,
		stringLiteral.value
	));
	directiveNode.addChild(new CozyNode(
		COZY_NODE.LITERAL,
		lexer.tokenIndex
	));
}

/// @ignore
/// @param {Struct.CozyNode} directiveNode
/// @param {Struct.CozyLexer} lexer
function __cozylang_directive_include_modifyTokens(directiveNode,lexer) {
	var filepath = directiveNode.children[0].value;
	if (!lexer.env.fileExists(filepath))
	{
		lexer.env.stderrWriteLine($"Couldn't include file {filepath}");
		return;
	}
	
	var lexerPosition = directiveNode.children[1].value;
	
	var newLexer = new CozyLexer(lexer.env);
	
	newLexer.tokenizeFile(filepath);
	
	for (var i = 0, n = array_length(newLexer.tokens); i < n-1; i++)
		array_insert(lexer.tokens,i+lexerPosition,newLexer.tokens[i]);
	
	delete newLexer;
}

/// @param {Struct.CozyEnvironment} env
function CozyParser(env) constructor {
	self.env = env;
	
	self.env.directives[$ "define"].parseDirective = __cozylang_directive_define_parse;
	self.env.directives[$ "define"].modifyTokens = __cozylang_directive_define_modifyTokens;
	self.env.directives[$ "include"].parseDirective = __cozylang_directive_include_parse;
	self.env.directives[$ "include"].modifyTokens = __cozylang_directive_include_modifyTokens;
	
	/// @param {Struct.CozyLexer} lexer
	static parseDirectives = function(lexer) {
		var directivesNode = new CozyNode(
			COZY_NODE.DIRECTIVES,
			undefined
		);
		
		var directiveIndices = [];
		
		var parsingDirectives = true;
		while (parsingDirectives)
		{
			var next = lexer.next();
			switch (next.type)
			{
				default:
					break;
				case COZY_TOKEN.EOF:
					parsingDirectives = false;
					break;
				case COZY_TOKEN.DIRECTIVE:
					array_push(directiveIndices,lexer.tokenIndex-1);
					
					var start = lexer.tokenIndex;
					
					var directiveName = next.value;
					var directive = self.env.directives[$ directiveName];
					
					var directiveNode = new CozyNode(
						COZY_NODE.DIRECTIVE,
						directiveName
					);
					directive.parseDirective(self,lexer,directiveNode);
					
					directivesNode.addChild(directiveNode);
					
					for (var i = 0; i < lexer.tokenIndex-start; i++)
						array_push(directiveIndices,start+i);
					
					var prevPos = lexer.tokenIndex;
					
					directive.modifyTokens(directiveNode,lexer);
					lexer.tokenIndex = prevPos;
					break;
			}
		}
		
		for (var i = array_length(directiveIndices)-1; i >= 0; i--)
			lexer.remove(directiveIndices[i]);
		
		return directivesNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseImports = function(lexer) {
		var importsNode = new CozyNode(
			COZY_NODE.IMPORTS,
			undefined
		);
		
		var parsingImports = true;
		while (parsingImports)
		{
			var importKeyword = lexer.peek();
			
			switch (importKeyword.type)
			{
				case COZY_TOKEN.IMPORT:
					lexer.next();
				
					var importNode = self.parseImport(lexer);
					importsNode.addChild(importNode);
					break;
				default:
					parsingImports = false;
					break;
			}
			
			if (!parsingImports)
				break;
		}
		
		return importsNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseImport = function(lexer) {
		var names = [];
		
		var isImportOnly = false;
		
		var exclamationToken = lexer.peek();
		if (exclamationToken.type == COZY_TOKEN.OPERATOR)
		{
			if (exclamationToken.value != "!")
				throw $"Malformed import @ line: {exclamationToken.line} col: {exclamationToken.col}";
			
			isImportOnly = true;
			lexer.next();
		}
		
		var gettingNames = true;
		while (gettingNames)
		{
			var nameToken = lexer.peek();
			switch (nameToken.type)
			{
				default:
					throw $"Malformed import @ line: {nameToken.line} col: {nameToken.col}";
				case COZY_TOKEN.IDENTIFIER:
				case COZY_TOKEN.OPERATOR:
					array_push(names,nameToken.value);
					
					lexer.next();
					
					var next = lexer.peek();
					switch (next.type)
					{
						default:
							throw $"Malformed import @ line: {next.line} col: {next.col}";
						case COZY_TOKEN.OPERATOR:
							if (next.value != ".")
								throw $"Malformed import @ line: {next.line} col: {next.col}";
							
							lexer.next();
							break;
						case COZY_TOKEN.SEMICOLON:
							gettingNames = false;
							
							lexer.next();
							break;
					}
					break;
			}
			
			if (!gettingNames)
				break;
		}
				
		return new CozyNode(
			isImportOnly ?
				COZY_NODE.IMPORTONLY :
				COZY_NODE.IMPORT,
			names
		);
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseBody = function(lexer) {
		var bodyNode = new CozyNode(
			COZY_NODE.BODY,
			undefined
		);
		
		var parsingBody = true;
		while (parsingBody)
		{
			var result = self.parseStatement(lexer)
			if (!is_undefined(result.node))
				bodyNode.addChild(result.node);
			parsingBody = result.keepGoing;
			
			if (!parsingBody)
				break;
		}
		
		return bodyNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	static parseStatement = function(lexer) {
		var node = undefined;
		var keepGoing = true;
		
		var next = lexer.peek();
		//show_debug_message(next)
		switch (next.type)
		{
			default:
				throw $"Unexpected token @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.GOTO:
				throw $"goto statement is unimplemented @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.SEMICOLON:
				lexer.next();
				break;
			case COZY_TOKEN.EOF:
			case COZY_TOKEN.RIGHT_BRACKET:
				lexer.next();
				keepGoing = false;
				break;
			case COZY_TOKEN.NEW:
			case COZY_TOKEN.IDENTIFIER:
			case COZY_TOKEN.OPERATOR:
			case COZY_TOKEN.LEFT_PAREN:
				var exprNode = self.parseExpression(lexer);
				
				node = exprNode;
				break;
			case COZY_TOKEN.LOCAL:
				lexer.next();
				var localNode = self.parseLocal(lexer);
				
				node = localNode;
				break;
			case COZY_TOKEN.CONST:
				lexer.next();
				var constNode = self.parseConst(lexer);
				
				node = constNode;
				break;
			case COZY_TOKEN.IF:
				lexer.next();
				var ifNode = self.parseIf(lexer);
				
				node = ifNode;
				break;
			case COZY_TOKEN.WHILE:
				lexer.next();
				var whileNode = self.parseWhile(lexer);
				
				node = whileNode;
				break;
			case COZY_TOKEN.FOR:
				lexer.next();
				var forNode = self.parseFor(lexer);
				
				node = forNode;
				break;
			case COZY_TOKEN.DO:
				lexer.next();
				var forNode = self.parseDo(lexer);
				
				node = forNode;
				break;
			case COZY_TOKEN.FUNC:
				lexer.next();
				var funcNode = self.parseFunc(lexer);
				
				node = funcNode;
				break;
			case COZY_TOKEN.SWITCH:
				lexer.next();
				var switchNode = self.parseSwitch(lexer);
				
				node = switchNode;
				break;
			case COZY_TOKEN.CLASS:
				lexer.next();
				var classNode = self.parseClass(lexer);
				
				node = classNode;
				break;
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var node = self.parseModifier(lexer,next.value);
				
				node = node;
				break;
			case COZY_TOKEN.RETURN:
				lexer.next();
				var returnNode = self.parseReturn(lexer);
				
				node = returnNode;
				break;
			case COZY_TOKEN.BREAK:
				lexer.next();
				var breakNode = new CozyNode(
					COZY_NODE.BREAK,
					undefined
				);
				
				node = breakNode;
				break;
			case COZY_TOKEN.CONTINUE:
				lexer.next();
				var continueNode = new CozyNode(
					COZY_NODE.CONTINUE,
					undefined
				);
				
				node = continueNode;
				break;
		}
		
		return {
			node : node,
			keepGoing : keepGoing
		};
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @param {String} modifier
	/// @returns {Struct.CozyNode}
	static parseModifier = function(lexer,modifier) {
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed modifier statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.CLASS:
				lexer.next();
				var classNode = self.parseClass(lexer);
				var modifiersNode = classNode.children[0];
				modifiersNode.addChild(new CozyNode(
					COZY_NODE.MODIFIER,
					modifier
				));
				
				return classNode;
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var node = self.parseModifier(lexer,next.value);
				var modifiersNode = node.children[0];
				modifiersNode.addChild(new CozyNode(
					COZY_NODE.MODIFIER,
					modifier
				));
				
				return node;
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseLocal = function(lexer) {
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed local statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.FUNC:
				lexer.next();
				var funcNode = self.parseFunc(lexer);
				funcNode.type = COZY_NODE.LOCAL_FUNC;
				
				return funcNode;
			case COZY_TOKEN.CLASS:
				lexer.next();
				var classNode = self.parseClass(lexer);
				classNode.type = COZY_NODE.LOCAL_CLASS;
				
				return classNode;
			case COZY_TOKEN.IDENTIFIER:
				return self.parseLocalVariable(lexer);
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var node = self.parseModifier(lexer,next.value);
				switch (node.type)
				{
					case COZY_NODE.CLASS:
						node.type = COZY_NODE.LOCAL_CLASS;
						break;
				}
				
				return node;
			case COZY_TOKEN.CONST: // local const!!
				lexer.next();
				var constNode = self.parseConst(lexer);
				switch (constNode.type)
				{
					case COZY_NODE.CONST_VARIABLE:
						constNode.type = COZY_NODE.LOCAL_CONST_VARIABLE;
						break;
					case COZY_NODE.CONST_FUNC:
						constNode.type = COZY_NODE.LOCAL_CONST_FUNC;
						break;
					case COZY_NODE.CONST_CLASS:
						constNode.type = COZY_NODE.LOCAL_CONST_CLASS;
						break;
				}
				
				return constNode;
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseLocalVariable = function(lexer) {
		var localNode = new CozyNode(
			COZY_NODE.LOCAL_VARIABLE,
			""
		); 
		
		var identifier = lexer.next();
		if (identifier.type != COZY_TOKEN.IDENTIFIER)
			throw $"Malformed local variable statement @ line: {identifier.line} col: {identifier.col}";
		
		localNode.value = identifier.value;
		
		var equals = lexer.next();
		switch (equals.type)
		{
			default:
				throw $"Malformed local variable statement @ line: {equals.line} col: {equals.col}";
			case COZY_TOKEN.OPERATOR:
				if (equals.value != "=")
					throw $"Malformed local variable statement @ line: {equals.line} col: {equals.col}";
				break;
			case COZY_TOKEN.SEMICOLON: // local <identifier>;
				localNode.addChild(new CozyNode(
					COZY_NODE.LITERAL,
					undefined
				));
				
				return localNode;
		}
		
		var exprNode = self.parseExpression(lexer);
		
		var semicolon = lexer.next();
		if (semicolon.type != COZY_TOKEN.SEMICOLON)
			throw $"Malformed local variable statement @ line: {semicolon.line} col: {semicolon.col}";
		
		localNode.addChild(exprNode);
		
		return localNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseConst = function(lexer) {
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed const statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.FUNC:
				lexer.next();
				var funcNode = self.parseFunc(lexer);
				funcNode.type = COZY_NODE.CONST_FUNC;
				
				return funcNode;
			case COZY_TOKEN.CLASS:
				lexer.next();
				var classNode = self.parseClass(lexer);
				classNode.type = COZY_NODE.CONST_CLASS;
				
				return classNode;
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var node = self.parseModifier(lexer,next.value);
				switch (node.type)
				{
					case COZY_NODE.CLASS:
						node.type = COZY_NODE.CONST_CLASS;
						break;
				}
				
				return node;
			case COZY_TOKEN.IDENTIFIER:
				return self.parseConstVariable(lexer);
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseConstVariable = function(lexer) {
		var localNode = new CozyNode(
			COZY_NODE.CONST_VARIABLE,
			""
		); 
		
		var identifier = lexer.next();
		if (identifier.type != COZY_TOKEN.IDENTIFIER)
			throw $"Malformed const variable statement @ line: {identifier.line} col: {identifier.col}";
		
		localNode.value = identifier.value;
		
		var equals = lexer.next();
		if (equals.type != COZY_TOKEN.OPERATOR or equals.value != "=")
			throw $"Malformed const variable statement @ line: {equals.line} col: {equals.col}";
		
		var exprNode = self.parseExpression(lexer);
		
		var semicolon = lexer.next();
		if (semicolon.type != COZY_TOKEN.SEMICOLON)
			throw $"Malformed const variable statement @ line: {semicolon.line} col: {semicolon.col}";
		
		localNode.addChild(exprNode);
		
		return localNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseIf = function(lexer) {
		var ifNode = new CozyNode(
			COZY_NODE.IF,
			undefined
		);
		
		var exprNode = self.parseExpression(lexer,-infinity,true);
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed if statement @ line: {next.line} col: {next.col}";
		
		var trueNode = self.parseBody(lexer);
		
		// Check for else
		var falseNode = new CozyNode(
			COZY_NODE.BODY,
			undefined
		);
		
		var next = lexer.peek();
		if (next.type == COZY_TOKEN.ELSE)
		{
			lexer.next();
			var next = lexer.next();
			// Check for "else if"
			if (next.type == COZY_TOKEN.IF)
			{
				delete falseNode;
				falseNode = self.parseIf(lexer);
			}
			else
			{
				// Check for open bracket and skip
				if (next.type != COZY_TOKEN.LEFT_BRACKET)
					throw $"Malformed if statement @ line: {next.line} col: {next.col}";
				
				falseNode = self.parseBody(lexer);
			}
		}
		
		ifNode.addChild(exprNode);
		ifNode.addChild(trueNode);
		ifNode.addChild(falseNode);
		
		return ifNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseWhile = function(lexer) {
		var whileNode = new CozyNode(
			COZY_NODE.WHILE,
			undefined
		);
		
		var exprNode = self.parseExpression(lexer,-infinity,true);
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed while statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		whileNode.addChild(exprNode);
		whileNode.addChild(bodyNode);
		
		return whileNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseDo = function(lexer) {
		
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed do statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		var whileToken = lexer.peek();
		if (whileToken.type == COZY_TOKEN.WHILE)
		{
			lexer.next();
			
			var doWhileNode = new CozyNode(
				COZY_NODE.DO_WHILE,
				undefined
			);
			
			var exprNode = self.parseExpression(lexer);
			
			doWhileNode.addChild(exprNode);
			doWhileNode.addChild(bodyNode);
			
			return doWhileNode;
		}
		
		return bodyNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseFor = function(lexer) {
		var forNode = new CozyNode(
			COZY_NODE.FOR,
			undefined
		);
		
		// Check for open parenthesis and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_PAREN)
			throw $"Malformed for statement @ line: {next.line} col: {next.col}";
		
		var initResult = self.parseStatement(lexer);
		var initStatementNode = initResult.node;
		if (is_undefined(initStatementNode))
			initStatementNode = new CozyNode(COZY_NODE.BODY,undefined);
		
		var checkExprNode = self.parseExpression(lexer);
		
		// Check for semicolon and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.SEMICOLON)
			throw $"Malformed for statement @ line: {next.line} col: {next.col}";
		
		var endExprNode = self.parseExpression(lexer);
		
		// Check for semicolon and skip optionally
		if (lexer.peek().type == COZY_TOKEN.SEMICOLON)
			lexer.next();
		
		// Check for closed parenthesis and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.RIGHT_PAREN)
			throw $"Malformed for statement @ line: {next.line} col: {next.col}";
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed for statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		forNode.addChild(initStatementNode);
		forNode.addChild(checkExprNode);
		forNode.addChild(endExprNode);
		forNode.addChild(bodyNode);
		
		return forNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseFuncArguments = function(lexer) {
		var argsNode = new CozyNode(
			COZY_NODE.FUNC_ARGS,
			undefined
		);
		
		if (lexer.peek().type == COZY_TOKEN.LEFT_PAREN)
			lexer.next();
		
		if (lexer.peek().type == COZY_TOKEN.RIGHT_PAREN)
		{
			lexer.next();
			return argsNode;
		}
		
		var parsingFuncAguments = true;
		var needsToStop = false;
		while (parsingFuncAguments)
		{
			var argNode = new CozyNode(
				COZY_NODE.ARGUMENT,
				""
			);
			
			var first = lexer.next();
			switch (first.type)
			{
				default:
					throw $"Malformed function arguments @ line: {first.line} col: {first.col}";
				case COZY_TOKEN.IDENTIFIER:
					argNode.value = first.value;
					break;
				case COZY_TOKEN.PARAMS:
					var identifier = lexer.next();
					if (identifier.type != COZY_TOKEN.IDENTIFIER)
						throw $"Malformed function arguments @ line: {first.line} col: {first.col}";
					
					argNode.type = COZY_NODE.ARGUMENT_PARAMS;
					argNode.value = identifier.value;
					
					needsToStop = true;
					break;
			}
			
			var last = lexer.next();
			switch (last.type)
			{
				default:
					throw $"Malformed function arguments @ line: {last.line} col: {last.col}";
				case COZY_TOKEN.COMMA:
					if (needsToStop)
						throw $"Malformed function arguments @ line: {last.line} col: {last.col}";
					break;
				case COZY_TOKEN.RIGHT_PAREN:
					parsingFuncAguments = false;
					break;
			}
			
			argsNode.addChild(argNode);
		}
		
		return argsNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseFunc = function(lexer) {
		var funcNode = new CozyNode(
			COZY_NODE.FUNC_DECLARATION,
			""
		);
		
		var identifier = lexer.next();
		//show_debug_message(identifier);
		if (identifier.type != COZY_TOKEN.IDENTIFIER)
			throw $"Malformed func statement @ line: {identifier.line} col: {identifier.col}";
		
		funcNode.value = identifier.value;
		
		var argsNode = new CozyNode(
			COZY_NODE.FUNC_ARGS,
			undefined
		);
		
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed func statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.LEFT_PAREN:
				delete argsNode;
				argsNode = self.parseFuncArguments(lexer);
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				break;
		}
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed func statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		funcNode.addChild(argsNode);
		funcNode.addChild(bodyNode);
		
		return funcNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseClass = function(lexer) {
		var className = "";
		var parentName = "";
		var isStrict = false;
		
		// class name
		var next = lexer.next();
		switch (next.type)
		{
			default:
				throw $"Malformed class statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.IDENTIFIER:
				className = next.value;
				break;
			case COZY_TOKEN.OPERATOR:
				if (next.value != "!") // strict classes
					throw $"Malformed class statement @ line: {next.line} col: {next.col}";
				
				isStrict = true;
				
				var identifier = lexer.next();
				if (identifier.type != COZY_TOKEN.IDENTIFIER)
					throw $"Malformed class statement @ line: {next.line} col: {next.col}";
					
				className = identifier.value;
				break;
		}
		
		// class parent name
		var next = lexer.next();
		switch (next.type)
		{
			default:
				throw $"Malformed class statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.COLON:
				var inheritedIdentifier = lexer.next();
				if (inheritedIdentifier.type != COZY_TOKEN.IDENTIFIER)
					throw $"Malformed class statement @ line: {next.line} col: {next.col}";
				
				parentName = inheritedIdentifier.value;
				
				if (className == parentName)
					throw $"Malformed class statement @ line: {next.line} col: {next.col}";
				
				var leftBracket = lexer.next();
				if (leftBracket.type != COZY_TOKEN.LEFT_BRACKET)
					throw $"Malformed class statement @ line: {next.line} col: {next.col}";
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				break;
		}
		
		var classNode = new CozyNode(
			COZY_NODE.CLASS,
			className
		);
		classNode.addChild(new CozyNode(
			COZY_NODE.MODIFIERS,
			undefined
		));
		classNode.addChild(new CozyNode(
			COZY_NODE.CLASS_STRICT,
			isStrict
		));
		classNode.addChild(new CozyNode(
			COZY_NODE.IDENTIFIER,
			parentName
		));
		
		self.parseClassBody(lexer,classNode);
		
		return classNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @param {Struct.CozyNode} classNode
	/// @returns {Struct.CozyNode}
	static parseClassBody = function(lexer,classNode) {
		var parsingBody = true;
		while (parsingBody)
		{
			var result = self.parseClassStatement(lexer)
			if (!is_undefined(result.node))
				classNode.addChild(result.node);
			parsingBody = result.keepGoing;
			
			if (!parsingBody)
				break;
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	static parseClassStatement = function(lexer) {
		var node = undefined;
		var keepGoing = true;
		
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Unexpected token @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.OPERATOR_KW:
				if (!self.env.flags.operatorOverloading)
					throw $"Operator overloading is disabled @ line: {next.line} col: {next.col}";
				
				lexer.next();
				node = self.parseClassOperator(lexer);
				break;
			case COZY_TOKEN.CONSTRUCTOR:
				lexer.next();
				node = self.parseClassConstructor(lexer);
				break;
			case COZY_TOKEN.DESTRUCTOR:
				lexer.next();
				node = self.parseClassDestructor(lexer);
				break;
			case COZY_TOKEN.PROPERTY:
				lexer.next();
				node = self.parseClassProperty(lexer);
				break;
			case COZY_TOKEN.FUNC:
				lexer.next();
				node = self.parseFunc(lexer);
				array_insert(node.children,0,new CozyNode(
					COZY_NODE.MODIFIERS,
					undefined
				));
				node.type = COZY_NODE.CLASS_FUNC;
				break;
			case COZY_TOKEN.RIGHT_BRACKET:
				lexer.next();
				keepGoing = false;
				break;
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var result = self.parseClassModifier(lexer,next.value);
				node = result.node;
				keepGoing = result.keepGoing;
				break;
		}
		
		return {
			node : node,
			keepGoing : keepGoing
		};
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseClassOperator = function(lexer) {
		var operatorNode = new CozyNode(
			COZY_NODE.CLASS_OPERATOR,
			""
		);
		operatorNode.addChild(new CozyNode(
			COZY_NODE.MODIFIERS,
			undefined
		));
		
		var identifier = lexer.next();
		if (identifier.type != COZY_TOKEN.IDENTIFIER)
			throw $"Malformed operator statement @ line: {identifier.line} col: {identifier.col}";
		
		var hasArgument = true;
		
		switch (identifier.value)
		{
			default:
				throw $"Invalid operator type {identifier.value} @ line: {identifier.line} col: {identifier.col}";
			case "prefix":
			case "postfix":
				hasArgument = false;
			case "infix":
				break;
		}
		
		var operator = lexer.next();
		if (operator.type != COZY_TOKEN.OPERATOR)
			throw $"Malformed operator statement @ line: {operator.line} col: {operator.col}";
		operatorNode.value = operator.value;
		
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_PAREN)
			throw $"Malformed operator statement @ line: {next.line} col: {next.col}";
		
		var argumentIdentifier = undefined;
		if (hasArgument)
		{
			argumentIdentifier = lexer.next();
			if (argumentIdentifier.type != COZY_TOKEN.IDENTIFIER)
				throw $"Malformed operator statement @ line: {argumentIdentifier.line} col: {argumentIdentifier.col}";
		}
		
		var next = lexer.next();
		if (next.type != COZY_TOKEN.RIGHT_PAREN)
			throw $"Malformed operator statement @ line: {next.line} col: {next.col}";
		
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed operator statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		operatorNode.addChild(new CozyNode(
			COZY_NODE.IDENTIFIER,
			identifier.value
		));
		var argsNode = new CozyNode(
			COZY_NODE.FUNC_ARGS,
			undefined
		)
		if (hasArgument)
		{
			argsNode.addChild(new CozyNode(
				COZY_NODE.ARGUMENT,
				argumentIdentifier.value
			));
		}
		operatorNode.addChild(argsNode);
		operatorNode.addChild(bodyNode);
		
		return operatorNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @param {String} modifier
	static parseClassModifier = function(lexer,modifier) {
		var node = undefined;
		var keepGoing = true;
		
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Unexpected token @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.PROPERTY:
			case COZY_TOKEN.FUNC:
				var result = self.parseClassStatement(lexer);
				
				var modifiersNode = result.node.children[0];
				modifiersNode.addChild(new CozyNode(
					COZY_NODE.MODIFIER,
					modifier
				));
				
				node = result.node;
				break;
			case COZY_TOKEN.MODIFIER:
				lexer.next();
				var result = self.parseClassModifier(lexer,next.value);
				var node = result.node;
				var modifiersNode = node.children[0];
				modifiersNode.addChild(new CozyNode(
					COZY_NODE.MODIFIER,
					modifier
				));
				
				return result;
		}
		
		return {
			node : node,
			keepGoing : keepGoing
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseClassConstructor = function(lexer) {
		var constructorNode = new CozyNode(
			COZY_NODE.CLASS_CONSTRUCTOR,
			undefined
		);
		
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed constructor statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.LEFT_PAREN:
				lexer.next();
				
				var argsNode = self.parseFuncArguments(lexer);
				
				constructorNode.addChild(argsNode);
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				constructorNode.addChild(new CozyNode(COZY_NODE.FUNC_ARGS,undefined));
				break;
		}
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed constructor statement @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		constructorNode.addChild(bodyNode);
		
		return constructorNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseClassDestructor = function(lexer) {
		var destructorNode = new CozyNode(
			COZY_NODE.CLASS_DESTRUCTOR,
			undefined
		);
		destructorNode.addChild(new CozyNode(COZY_NODE.FUNC_ARGS,undefined));
		
		var next = lexer.next();
		switch (next.type)
		{
			default:
				throw $"Malformed destructor statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.LEFT_PAREN:
				var next = lexer.next();
				if (next.type != COZY_TOKEN.RIGHT_PAREN)
					throw $"Malformed destructor statement @ line: {next.line} col: {next.col}";
				
				// Check for open bracket and skip
				var next = lexer.next();
				if (next.type != COZY_TOKEN.LEFT_BRACKET)
					throw $"Malformed destructor statement @ line: {next.line} col: {next.col}";
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				break;
		}
		
		var bodyNode = self.parseBody(lexer);
		
		destructorNode.addChild(bodyNode);
		
		return destructorNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseClassProperty = function(lexer) {
		var propertyNode = new CozyNode(
			COZY_NODE.CLASS_PROPERTY,
			""
		);
		propertyNode.addChild(new CozyNode(
			COZY_NODE.MODIFIERS,
			undefined
		));
		propertyNode.addChild(new CozyNode(
			COZY_NODE.LITERAL,
			undefined
		));
		
		var isFallback = false;
		var isNumericIndex = false;
		
		var identifier = lexer.next();
		switch (identifier.type)
		{
			default:
				throw $"Malformed property statement @ line: {identifier.line} col: {identifier.col}";
			case COZY_TOKEN.IDENTIFIER:
				propertyNode.value = identifier.value;
				break;
			case COZY_TOKEN.HASHTAG:
				isNumericIndex = true;
				propertyNode.value = "#";
				break;
			case COZY_TOKEN.AT:
				isFallback = true;
				propertyNode.value = "@";
				break;
		}
		
		// Check for open bracket and skip
		var next = lexer.next();
		switch (next.type)
		{
			default:
				throw $"Malformed property statement @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.LEFT_BRACKET:
				break;
			case COZY_TOKEN.SEMICOLON:
				return propertyNode;
			case COZY_TOKEN.OPERATOR: /// property <identifier> = <expression>;
				if (next.value != "=")
					throw $"Malformed expression statement @ line: {next.line} col: {next.col}";
				
				switch (propertyNode.value)
				{
					default:
						break;
					case "@":
					case "#":
						throw $"Cannot set value for {propertyNode.value} property @ line: {next.line} col: {next.col}";
				}
				
				var exprNode = self.parseExpression(lexer);
				
				var semicolonToken = lexer.next();
				if (semicolonToken.type != COZY_TOKEN.SEMICOLON)
					throw $"Malformed property statement @ line: {semicolonToken.line} col: {semicolonToken.col}";
				
				propertyNode.children[1] = exprNode;
				
				return propertyNode;
		}
		
		var hasGetter = false;
		var hasSetter = false;
		
		var parsingProperty = true;
		while (parsingProperty)
		{
			var next = lexer.next();
			
			if (isNumericIndex or isFallback)
			{
				if (next.type == COZY_TOKEN.RIGHT_BRACKET and !(hasGetter or hasSetter))
					throw $"Empty {propertyNode.value} property @ line: {next.line} col: {next.col}";
				
				if (next.type == COZY_TOKEN.RIGHT_BRACKET and (hasGetter or hasSetter))
					break;
				
				if (next.type != COZY_TOKEN.IDENTIFIER)
					throw $"Malformed property statement @ line: {next.line} col: {next.col}";
				
				var indexIdentifier = next;
				var next = lexer.next();
				switch (next.type)
				{
					default:
						throw $"Malformed property statement @ line: {next.line} col: {next.col}";
					case COZY_TOKEN.COMMA: // this is a setter!
						if (hasSetter)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						var valueIdentifier = lexer.next();
						if (valueIdentifier.type != COZY_TOKEN.IDENTIFIER)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						hasSetter = true;
						
						var setterNode = new CozyNode(
							COZY_NODE.CLASS_PROPERTY_SETTER,
							undefined
						);
						
						var leftBrack = lexer.next();
						if (leftBrack.type != COZY_TOKEN.LEFT_BRACKET)
							throw $"Malformed property statement @ line: {leftBrack.line} col: {leftBrack.col}";
						
						var setterBodyNode = self.parseBody(lexer);
						var argsNode = new CozyNode(
							COZY_NODE.FUNC_ARGS,
							undefined
						);
						
						argsNode.addChild(new CozyNode(
							COZY_NODE.ARGUMENT,
							indexIdentifier.value
						));
						argsNode.addChild(new CozyNode(
							COZY_NODE.ARGUMENT,
							valueIdentifier.value
						));
						
						setterNode.addChild(argsNode);
						setterNode.addChild(setterBodyNode);
						
						propertyNode.addChild(setterNode);
						break;
					case COZY_TOKEN.LEFT_BRACKET: // this is a getter!
						if (hasGetter)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						hasGetter = true;
						
						var getterNode = new CozyNode(
							COZY_NODE.CLASS_PROPERTY_GETTER,
							undefined
						);
						
						var getterBodyNode = self.parseBody(lexer);
						var argsNode = new CozyNode(
							COZY_NODE.FUNC_ARGS,
							undefined
						);
						
						argsNode.addChild(new CozyNode(
							COZY_NODE.ARGUMENT,
							indexIdentifier.value
						));
						
						getterNode.addChild(argsNode);
						getterNode.addChild(getterBodyNode);
						
						propertyNode.addChild(getterNode);
						break;
				}
			}
			else
			{
				if (next.type == COZY_TOKEN.RIGHT_BRACKET)
					break;
					
				switch (next.type)
				{
					default:
						throw $"Malformed property statement @ line: {next.line} col: {next.col}";
					case COZY_TOKEN.LEFT_BRACKET:
						if (hasGetter)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						hasGetter = true;
						
						var getterNode = new CozyNode(
							COZY_NODE.CLASS_PROPERTY_GETTER,
							undefined
						);
						
						var getterBodyNode = self.parseBody(lexer);
							
						getterNode.addChild(new CozyNode(
							COZY_NODE.FUNC_ARGS,
							undefined
						));
						getterNode.addChild(getterBodyNode);
						
						propertyNode.addChild(getterNode);
						break;
					case COZY_TOKEN.IDENTIFIER:
						if (hasSetter)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						var leftBrack = lexer.next();
						if (leftBrack.type != COZY_TOKEN.LEFT_BRACKET)
							throw $"Malformed property statement @ line: {next.line} col: {next.col}";
						
						hasSetter = true;
						
						var setterNode = new CozyNode(
							COZY_NODE.CLASS_PROPERTY_SETTER,
							undefined
						);
						
						var setterBodyNode = self.parseBody(lexer);
						
						var argsNode = new CozyNode(
							COZY_NODE.FUNC_ARGS,
							undefined
						);
						argsNode.addChild(new CozyNode(
							COZY_NODE.ARGUMENT,
							next.value
						));
						
						setterNode.addChild(argsNode);
						setterNode.addChild(setterBodyNode);
						
						propertyNode.addChild(setterNode);
						break;
				}
			}
		}
		
		return propertyNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseReturn = function(lexer) {
		var returnNode = new CozyNode(
			COZY_NODE.RETURN,
			undefined
		);
		
		if (lexer.peek().type == COZY_TOKEN.SEMICOLON)
		{
			lexer.next();
			return returnNode;
		}
		
		var parsingReturn = true;
		while (parsingReturn)
		{
			var exprNode = self.parseExpression(lexer);
			
			returnNode.addChild(exprNode);
			
			var next = lexer.peek();
			switch (next.type)
			{
				default:
					throw $"Malformed return statement @ line: {next.line} col: {next.col}";
				case COZY_TOKEN.COMMA:
					lexer.next();
					break;
				case COZY_TOKEN.SEMICOLON:
					parsingReturn = false;
					lexer.next();
					break;
			}
		}
		
		return returnNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseSwitch = function(lexer) {
		var switchNode = new CozyNode(
			COZY_NODE.SWITCH,
			undefined
		);
		
		var exprNode = self.parseExpression(lexer,-infinity,true);
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed switch statement @ line: {next.line} col: {next.col}";
		
		var caseNodes = [];
		
		// Get cases
		var parsingSwitch = true;
		var hasDefault = false;
		while (parsingSwitch)
		{
			var next = lexer.peek();
			switch (next.type)
			{
				default:
					throw $"Malformed switch statement @ line: {next.line} col: {next.col}";
				case COZY_TOKEN.CASE:
					lexer.next();
					var caseNode = self.parseSwitchCase(lexer);
					
					array_push(caseNodes,caseNode);
					break;
				case COZY_TOKEN.DEFAULT:
					lexer.next();
					
					if (hasDefault)
						throw $"Duplicate default case in switch statement @ line: {next.line} col: {next.col}";
					
					var defaultNode = self.parseSwitchDefault(lexer);
					
					array_push(caseNodes,defaultNode);
					
					hasDefault = true;
					break;
				case COZY_TOKEN.RIGHT_BRACKET:
					parsingSwitch = false;
					break;
			}
		}
		
		switchNode.addChild(exprNode);
		for (var i = 0, n = array_length(caseNodes); i < n; i++)
			switchNode.addChild(caseNodes[i]);
		
		return switchNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseSwitchCase = function(lexer) {
		var caseNode = new CozyNode(
			COZY_NODE.CASE,
			undefined
		);
		
		// Parse expression
		var exprNode = self.parseExpression(lexer,-infinity,true);
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed switch case @ line: {next.line} col: {next.col}"
		
		var bodyNode = self.parseBody(lexer);
		
		caseNode.addChild(exprNode);
		caseNode.addChild(bodyNode);
		
		return caseNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseSwitchDefault = function(lexer) {
		var defaultNode = new CozyNode(
			COZY_NODE.CASE_DEFAULT,
			undefined
		);
		
		// Check for identifier
		var identifier = lexer.next();
		switch (identifier.type)
		{
			default:
				throw $"Malformed switch default case @ line: {identifier.line} col: {identifier.col}";
			case COZY_TOKEN.IDENTIFIER:
				defaultNode.value = identifier.value;
				
				var leftBrack = lexer.next();
				if (leftBrack.type != COZY_TOKEN.LEFT_BRACKET)
					throw $"Malformed switch default case @ line: {identifier.line} col: {identifier.col}"
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				break;
		}
		
		var bodyNode = self.parseBody(lexer);
		
		defaultNode.addChild(bodyNode);
		
		return defaultNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @param {Real} minBindingPower
	/// @returns {Struct.CozyNode}
	static parseExpression = function(lexer,minBindingPower=-infinity,parenOnly=false) {
		var lhs = lexer.next();
		
		if (parenOnly and lhs.type != COZY_TOKEN.LEFT_PAREN)
			throw $"Expected open parenthesis in expression @ line: {lhs.line} col: {lhs.col}";
		
		switch (lhs.type)
		{
			default:
				throw $"Unexpected token in expression";
			case COZY_TOKEN.SWITCH:
				lhs = self.parseSwitch(lexer);
				lexer.next();
				break;
			case COZY_TOKEN.FUNC:
				lhs = self.parseFuncExpression(lexer);
				break;
			case COZY_TOKEN.LEFT_PAREN:
				lhs = self.parseExpression(lexer);
				
				var rightParen = lexer.next();
				if (rightParen.type != COZY_TOKEN.RIGHT_PAREN)
					throw $"Missing parenthesis in expression @ line: {rhs.line} col: {rhs.col}";
				
				if (parenOnly)
					return lhs;
				break;
			case COZY_TOKEN.IDENTIFIER:
				lhs = new CozyNode(
					COZY_NODE.IDENTIFIER,
					lhs.value
				);
				break;
			case COZY_TOKEN.LITERAL:
				lhs = new CozyNode(
					COZY_NODE.LITERAL,
					lhs.value
				);
				break;
			case COZY_TOKEN.OPERATOR:
				if (!self.env.isValidPrefixOperator(lhs.value))
					throw $"Invalid operator {lhs.value} in expression @ line: {lhs.line} col: {lhs.col}";
				
				var rightBP = self.env.getPrefixOpBindingPower(lhs.value);
				var rhs = self.parseExpression(lexer,rightBP);
				
				lhs = new CozyNode(
					COZY_NODE.PRE_OPERATOR,
					lhs.value
				);
				lhs.addChild(rhs);
				break;
			case COZY_TOKEN.NEW:
				lhs = self.parseNew(lexer);
				break;
			case COZY_TOKEN.IF:
				lhs = self.parseIfExpression(lexer);
				break;
		}
		
		var parsingExpression = true;
		while (parsingExpression)
		{
			var continueExpression = false;
			
			if (lexer.peekWithNewline().type == COZY_TOKEN.EOL)
				break;
			
			var op = lexer.peek();
			switch (op.type)
			{
				default:
					throw $"Unexpected token in expression @ line: {op.line} col: {op.col}";
				case COZY_TOKEN.LEFT_PAREN:
					lexer.next();
					
					var expressionNodes = self.parseCallArguments(lexer);
					
					var callNode = new CozyNode(
						COZY_NODE.CALL,
						undefined
					);
					callNode.addChild(lhs);
					
					for (var i = 0, n = array_length(expressionNodes); i < n; i++)
						callNode.addChild(expressionNodes[i]);
					
					lhs = callNode;
					
					continueExpression = true;
					break;
				case COZY_TOKEN.RIGHT_PAREN:
				case COZY_TOKEN.RIGHT_SQ_BRACK:
				case COZY_TOKEN.COMMA:
					parsingExpression = false;
					break;
				case COZY_TOKEN.EOF:
				case COZY_TOKEN.SEMICOLON:
					parsingExpression = false;
					break;
				case COZY_TOKEN.OPERATOR:
					if (!self.env.isValidOperator(op.value))
						throw $"Invalid operator {op.value} in expression @ line: {op.line} col: {op.col}";
					break;
				case COZY_TOKEN.LEFT_SQ_BRACK:
					lexer.next();
					
					var rhs = self.parseExpression(lexer);
				
					var rightSqBrack = lexer.next();
					if (rightSqBrack.type != COZY_TOKEN.RIGHT_SQ_BRACK)
						throw $"Missing brackets in expression @ line: {rightSqBrack.line} col: {rightSqBrack.col}";
					
					var opNode = new CozyNode(
						COZY_NODE.BIN_OPERATOR,
						"["
					);
					opNode.addChild(lhs);
					opNode.addChild(rhs);
					
					lhs = opNode;
					
					continueExpression = true;
					break;
			}
			
			if (!parsingExpression)
				break;
			if (continueExpression)
				continue;
			
			if (self.env.isValidPostfixOperator(op.value))
			{
				var leftBP = self.env.getPostfixOpBindingPower(op.value);
				if (leftBP < minBindingPower)
					break;
				lexer.next();
				
				var opNode = new CozyNode(
					COZY_NODE.POST_OPERATOR,
					op.value
				);
				opNode.addChild(lhs);
				
				lhs = opNode;
				continue;
			}
			
			if (self.env.isValidOperator(op.value))
			{
				var bindingPower = self.env.getInfixOpBindingPower(op.value);
				if (bindingPower[0] < minBindingPower)
					break;
				lexer.next();
				
				var rhs = self.parseExpression(lexer,bindingPower[1]);
				//show_debug_message(rhs)
			
				var opNode = new CozyNode(
					COZY_NODE.BIN_OPERATOR,
					op.value
				);
				opNode.addChild(lhs);
				opNode.addChild(rhs);
				
				if (op.value == ".")
				{
					if (rhs.type == COZY_NODE.BIN_OPERATOR and rhs.value == ".")
					{
						opNode.children[0] = new CozyNode(
							COZY_NODE.BIN_OPERATOR,
							"."
						);
						opNode.children[0].addChild(lhs);
						opNode.children[0].addChild(rhs.children[0]);
					
						opNode.children[1] = rhs.children[1];
					}
					if (rhs.type == COZY_NODE.CALL)
					{
						opNode.children[0] = new CozyNode(
							COZY_NODE.BIN_OPERATOR,
							"."
						);
						opNode.children[0].addChild(lhs);
						opNode.children[0].addChild(rhs.children[0]);
					
						opNode.type = COZY_NODE.CALL;
						opNode.value = undefined;
					
						array_pop(opNode.children);
					
						for (var i = 1, n = array_length(rhs.children); i < n; i++)
						{
							opNode.children[i] = rhs.children[i];
						}
					}
				}
			
				lhs = opNode;
				continue;
			}
			break;
		}
		
		return lhs;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseIfExpression = function(lexer) {
		var ifExprNode = new CozyNode(
			COZY_NODE.IF_EXPRESSION,
			undefined
		);
		
		var exprNode = self.parseExpression(lexer,-infinity,true);
		var trueNode = self.parseExpression(lexer,-infinity,true);
		
		var elseNode = lexer.next();
		if (elseNode.type != COZY_TOKEN.ELSE)
			throw $"Malformed if expression @ line: {elseNode.line} col: {elseNode.col}";
		
		var falseNode = self.parseExpression(lexer,-infinity,true);
		
		ifExprNode.addChild(exprNode);
		ifExprNode.addChild(trueNode);
		ifExprNode.addChild(falseNode);
		
		return ifExprNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseNew = function(lexer) {
		var exprNode = self.parseExpression(lexer);
		switch (exprNode.type)
		{
			default:
				throw $"Malformed new expression @ line: {exprNode.line} col: {exprNode.col}";
			case COZY_NODE.CALL:
				exprNode.type = COZY_NODE.NEW_OBJECT;
				return exprNode;
			case COZY_NODE.BIN_OPERATOR:
				switch (exprNode.value)
				{
					default:
						throw $"Malformed new expression @ line: {exprNode.line} col: {exprNode.col}";
					case ".":
					case "[":
						break;
				}
			case COZY_NODE.IDENTIFIER:
				var newNode = new CozyNode(
					COZY_NODE.NEW_OBJECT,
					undefined
				);
				newNode.addChild(exprNode);
				
				return newNode;
		}
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parseFuncExpression = function(lexer) {
		var funcNode = new CozyNode(
			COZY_NODE.FUNC_EXPRESSION,
			undefined
		);
		
		var next = lexer.peek();
		switch (next.type)
		{
			default:
				throw $"Malformed func expression @ line: {next.line} col: {next.col}";
			case COZY_TOKEN.LEFT_PAREN:
				lexer.next();
				
				var argsNode = self.parseFuncArguments(lexer);
				
				funcNode.addChild(argsNode);
				break;
			case COZY_TOKEN.LEFT_BRACKET:
				funcNode.addChild(new CozyNode(COZY_NODE.FUNC_ARGS,undefined));
				break;
		}
		
		// Check for open bracket and skip
		var next = lexer.next();
		if (next.type != COZY_TOKEN.LEFT_BRACKET)
			throw $"Malformed func expression @ line: {next.line} col: {next.col}";
		
		var bodyNode = self.parseBody(lexer);
		
		funcNode.addChild(bodyNode);
		
		return funcNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Array<Struct.CozyNode>}
	static parseCallArguments = function(lexer) {
		var expressionNodes = [];
		
		if (lexer.peek().type == COZY_TOKEN.RIGHT_PAREN)
		{
			lexer.next();
			/// @feather disable GM1045
			return [];
			/// @feather enable GM1045
		}
		
		var parsingArguments = true;
		while (parsingArguments)
		{
			var next = lexer.peek();
			switch (next.type)
			{
				default:
					throw $"Malformed function call @ line: {next.line} col: {next.col}";
				case COZY_TOKEN.LITERAL:
				case COZY_TOKEN.IDENTIFIER:
				case COZY_TOKEN.OPERATOR:
				case COZY_TOKEN.LEFT_PAREN:
				case COZY_TOKEN.NEW:
				//case COZY_TOKEN.LEFT_SQ_BRACK: /// TODO: UNCOMMENT WHEN ARRAY LITERALS EXIST!
				//case COZY_TOKEN.LEFT_BRACKET:  /// TODO: UNCOMMENT WHEN STRUCT LITERALS EXIST!
					array_push(expressionNodes,self.parseExpression(lexer));
					break;
			}
			
			var next = lexer.next();
			switch (next.type)
			{
				default:
					throw $"Malformed function call @ line: {next.line} col: {next.col}";
				case COZY_TOKEN.RIGHT_PAREN:
					parsingArguments = false;
					break;
				case COZY_TOKEN.COMMA:
					break;
			}
			
			
		}
		
		return expressionNodes;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @returns {Struct.CozyNode}
	static parse = function(lexer) {
		var rootNode = new CozyNode(
			COZY_NODE.ROOT,
			undefined
		);
		
		// Directives
		var directivesNode = self.parseDirectives(lexer);
		lexer.resetToStart();
		
		// Remove all line breaks and comments
		self.removeTokensOfType(lexer,COZY_TOKEN.EOL);
		lexer.resetToStart();
		self.removeTokensOfType(lexer,COZY_TOKEN.COMMENT);
		lexer.resetToStart();
		
		// Imports first
		var importsNode = self.parseImports(lexer);
		
		// Then parse like normal
		var bodyNode = self.parseBody(lexer);
		
		// Apply directive post-parse modifications to body
		for (var i = 0, n = array_length(directivesNode.children); i < n; i++)
		{
			var directiveNode = directivesNode.children[i];
			var directive = self.env.directives[$ directiveNode.value];
			
			directive.modifyPostParse(directiveNode,bodyNode);
			
		}
		
		// Add to root
		rootNode.addChild(directivesNode);
		rootNode.addChild(importsNode);
		rootNode.addChild(bodyNode);
		
		return rootNode;
	}
	
	/// @param {Struct.CozyLexer} lexer
	/// @param {Enum.COZY_TOKEN} type
	static removeTokensOfType = function(lexer,type) {
		var indices = [];
		
		var removing = true;
		while (removing)
		{
			var next = lexer.next();
			switch (next.type)
			{
				case COZY_TOKEN.EOF:
					removing = false;
					break;
				default:
					if (next.type == type)
						array_push(indices,lexer.tokenIndex-1);
					break;
			}
		}
		
		for (var i = array_length(indices)-1; i >= 0; i--)
			lexer.remove(indices[i]);
	}
}