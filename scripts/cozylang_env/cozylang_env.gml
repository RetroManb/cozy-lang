

#macro COZY_TIMEOUT_MS 1000
#macro COZY_CALLSTACK_LIMIT 4096
#macro COZY_SELF_NAME "this"

#macro COZY_NAME_GET "__CozyGet"
#macro COZY_NAME_SET "__CozySet"
#macro COZY_NAME_CANDELETE "__CozyCanDelete"

/// @param {String} name
/// @param {Array<Any>|Function} bytecode
function CozyLibrary(name,bytecode) constructor {
	self.name = name;
	self.func = is_array(bytecode) ?
		new CozyFunction($"<library-{name}>",bytecode) :
		bytecode;
	self.children = {};
	
	/// @param {String} name
	/// @param {Struct.CozyLibrary} library
	static addChild = function(name,library) {
		if (struct_exists(self.children,name))
			show_debug_message($"Overwriting already existing library \"{name}\" in library \"{self.name}\"");
		self.children[$ name] = library;
	}
	
	/// @param {String} name
	static removeChild = function(name) {
		if (!struct_exists(self.children,name))
			return;
		struct_remove(self.children,name);
	}
	
	/// @param {Struct.CozyState} state
	/// @param {Bool} applyChildren
	static applyToState = function(state,applyChildren) {
		// apply children first
		if (applyChildren)
		{
			var childNames = struct_get_names(self.children);
			for (var i = 0, n = array_length(childNames); i < n; i++)
				self.children[$ childNames[i]].applyToState(state,true);
		}
		
		// apply 
		if (is_callable(self.func))
		{
			self.func(state);
			return;
		}
		
		state.runFunction(self.func);
	}
}

function CozyLibraryBuilder(name) constructor {
	if (!is_string(name))
		throw $"Invalid name given to CozyLibraryBuilder";
	
	// library info
	
	/// @ignore
	self.__name = name;
	/// @ignore
	self.__globals = {};
	/// @ignore
	self.__consts = {};
	/// @ignore
	self.__dynamicConsts = {};
	/// @ignore
	self.__libraries = {};
	
	// state
	
	/// @ignore
	self.__libTarget = undefined;
	
	/// @param {String} name
	/// @param {Any} value
	static setGlobal = function(name,value) {
		if (is_undefined(self.__libTarget))
			self.__globals[$ name] = value;
		else
			self.__libraries[$ self.__libTarget].set(name,value);
		
		return self;
	}
	/// @param {String} name
	/// @param {Any} value
	static setConst = function(name,value) {
		if (is_undefined(self.__libTarget))
		{
			if (struct_exists(self.__dynamicConsts,name))
				throw $"Attempt to set a non-dynamic const to an already existing dynamic const in CozyLibraryBuilder";
			
			self.__consts[$ name] = value;
		}
		else
		{
			self.__libraries[$ self.__libTarget].setConstant(name,value);
		}
		
		return self;
	}
	/// @param {String} name
	/// @param {Function|Struct.CozyFunction} value
	static setDynamicConst = function(name,value) {
		if (is_undefined(self.__libTarget))
		{
			if (struct_exists(self.__consts,name))
				throw $"Attempt to set a dynamic const to an already existing non-dynamic const in CozyLibraryBuilder";
			
			self.__dynamicConsts[$ name] = value;
		}
		else
		{
			self.__libraries[$ self.__libTarget].setDynamicConstant(name,value);
		}
		
		return self;
	}
	/// @param {String} name
	static addLibrary = function(name) {
		self.__libraries[$ name] = new CozyObject();
		
		return self;
	}
	/// @param {String} name
	static inLibraryScope = function(name) {
		self.__libTarget = name;
		
		return self;
	}
	static inGlobalScope = function() {
		self.__libTarget = undefined;
		
		return self;
	}
	
	/// @ignore
	/// @param {Struct.CozyState} state
	static __libFunc = function(state) {
		var structLibraryNames = struct_get_names(structLibraries);
		for (var i = 0, n = array_length(structLibraryNames); i < n; i++)
		{
			var name = structLibraryNames[i];
			state.consts[$ name] = structLibraries[$ name];
		}
		
		var constNames = struct_get_names(consts);
		for (var i = 0, n = array_length(constNames); i < n; i++)
		{
			var name = constNames[i];
			state.consts[$ name] = consts[$ name];
		}
		
		var dynConstNames = struct_get_names(dynamicConsts);
		for (var i = 0, n = array_length(dynConstNames); i < n; i++)
		{
			var name = dynConstNames[i];
			state.dynamicConsts[$ name] = dynamicConsts[$ name];
		}
		
		var globalNames = struct_get_names(globals);
		for (var i = 0, n = array_length(globalNames); i < n; i++)
		{
			var name = globalNames[i];
			state.setGlobal(name,globals[$ name]);
		}
	}
	
	static build = function() {
		
		
		var funcStruct = {
			globals : self.__globals,
			consts : self.__consts,
			dynamicConsts : self.__dynamicConsts,
			structLibraries : self.__libraries,
		};
		
		var func = method(funcStruct,__libFunc);
		
		return new CozyLibrary(self.__name,func);
	}
}

function CozyDirective() constructor {
	/// @param {Struct.CozyParser} parser
	/// @param {Struct.CozyLexer} lexer
	/// @param {Struct.CozyNode} directiveNode
	self.parseDirective = function(parser,lexer,node) {}
	
	/// @param {Struct.CozyNode} directiveNode
	/// @param {Struct.CozyNode} node
	/// @returns {Struct.CozyNode}
	self.modifyNode = function(directiveNode,node) {}
	
	/// @param {Struct.CozyNode} directiveNode
	/// @param {Struct.CozyToken} lexer
	self.modifyTokens = function(directiveNode,lexer) {}
	
	self.modifyNodeChildren = true;
	
	/// @param {Struct.CozyNode} directiveNode
	/// @param {Struct.CozyNode} node
	/// @returns {Struct.CozyNode}
	static modifyPostParse = function(directiveNode,node) {
		if (self.modifyNodeChildren)
		{
			for (var i = 0, n = array_length(node.children); i < n; i++)
				node.children[i] = self.modifyPostParse(directiveNode,node.children[i]);
		}
		
		var modified = self.modifyNode(directiveNode,node);
		
		/// @feather disable GM1045
		return modified;
		/// @feather enable GM1045
	}
}

function CozyEnvironmentFlags() constructor {
		/// Allow operator overloading?
	self.operatorOverloading = true;
	
		/// Make CozyObjects instead of structs when creating a struct literal?
	self.structLiteralsAreCozyObjects = false;
	
		/// Always call the parent constructors on classes?
	self.alwaysCallParentConstructor = true;
	
		/// Use __CozyGet and __CozySet methods on structs when getting/setting a
		/// variable from a struct?
	self.structGetterSetters = true;
	
		/// Import a libraries sub-libraries on import?
	self.importSubLibraries = true;
}

function CozyEnvironment() constructor {
	self.flags = global.cozylang.envFlags;
	
	/// @param {String} name
	/// @param {String} codeString
	/// @returns {Struct.CozyFunction}
	static compileString = function(name,codeString) {
		var bytecode = self.compileBytecode(name,codeString);
		return new CozyFunction(name,bytecode);
	}
	
	/// @param {String} name
	/// @param {String} path
	/// @returns {Struct.CozyFunction}
	static compileFile = function(name,path) {
		var codeString = "";
		
		if (!file_exists(path))
			throw $"File {path} does not exist to compile";
		
		var buffer = buffer_load(path);
		codeString = buffer_read(buffer,buffer_string);
		buffer_delete(buffer);
		
		return self.compileString(name,codeString);
	}
	
	/// @param {String} name
	/// @param {String} codeString
	/// @returns {Array<Any>}
	static compileBytecode = function(name,codeString) {
		var ast = self.parseString(codeString);
		return self.compiler.compile(ast);
	}
	
	/// @param {String} codeString
	/// @returns {Struct.CozyNode}
	static parseString = function(codeString) {
		self.lexer.tokenizeString(codeString);
		var ast = self.parser.parse(self.lexer);
		return ast;
	}
	
	/// @param {String} path
	/// @returns {Struct.CozyNode}
	static parseFile = function(path) {
		var codeString = "";
		
		if (!file_exists(path))
			throw $"File {path} does not exist to compile";
		
		var buffer = buffer_load(path);
		codeString = buffer_read(buffer,buffer_string);
		buffer_delete(buffer);
		
		return self.parse(codeString);
	}
	
	/// directives
	self.directives = {};
	self.directives[$ "define"] = new CozyDirective();
	self.directives[$ "include"] = new CozyDirective();
	
	/// @param {String} name
	/// @returns {Bool}
	static isValidDirective = function(name) {
		return array_get_index(self.validDirectives,name) >= 0;
	}
	
	/// standard out & standard error
	self.stdoutFlush = function(stdout) {
		show_debug_message($"[OUT] {stdout}");
	};
	self.stderrFlush = function(stderr) {
		show_debug_message($"[ERR] {stderr}");
	};
	static stdoutWriteLine = function(text) {
		if (is_callable(self.stdoutFlush))
			self.stdoutFlush(text);
	}
	static stderrWriteLine = function(text) {
		if (is_callable(self.stderrFlush))
			self.stderrFlush(text);
	}
	
	/// file sandbox
	self.fileExists = function(fname) {
		if (array_length(self.allowedDirectories) > 0 and array_get_index(self.allowedDirectories,filename_dir(fname)) < 0)
			return false;
		
		return file_exists(fname);
	}
	
	static assertFileExists = function(fname,exception=$"File {fname} does not exist or is not viewable to the current environment") {
		if (!self.fileExists(fname))
			throw exception;
	}
	
	/// restrictions
	self.bannedNames = [
		"toString",
			/// PLEASE DONT GET RID OF THIS
			/// I'm serious btw, having this be a name you can access on any object gets
			/// annoying to deal with as gamemaker LOVES to insert it into every struct
			/// instead of putting it in the base struct's static struct or whatever
			///
			/// that is the ONE feature about structs in gamemaker that i do not like
			///	due to the dumb loopholes I tried to do to let cozy and GML be nice to
			/// eachother
		COZY_NAME_GET,
		COZY_NAME_SET,
		COZY_NAME_CANDELETE,
			/// Reserved struct variable names for cozy
	];
	self.allowedDirectories = [];
	
	/// @param {String} name
	/// @returns {Bool}
	static nameIsBanned = function(name) {
		return array_get_index(self.bannedNames,name) >= 0;
	}
	
	/// operators
	self.validOperators = [
		"+","-",
		"*","/","%",
		"**","//",
		".",
		"==","!=","<=",">=","<",">",
		"=",
		"+=","-=","*=","/=","%=",
		"**=","//=",
		"[",
		"&","|","^",
		"&&","||","^^","??",
		"<<",">>",
		"<<=",">>=","&=","|=","^=",
		"instanceof","is",
	];
	self.validPrefixOperators = [
		"+","-",
		"!","~",
		"?",
		"delete","classof"
		//"++","--",
	];
	self.validPostfixOperators = [
		
		//"++","--",
	];
	self.overloadableOperators = [
		"+","-",
		"*","/","%",
		"**","//",
		"==","<=",">=","<",">",
		"&","|","^",
		"&&","||","^^",
		"<<",">>",
	];
	self.overloadablePrefixOperators = [
		"+","-",
		"!","~",
		"?",
	];
	self.overloadablePostfixOperators = [];
	
	self.infixOpBindingPower = {};
	self.infixOpBindingPower[$ "+"] = [10,10.1];
	self.infixOpBindingPower[$ "-"] = [10,10.1];
	self.infixOpBindingPower[$ "*"] = [11,11.1];
	self.infixOpBindingPower[$ "/"] = [11,11.1];
	self.infixOpBindingPower[$ "%"] = [11,11.1];
	self.infixOpBindingPower[$ "//"] = [11,11.1];
	self.infixOpBindingPower[$ "**"] = [12.1,12];
	self.infixOpBindingPower[$ "."] = [20,20.1];
	self.infixOpBindingPower[$ "=="] = [5,5.1];
	self.infixOpBindingPower[$ "!="] = [5,5.1];
	self.infixOpBindingPower[$ "<="] = [5,5.1];
	self.infixOpBindingPower[$ ">="] = [5,5.1];
	self.infixOpBindingPower[$ "<"] = [5,5.1];
	self.infixOpBindingPower[$ ">"] = [5,5.1];
	self.infixOpBindingPower[$ "<<"] = [12,12.1];
	self.infixOpBindingPower[$ ">>"] = [12,12.1];
	self.infixOpBindingPower[$ "&"] = [15,15.1];
	self.infixOpBindingPower[$ "|"] = [15,15.1];
	self.infixOpBindingPower[$ "^"] = [15,15.1];
	self.infixOpBindingPower[$ "&&"] = [0,0.1];
	self.infixOpBindingPower[$ "||"] = [0,0.1];
	self.infixOpBindingPower[$ "^^"] = [0,0.1];
	self.infixOpBindingPower[$ "??"] = [-2,-1.9];
	self.infixOpBindingPower[$ "instanceof"] = [18,18.1];
	self.infixOpBindingPower[$ "is"] = [18,18.1];
	self.infixOpBindingPower[$ "="] = [-4.9,-5];
	self.infixOpBindingPower[$ "+="] = [-4.9,-5];
	self.infixOpBindingPower[$ "-="] = [-4.9,-5];
	self.infixOpBindingPower[$ "*="] = [-4.9,-5];
	self.infixOpBindingPower[$ "/="] = [-4.9,-5];
	self.infixOpBindingPower[$ "%="] = [-4.9,-5];
	self.infixOpBindingPower[$ "**="] = [-4.9,-5];
	self.infixOpBindingPower[$ "//="] = [-4.9,-5];
	self.infixOpBindingPower[$ "??="] = [-4.9,-5];
	self.infixOpBindingPower[$ "<<="] = [-4.9,-5];
	self.infixOpBindingPower[$ ">>="] = [-4.9,-5];
	self.infixOpBindingPower[$ "&="] = [-4.9,-5];
	self.infixOpBindingPower[$ "|="] = [-4.9,-5];
	self.infixOpBindingPower[$ "^="] = [-4.9,-5];
	
	self.prefixOpBindingPower = {};
	self.prefixOpBindingPower[$ "+"] = 5;
	self.prefixOpBindingPower[$ "-"] = 5;
	self.prefixOpBindingPower[$ "!"] = 5;
	self.prefixOpBindingPower[$ "~"] = 5;
	self.prefixOpBindingPower[$ "?"] = 5;
	self.prefixOpBindingPower[$ "++"] = 5;
	self.prefixOpBindingPower[$ "--"] = 5;
	self.prefixOpBindingPower[$ "delete"] = 5;
	self.prefixOpBindingPower[$ "classof"] = 5;
	
	self.postfixOpBindingPower = {};
	self.postfixOpBindingPower[$ "++"] = 5;
	self.postfixOpBindingPower[$ "--"] = 5;
	
	self.infixOpCompilers = {};
	self.prefixOpCompilers = {};
	self.postfixOpCompilers = {};
	
	/// @param {String} op
	/// @returns {Bool}
	static isValidOperator = function(op) {
		return array_get_index(self.validOperators,op) >= 0;
	}
	
	/// @param {String} op
	/// @returns {Bool}
	static isValidPrefixOperator = function(op) {
		return array_get_index(self.validPrefixOperators,op) >= 0;
	}
	
	/// @param {String} op
	/// @returns {Bool}
	static isValidPostfixOperator = function(op) {
		return array_get_index(self.validPostfixOperators,op) >= 0;
	}
	
	/// @param {String} op
	/// @returns {Array<Real>}
	static getInfixOpBindingPower = function(op) {
		return self.infixOpBindingPower[$ op];
	}
	
	/// @param {String} op
	/// @returns {Array<Real>}
	static getPrefixOpBindingPower = function(op) {
		return self.prefixOpBindingPower[$ op];
	}
	
	/// @param {String} op
	/// @returns {Array<Real>}
	static getPostfixOpBindingPower = function(op) {
		return self.postfixOpBindingPower[$ op];
	}
	
	/// lexer, parser, compiler, and state
	self.lexer = new CozyLexer(self);
	self.parser = new CozyParser(self);
	self.compiler = new CozyCompiler(self);
	
	self.state = new CozyState(self);
	
	static resetState = function() {
		self.state.reset();
	}
	
	/// libraries
	self.libraries = {};
	
	/// @param {String} name
	/// @param {Struct.CozyLibrary} library
	static addLibrary = function(name,library) {
		if (struct_exists(self.libraries,name))
			show_debug_message($"Overwriting already existing library \"{name}\"");
		self.libraries[$ name] = library;
	}
	/// @param {String} name
	/// @returns {Struct.CozyLibrary}
	static getLibrary = function(name) {
		var split = string_split(name,".");
		if (!struct_exists(self.libraries,split[0]))
			throw $"Invalid library \"{name}\"";
		
		var current = self.libraries[$ split[0]];
		for (var i = 1, n = array_length(split); i < n; i++)
		{
			var childName = split[i];
			if (!struct_exists(current.children,childName))
				throw $"Invalid library \"{name}\"";
			
			current = current.children[$ childName];
		}
		
		return current;
	}
	
	/// @param {String} dname
	/// @param {String} namePrefix
	/// @returns {Struct.CozyLibrary}
	static newLibraryFromDirectory = function(dname,namePrefix="") {
		/// @feather disable GM1045
		if (!directory_exists(dname))
			return undefined;
		if (!file_exists(dname + "/init.cozy") and !file_exists(dname + "/init.cz"))
			return undefined;
		
		var libName = namePrefix + filename_name(dname);
		var libInitBytecode = undefined;
		var buffer = undefined;
		
		var subLibraries = [];
	
		try {
			/// init.cozy / init.cz
			if (file_exists(dname + "/init.cozy"))
			{
				var codeString = "";
				
				buffer = buffer_load(dname + "/init.cozy");
				codeString = buffer_read(buffer,buffer_string);
				buffer_delete(buffer);
				
				libInitBytecode = self.compileBytecode(libName,codeString);
			}
			else
			{
				var bytecodeStruct = new CozyBytecode();
				buffer = buffer_load(dname + "/init.cz");
				bytecodeStruct.fromBuffer(buffer);
				buffer_delete(buffer);
				libInitBytecode = bytecodeStruct.bytecode;
				delete bytecodeStruct;
			}
			
			/// sub-libraries
			var subLibraryDirectories = [];
			
			var dir = file_find_first(dname + "/*",fa_directory);
			while (dir != "")
			{
				array_push(subLibraryDirectories,dir);
				
				dir = file_find_next();
			}
			file_find_close();
			
			for (var i = 0, n = array_length(subLibraryDirectories); i < n; i++)
			{
				var subLibraryName = subLibraryDirectories[i];
				
				var subLibrary = self.newLibraryFromDirectory(dname + "/" + subLibraryName);
				if (!is_undefined(subLibrary))
				{
					subLibrary.name = subLibraryName;
					
					array_push(subLibraries,subLibrary);
				}
			}
		}
		catch (e) {
			if (buffer_exists(buffer))
				buffer_delete(buffer);
			
			self.stderrWriteLine($"Error while loading library {libName}: {e}");
			return undefined;
		}
	
		var library = new CozyLibrary(libName,libInitBytecode);
		/// @feather enable GM1045
		
		for (var i = 0, n = array_length(subLibraries); i < n; i++)
		{
			var subLibrary = subLibraries[i];
			
			library.addChild(libName + "." + subLibrary.name,subLibrary);
		}
		
		return library;
	}
	
	/// @param {String} dname
	/// @returns {Array<Struct.CozyLibrary>}
	static newLibrariesInDirectory = function(dname) {
		var arr = [];
		
		var libs = [];
		
		var dir = file_find_first(dname + "/*",fa_directory);
		while (dir != "")
		{
			array_push(libs,dir);
			
			dir = file_find_next();
		}
		file_find_close();
		
		for (var i = 0, n = array_length(libs); i < n; i++)
		{
			var libraryDir = libs[i];
			
			var library = self.newLibraryFromDirectory(dname + "/" + libraryDir);
			
			if (!is_undefined(library))
				array_push(arr,library);
		}
		
		return arr;
	}
	
	/// add built-in libraries
	var libs = __cozylang_get_libraries(self);
	var libNames = struct_get_names(libs);
	for (var i = 0, n = array_length(libNames); i < n; i++)
	{
		var libName = libNames[i];
		self.addLibrary(libName,libs[$ libName]);
	}
}

/// @ignore
/// @param {Struct.CozyEnvironment} env
function __cozylang_get_libraries(env) {
	static libraries = undefined;
	if (is_undefined(libraries))
	{
		libraries = {};
		
		var cozyLib = new CozyLibrary("cozy",COZY_EMPTY_BYTECODE);

		var mathLib = new CozyLibrary("cozy.math",function(state) {
			var math = {};
			
			math.Abs = method(undefined,abs);
			math.Acos = method(undefined,arccos);
			math.Asin = method(undefined,arcsin);
			math.Atan = method(undefined,arctan);
			math.Atan2 = method(undefined,arctan2);
			math.DegAcos = method(undefined,darccos);
			math.DegAsin = method(undefined,darcsin);
			math.DegAtan = method(undefined,darctan);
			math.DegAtan2 = method(undefined,darctan2);
			math.Ceil = method(undefined,ceil);
			math.Clamp = method(undefined,clamp);
			math.Cos = method(undefined,cos);
			math.DegCos = method(undefined,dcos);
			math.RadToDeg = method(undefined,radtodeg);
			math.Exp = method(undefined,exp);
			math.Fact = function(x) {
				var product = 1;
				for (var i = 2; i <= x; i++)
					product *= i;
				
				return product;
			};
			math.Floor = method(undefined,floor);
			math.Round = method(undefined,round);
			math.LogN = method(undefined,logn);
			math.Log2 = method(undefined,log2);
			math.Log10 = method(undefined,log10);
			math.Max = method(undefined,max);
			math.Min = method(undefined,min);
			math.Frac = method(undefined,frac);
			math.DegToRad = method(undefined,degtorad);
			math.Sin = method(undefined,sin);
			math.Sign = method(undefined,sign);
			math.DegSin = method(undefined,dsin);
			math.Sqrt = method(undefined,sqrt);
			math.Tan = method(undefined,tan);
			math.DegTan = method(undefined,dtan);
			math.ToReal = method(undefined,real);
			math.TryReal = function(value,def=undefined) {
				try {
					var v = real(value);
					return v;
				}
				catch (e) {
					return def;
				}
			};
			math.Distance = method(undefined,point_distance);
			math.Distance3D = method(undefined,point_distance_3d);
			math.Direction = method(undefined,point_direction);
			math[$ "pi"] = pi;
			
			state.setGlobal("math",math);
		});
		var stdLib = new CozyLibrary("cozy.std",function(state) {
			var stdout = {};
			var stderr = {};
			
			state.setGlobal("stdout",stdout);
			state.setGlobal("stderr",stderr);
			
			stdout.Flush = function() {
				state.flushStdout();
			}
			stdout.Write = function(str) {
				state.stdout += string(str);
			}
			stdout.WriteLn = function(str) {
				state.stdout += string(str);
				state.flushStdout();
			}
			
			stderr.Flush = function() {
				state.flushStderr();
			}
			stderr.Write = function(str) {
				state.stderr += string(str);
			}
			stderr.WriteLn = function(str) {
				state.stderr += string(str);
				state.flushStderr();
			}
			
			state.setGlobal("assert",function(val,exception) {
				if (!cozylang_is_truthy(val))
					throw exception;
			});
			state.setGlobal("print",method({stdout : stdout},function() {
				if (argument_count == 0)
				{
					stdout.WriteLn("");
					return;
				}
				
				var str = string(argument[0]);
				for (var i = 1; i < argument_count; i++)
				{
					str += " ";
					str += string(argument[i]);
				}
				
				stdout.WriteLn(str);
			}));
			state.setGlobal("throw",function(exception) {
				throw exception;
			});
			state.setGlobal("rawget",function(object,name) {
				if (is_struct(object))
				{
					if (is_instanceof(object,CozyClass))
					{
						if (object.isStrict and !(struct_exists(object.statics,name) or struct_exists(object.staticProperties,name)))
							throw $"Property {name} does not exist in class";
						
						return object.statics[$ name];
					}
					else if (is_instanceof(object,CozyFunction))
						return undefined;
					else if (is_instanceof(object,CozyObject))
					{
						if (object.isStrict and !(struct_exists(object.variables,name) or struct_exists(object.properties,name)))
						{
							if (is_cozyclass(object.class) and struct_exists(object.class.statics,name))
								return object.class.statics[$ name];
							
							throw $"Property {name} does not exist in object";
						}
						
						return object.variables[$ name];
					}
					else
						return object[$ name];
				}
				else if (is_handle(object) and instance_exists(object))
					return variable_instance_get(object,name);
				else if (is_array(object))
				{
					if (!is_numeric(name))
						throw $"Attempt to access an array with a non-numeric index";
						
					return object[name];
				}
				else if (is_string(object))
				{
					if (!is_numeric(name))
						throw $"Attempt to access a string with a non-numeric index";
					if (name < 0 or name >= string_length(object))
						throw $"Attempt to access a string out of bounds, {name} is outside of range [0..{string_length(object)-1}]"
						
					return string_char_at(object,name+1);
				}
				
				throw $"Cannot use rawget on a {typeof(object)} value";
			});
			state.setGlobal("rawset",function(object,name,value) {
				if (is_struct(object))
				{
					if (is_instanceof(object,CozyClass))
					{
						if (object.isStrict and !(struct_exists(object.statics,name) or struct_exists(object.staticProperties,name)))
							throw $"Property {name} does not exist in class";
						
						object.statics[$ name] = value;
					}
					else if (is_instanceof(object,CozyFunction))
						throw $"Attempt to modify function";
					else if (is_instanceof(object,CozyObject))
					{
						
						if (object.isStrict and !(struct_exists(object.variables,name) or struct_exists(object.properties,name)))
						{
							if (is_cozyclass(object.class) and struct_exists(object.class.statics,name))
								object.class.statics[$ name] = value;
							
							throw $"Property {name} does not exist in object";
						}
						
						object.variables[$ name] = value;
					}
					else
						object[$ name] = value;
				}
				else if (is_handle(object) and instance_exists(object))
					variable_instance_set(object,name,value);
				else if (is_array(object))
				{
					if (!is_numeric(name))
						throw $"Attempt to access an array with a non-numeric index";
						
					object[name] = value;
				}
				else
					throw $"Cannot use rawget on a {typeof(object)} value";
			});
		});
		var stringLib = new CozyLibrary("cozy.string",function(state) {
			var _string = {};
			
			_string.Char = new CozyFunction("cozy.string.Char",function() {
				var finalArr = [0];
				
				for (var i = 0; i < argument_count; i++)
					array_push(finalArr,chr(argument[i]));
				
				finalArr[0] = array_length(finalArr)-1;
				return finalArr;
			});
			_string.IsEmpty = function(str) {
				return string_length(str) == 0;
			}
			_string.Length = method(undefined,string_length);
			_string.Lower = method(undefined,string_lower);
			_string.Ord = new CozyFunction("cozy.string.Ord",function(str) {
				var finalArr = [0];
				
				if (string_length(finalArr) <= 1)
					array_push(finalArr,ord(str));
				else
				{
					for (var i = 1; i <= string_length(str); i++)
						array_push(finalArr,ord(string_char_at(str,i)));
				}
				
				finalArr[0] = array_length(finalArr)-1;
				return finalArr;
			});
			_string.Reverse = function(str) {
				var newStr = "";
				
				for (var i = string_length(str); i >= 1; i--)
					newStr += string_char_at(str,i);
				
				return newStr;
			};
			_string.Split = method(undefined,string_split);
			_string.ToString = function(value) {
				return string(value);
			};
			_string.Upper = method(undefined,string_upper);
			
			state.setGlobal("string",_string);
		});
		var arrayLib = new CozyLibrary("cozy.array",function(state) {
			var array = {};
			
			array.New = function(len,value=undefined) {
				return array_create(len,value);
			};
			array.HasValue = function(array,value) {
				return array_get_index(array,value) <= 0;
			};
			array.InRange = function(array,index) {
				return index >= 0 and index < array_length(array);
			};
			array.Length = method(undefined,array_length);
			array.Resize = method(undefined,array_resize);
			array.Clear = function(array) {
				array_resize(array,0);
			};
			array.Reverse = function(array) {
				for (var i = 0, n = array_length(array); i < floor(n/2); i++)
				{
					var temp = array[i];
					array[@ i] = array[n-i-1];
					array[@ n-i-1] = temp;
				}
			};
			array.Copy = function(array) {
				var newArr = [];
				
				for (var i = 0, n = array_length(array); i < n; i++)
					newArr[@ i] = array[i];
				
				return newArr;
			};
			array.GetIndex = function(array,value) {
				var ind = array_get_index(array,value);
				
				return ind < 0 ?
					undefined :
					ind;
			};
			array.Pack = function() {
				var arr = [];
				
				for (var i = 0; i < argument_count; i++)
					array_push(arr,argument[i]);
				
				return arr;
			};
			array.Unpack = new CozyFunction("cozy.array.Unpack",function(array) {
				var finalArr = [0];
				
				for (var i = 0, n = array_length(array); i < n; i++)
					array_push(finalArr,array[i]);
				
				finalArr[0] = array_length(finalArr)-1;
				return finalArr;
			});
			array.Push = method(undefined,array_push);
			array.Pop = method(undefined,array_pop);
			array.First = method(undefined,array_first);
			array.Last = method(undefined,array_last);
			array.Insert = method(undefined,array_insert);
			array.Remove = method(undefined,array_delete);
			array.IsEmpty = function(array) {
				return array_length(array) == 0;
			}
			
			state.setGlobal("array",array);
		});
		var typesLib = new CozyLibrary("cozy.is",function(state) {
			var types = {};
			
			types.IsUndefined = method(undefined,is_undefined);
			types.IsNumeric = method(undefined,is_numeric);
			types.IsReal = method(undefined,is_real);
			types.IsInt32 = method(undefined,is_int32);
			types.IsInt64 = method(undefined,is_int64);
			types.IsInfinity = method(undefined,is_infinity);
			types.IsBool = method(undefined,is_bool);
			types.IsString = method(undefined,is_string);
			types.IsArray = method(undefined,is_array);
			types.IsStruct = method(undefined,is_struct);
			types.IsObject = method(undefined,is_cozyobject);
			types.IsClass = method(undefined,is_cozyclass);
			types.IsHandle = method(undefined,is_handle);
			types.IsCallable = method(undefined,cozylang_is_callable);
			
			state.setGlobal("types",types);
		});
		
		libraries[$ "cozy"] = cozyLib;
		libraries[$ "cozy"].addChild("std",stdLib);
		libraries[$ "cozy"].addChild("math",mathLib);
		libraries[$ "cozy"].addChild("string",stringLib);
		libraries[$ "cozy"].addChild("array",arrayLib);
		libraries[$ "cozy"].addChild("types",typesLib);
		
		var gmlLib = new CozyLibrary("gml",COZY_EMPTY_BYTECODE);
		
		var randomLib = new CozyLibrary("gml.random",function(state) {
			var _random = {};
			
			_random.Int = method(undefined,irandom);
			_random.IntRange = method(undefined,irandom_range);
			_random.Float = method(undefined,random);
			_random.FloatRange = method(undefined,random_range);
			_random.Pick = method(undefined,choose);
			_random.PickArray = function(array,index=0,count=array_length(array)) {
				return array[irandom_range(index,index+count-1)];
			};
			_random.PickString = function(str,index=0,count=string_length(array)) {
				return string_char_at(str,irandom_range(index+1,index+count));
			};
			_random.GetSeed = method(undefined,random_get_seed);
			_random.SetSeed = method(undefined,random_set_seed);
			_random.Randomize = method(undefined,randomize);
			
			state.setGlobal("random",_random);
		});
		var drawLib = new CozyLibrary("gml.draw",function(state) {
			var draw = {};
			
			draw.SetColor = method(undefined,draw_set_color);
			draw.GetColor = method(undefined,draw_get_color);
			draw.Text = method(undefined,draw_text);
			draw.Rectangle = method(undefined,draw_rectangle);
			draw.Circle = method(undefined,draw_circle);
			draw.Ellipse = method(undefined,draw_ellipse);
			draw.Triangle = method(undefined,draw_triangle);
			
			state.setGlobal("draw",draw);
		});
		
		libraries[$ "gml"] = gmlLib;
		libraries[$ "gml"].addChild("random",randomLib);
		libraries[$ "gml"].addChild("draw",drawLib);
		
	}
	
	return libraries;
}