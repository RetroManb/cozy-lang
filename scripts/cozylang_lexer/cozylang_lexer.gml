enum COZY_TOKEN {
	EOF = 0,
	LEFT_BRACKET = 1,
	LEFT_PAREN = 2,
	LEFT_SQ_BRACK = 3,
	RIGHT_BRACKET = 4,
	RIGHT_PAREN = 5,
	RIGHT_SQ_BRACK = 6,
	IDENTIFIER = 7,
	LITERAL = 8,
	OPERATOR = 9,
	SEMICOLON = 10,
	COLON = 11,
	COMMA = 12,
	PARAMS = 13,
	IF = 14,
	ELSE = 15,
	WHILE = 16,
	FOR = 17,
	FUNC = 18,
	SWITCH = 19,
	CASE = 20,
	DEFAULT = 21,
	RETURN = 22,
	BREAK = 23,
	CONTINUE = 24,
	IMPORT = 25,
	LOCAL = 26,
	CONST = 27,
	GOTO = 28,
	DO = 29,
	CLASS = 30,
	PROPERTY = 31,
	CONSTRUCTOR = 32,
	DESTRUCTOR = 33,
	NEW = 34,
	BACKSLASH = 35,
	LAMBDA_OPERATOR = 36,
	HASHTAG = 37,
	AT = 38,
	DIRECTIVE = 39,
	EOL = 40,
	OPERATOR_KW = 41,
	MODIFIER = 42,
	COMMENT = 43,
	__SIZE__ = 44,
}

enum COZY_LEXER_STATE {
	DEFAULT = 0,
	STRING_LITERAL = 1,
	NUMBER_LITERAL = 2,
	IDENTIFIER = 3,
	OPERATOR = 4,
	COMMENT = 5,
	COMMENT_BLOCK = 6,
	DIRECTIVE = 7,
	__SIZE__ = 8,
}

/// @ignore
function __cozylang_char_is_letter(char) {
	gml_pragma("forceinline");
	return (char >= 0x41 and char <= 0x5A) or
		(char >= 0x61 and char <= 0x7A);
}

/// @ignore
function __cozylang_char_is_letter_or_underscore(char) {
	gml_pragma("forceinline");
	return char == 0x5F or (char >= 0x41 and char <= 0x5A) or
		(char >= 0x61 and char <= 0x7A);
}

/// @ignore
function __cozylang_char_is_digit(char) {
	gml_pragma("forceinline");
	return char >= 0x30 and char <= 0x39;
}

/// @ignore
function __cozylang_char_is_whitespace(char) {
	gml_pragma("forceinline");
	return char <= 0x20 or (char >= 0x7F and char <= 0xFF);
}

/// @param {Enum.COZY_TOKEN} type
/// @param {Any} value
function CozyToken(type,value,line=1,col=1) constructor {
	self.type = type;
	self.value = value;
	self.line = line;
	self.col = col;
}

/// @param {Struct.CozyEnvironment} env
function CozyLexer(env) constructor {
	self.env = env;
	
	self.tokens = [];
	self.tokenIndex = 0;
	
	self.operatorCharacters = "+-*/<>=!~|&^?.%";
	self.charTokens = {}
	self.charTokens[$ "{"] = COZY_TOKEN.LEFT_BRACKET;
	self.charTokens[$ "("] = COZY_TOKEN.LEFT_PAREN;
	self.charTokens[$ "["] = COZY_TOKEN.LEFT_SQ_BRACK;
	self.charTokens[$ "}"] = COZY_TOKEN.RIGHT_BRACKET;
	self.charTokens[$ ")"] = COZY_TOKEN.RIGHT_PAREN;
	self.charTokens[$ "]"] = COZY_TOKEN.RIGHT_SQ_BRACK;
	self.charTokens[$ ";"] = COZY_TOKEN.SEMICOLON;
	self.charTokens[$ ":"] = COZY_TOKEN.COLON;
	self.charTokens[$ ","] = COZY_TOKEN.COMMA;
	self.charTokens[$ "@"] = COZY_TOKEN.AT;
	self.charTokens[$ "#"] = COZY_TOKEN.HASHTAG;
	self.charTokens[$ "\\"] = COZY_TOKEN.BACKSLASH;
	
	self.identifierTokens = {
		"if" : COZY_TOKEN.IF,
		"else" : COZY_TOKEN.ELSE,
		"while" : COZY_TOKEN.WHILE,
		"for" : COZY_TOKEN.FOR,
		"func" : COZY_TOKEN.FUNC,
		"switch" : COZY_TOKEN.SWITCH,
		"case" : COZY_TOKEN.CASE,
		"default" : COZY_TOKEN.DEFAULT,
		"return" : COZY_TOKEN.RETURN,
		"break" : COZY_TOKEN.BREAK,
		"continue" : COZY_TOKEN.CONTINUE,
		"property" : COZY_TOKEN.PROPERTY,
		"import" : COZY_TOKEN.IMPORT,
		"params" : COZY_TOKEN.PARAMS,
		"local" : COZY_TOKEN.LOCAL,
		"const" : COZY_TOKEN.CONST,
		"goto" : COZY_TOKEN.GOTO,
		"do" : COZY_TOKEN.DO,
		"class" : COZY_TOKEN.CLASS,
		"property" : COZY_TOKEN.PROPERTY,
		"constructor" : COZY_TOKEN.CONSTRUCTOR,
		"destructor" : COZY_TOKEN.DESTRUCTOR,
		"new" : COZY_TOKEN.NEW,
		"delete" : COZY_TOKEN.OPERATOR,
		"instanceof" : COZY_TOKEN.OPERATOR,
		"classof" : COZY_TOKEN.OPERATOR,
		"is" : COZY_TOKEN.OPERATOR,
		"operator" : COZY_TOKEN.OPERATOR_KW,
	};
	self.identifierModifiers = [
		"final","static",
	];
	self.identifierLiterals = {
		"undefined" : undefined,
		"true" : true,
		"false" : false,
		"infinity" : infinity,
		"NaN" : NaN,
	};
	self.identifierOperators = {
		"and" : "&&",
		"or" : "||",
		"xor" : "^^",
		"not" : "!",
	}
	self.invalidIdentifiers = [];
	self.invalidIdentifiers = array_union(self.invalidIdentifiers,self.env.bannedNames);
	self.operatorTokens = {};
	self.operatorTokens[$ "=>"] = COZY_TOKEN.LAMBDA_OPERATOR;
	
	static reset = function() {
		array_resize(self.tokens,0);
		self.resetToStart();
	}
	
	/// @param {Enum.COZY_TOKEN} type
	/// @param {Any} value
	static pushToken = function(type,value,positionInfo) {
		var tok = new CozyToken(
			type,
			value,
			positionInfo.line,
			positionInfo.col
		);
		array_push(self.tokens,tok);
		return tok;
	}
	
	/// @param {String} codeString
	static tokenizeString = function(codeString) {
		self.reset();
		
		codeString += chr(0x1A);
		
		var state = COZY_LEXER_STATE.DEFAULT;
		var current = "";
		var comment = "";
		var stringChar = 0;
		var rawString = false;
		var stringEscaping = false;
		var positionInfo = {
			line : 1,
			col : 1
		}
		var lastPositionI = 0;
		
		for (var i = 0, n = string_length(codeString); i < n; i++)
		{
			var char = string_ord_at(codeString,i+1);
			var nextChar = string_ord_at(codeString,i+2);
			var charStr = chr(char);
			
			switch (state)
			{
				default:
					throw $"Invalid lexer state {state}";
				case COZY_LEXER_STATE.DEFAULT:
					positionInfo = self.findPositionInString(codeString,i,lastPositionI,positionInfo.line,positionInfo.col);
					lastPositionI = i;
					
					// end of line
					if (char == 0xA)
					{
						self.pushToken(
							COZY_TOKEN.EOL,
							undefined,
							positionInfo
						);
						break;
					}
					
					// whitespace
					if (__cozylang_char_is_whitespace(char))
						break;
				
					// identifiers
					if (
						__cozylang_char_is_letter_or_underscore(char) and
						!__cozylang_char_is_digit(char)
					)
					{
						current = "";
						state = COZY_LEXER_STATE.IDENTIFIER;
						i--;
						break;
					}
					
					// number literals
					if (
						__cozylang_char_is_digit(char) or 
						(char == 0x2E and __cozylang_char_is_digit(string_ord_at(codeString,i+1)))
					)
					{
						current = "";
						state = COZY_LEXER_STATE.NUMBER_LITERAL;
						i--;
						break;
					}
					
					// string literals
					if (
						(char == 0x22 or char == 0x27 or char == 0x60) or
						(char == 0x40 and (nextChar == 0x22 or nextChar == 0x27 or nextChar == 0x60))
					)
					{
						stringEscaping = false;
						rawString = char == 0x40;
						stringChar = rawString ?
							nextChar :
							char;
						
						current = "";
						state = COZY_LEXER_STATE.STRING_LITERAL;
						
						if (rawString)
							i++;
						break;
					}
					
					// operators
					if (
						string_pos(charStr,self.operatorCharacters) != 0
					)
					{
						current = "";
						state = COZY_LEXER_STATE.OPERATOR;
						i--;
						break;
					}
					
					// directives
					if (
						char == 0x23 and __cozylang_char_is_letter_or_underscore(nextChar)
					)
					{
						current = "";
						state = COZY_LEXER_STATE.DIRECTIVE;
						break;
					}
					
					// specific characters
					if (struct_exists(self.charTokens,charStr))
					{
						self.pushToken(
							self.charTokens[$ charStr],
							undefined,
							positionInfo
						);
						break;
					}
					
					throw $"Unexpected character found in tokenization: {charStr} ({char})";
					break;
				case COZY_LEXER_STATE.IDENTIFIER:
					if (
						!(__cozylang_char_is_letter_or_underscore(char) or __cozylang_char_is_digit(char))
					)
					{
						if (array_get_index(self.invalidIdentifiers,current) >= 0)
						{
							throw $"Invalid identifier {current}";
							break;
						}
						
						if (struct_exists(self.identifierTokens,current))
						{
							var value = undefined;
							var newType = self.identifierTokens[$ current];
							
							if (newType == COZY_TOKEN.OPERATOR)
								value = current;
							
							self.pushToken(
								newType,
								value,
								positionInfo
							);
						}
						else if (struct_exists(self.identifierLiterals,current))
						{
							self.pushToken(
								COZY_TOKEN.LITERAL,
								self.identifierLiterals[$ current],
								positionInfo
							);
						}
						else if (struct_exists(self.identifierOperators,current))
						{
							self.pushToken(
								COZY_TOKEN.OPERATOR,
								self.identifierOperators[$ current],
								positionInfo
							);
						}
						else if (array_get_index(self.identifierModifiers,current) >= 0)
						{
							self.pushToken(
								COZY_TOKEN.MODIFIER,
								current,
								positionInfo
							);
						}
						else
						{
							self.pushToken(
								COZY_TOKEN.IDENTIFIER,
								current,
								positionInfo
							);
						}
						
						state = COZY_LEXER_STATE.DEFAULT;
						i--;
						break;
					}
					
					current += charStr;
					break;
				case COZY_LEXER_STATE.OPERATOR:
					if (
						string_pos(charStr,self.operatorCharacters) == 0
					)
					{
						if (struct_exists(self.operatorTokens,current))
						{
							self.pushToken(
								self.operatorTokens[$ current],
								undefined,
								positionInfo
							);
						}
						else
						{
							self.pushToken(
								COZY_TOKEN.OPERATOR,
								current,
								positionInfo
							);
						}
						
						state = COZY_LEXER_STATE.DEFAULT;
						i--;
						break;
					}
					
					current += charStr;
					
					if (current == "///")
					{
						state = COZY_LEXER_STATE.COMMENT;
						current = "";
						
						comment = "///";
					}
					if (current == "/*")
					{
						state = COZY_LEXER_STATE.COMMENT_BLOCK;
						current = "";
						
						comment = "/*";
					}
					break;
				case COZY_LEXER_STATE.NUMBER_LITERAL:
					if (
						!(char == 0x2E or char == 0x5F or __cozylang_char_is_digit(char))
					)
					{
						current = string_replace_all(current,"_","");
						
						self.pushToken(
							COZY_TOKEN.LITERAL,
							real(current),
							positionInfo
						);
						
						state = COZY_LEXER_STATE.DEFAULT;
						i--;
						break;
					}
					
					current += charStr;
					
					if (string_count(".",current) > 1)
						throw $"Malformed number literal";
					break;
				case COZY_LEXER_STATE.STRING_LITERAL:
					if (!stringEscaping)
					{
						if (
							char == stringChar
						)
						{
							self.pushToken(
								COZY_TOKEN.LITERAL,
								current,
								positionInfo
							);
						
							state = COZY_LEXER_STATE.DEFAULT;
							break;
						}
						
						if (!rawString and charStr == "\\")
						{
							stringEscaping = true;
							charStr = "";
						}
					}
					else
					{
						switch (charStr)
						{
							default:
								throw $"Invalid escape character {charStr} ({char}) for string";
							case "n":
								charStr = "\n";
								break;
							case "r":
								charStr = "\r";
								break;
							case "b":
								charStr = "\b";
								break;
							case "f":
								charStr = "\f";
								break;
							case "t":
								charStr = "\t";
								break;
							case "v":
								charStr = "\v";
								break;
							case "\\":
								charStr = "\\";
								break;
							case "a":
								charStr = "\a";
								break;
							case "\"":
								charStr = "\"";
								break;
							case "'":
								charStr = "'";
								break;
							case "`":
								charStr = "`";
								break;
						}
						
						stringEscaping = false;
					}
					
					current += charStr;
					break;
				case COZY_LEXER_STATE.COMMENT:
					if (charStr == "\r" or charStr == "\f" or charStr == "\n")
					{
						state = COZY_LEXER_STATE.DEFAULT;
						self.pushToken(
							COZY_TOKEN.COMMENT,
							comment,
							positionInfo
						);
						break;
					}
					comment += charStr;
					break;
				case COZY_LEXER_STATE.COMMENT_BLOCK:
					if (string_length(current) == 0)
					{
						if (charStr == "*")
							current += charStr;
					}
					else if (current == "*")
					{
						if (charStr == "/")
						{
							state = COZY_LEXER_STATE.DEFAULT;
							self.pushToken(
								COZY_TOKEN.COMMENT,
								comment,
								positionInfo
							);
							break;
						}
						else
							current = "";
					}
					comment += charStr;
					break;
				case COZY_LEXER_STATE.DIRECTIVE:
					if (!(__cozylang_char_is_letter_or_underscore(char) or __cozylang_char_is_digit(char)))
					{
						self.pushToken(
							COZY_TOKEN.DIRECTIVE,
							current,
							positionInfo
						);
						
						state = COZY_LEXER_STATE.DEFAULT;
						i--;
						break;
					}
					
					current += charStr;
					break;
			}
		}
		positionInfo.line++;
		positionInfo.col = 1;
		
		self.pushToken(
			COZY_TOKEN.EOF,
			current,
			positionInfo
		);
	}
	
	/// @param {String} path
	static tokenizeFile = function(path) {
		var codeString = "";
		
		if (!file_exists(path))
			throw $"File {path} does not exist to tokenize";
		
		var buffer = buffer_load(path);
		codeString = buffer_read(buffer,buffer_string);
		buffer_delete(buffer);
		
		return self.tokenizeString(codeString);
	}
	
	/// @returns {Bool}
	static finished = function() {
		return self.tokenIndex >= array_length(self.tokens);
	}
	/// @returns {Struct.CozyToken}
	static peek = function() {
		if (self.finished())
			throw $"Lexer reached end prematurely";
		
		var index = self.tokenIndex;
		while (self.tokens[index].type == COZY_TOKEN.EOL)
		{
			index += 1;
			if (self.finished())
				throw $"Lexer reached end prematurely";
		}
		
		//show_debug_message($"peek: {index}");
		return self.tokens[index];
	}
	/// @returns {Struct.CozyToken}
	static next = function() {
		if (self.finished())
			throw $"Lexer reached end prematurely";
		
		var index = self.tokenIndex;
		while (self.tokens[index].type == COZY_TOKEN.EOL)
		{
			index += 1;
			if (self.finished())
				throw $"Lexer reached end prematurely";
		}
		
		self.tokenIndex = index+1;
		//show_debug_message($"next: {self.tokenIndex}");
		return self.tokens[index];
	}
	/// @returns {Struct.CozyToken}
	static peekWithNewline = function() {
		if (self.finished())
			throw $"Lexer reached end prematurely";
		//show_debug_message($"peek newline: {self.tokenIndex}");
		return self.tokens[self.tokenIndex];
	}
	/// @returns {Struct.CozyToken}
	static nextWithNewline = function() {
		if (self.finished())
			throw $"Lexer reached end prematurely";
		//show_debug_message($"next newline: {self.tokenIndex+1}");
		return self.tokens[self.tokenIndex++];
	}
	/// @param {Real} index
	static remove = function(index) {
		array_delete(self.tokens,index,1);
	}
	static resetToStart = function() {
		self.tokenIndex = 0;
	}
	
	static findPositionInString = function(codeString,index=0,startIndex=0,startLine=1,startCol=1) {
		var line = startLine;
		var col = startCol;
		
		for (var i = startIndex; i < index; i++)
		{
			var char = string_ord_at(codeString,i+1);
			var charStr = chr(char);
			
			if (charStr == "\n") // new line
			{
				line++;
				col = 1;
				continue;
			}
			if (charStr == "\t") // tab
			{
				col = ceil(col / 4) * 4 + 1;
				continue;
			}
			
			if (char >= 32) // non-space whitespace
			{
				col++;
			}
		}
		
		return {
			line : line,
			col : col
		};
	}
}