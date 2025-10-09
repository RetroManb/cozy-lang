enum COZY_INSTR {
	PUSH_CONST = 0,
	MAKE_CONST = 1,
	WRAP_FUNCTION = 2,
	POP_DISCARD = 3,
	ADD = 4,
	SUB = 5,
	MUL = 6,
	DIV = 7,
	MOD = 8,
	NULLISH = 9,
	LSHIFT = 10,
	RSHIFT = 11,
	POSITIVE = 12,
	NEGATE = 13,
	POWER = 14,
	IDIV = 15,
	JUMP = 16,
	JUMP_IF_FALSE = 17,
	JUMP_IF_TRUE = 18,
	IS = 19,
	EQUALS = 20,
	LESS_THAN = 21,
	GREATER_THAN = 22,
	MAKE_LOCAL_CONST = 23,
	IMPORT = 24,
	LESS_OR_EQUALS = 25,
	GREATER_OR_EQUALS = 26,
	IMPORTONLY = 27,
	RETURN = 28,
	HALT = 29,
	UNUSED_1E = 30,
	UNUSED_1F = 31,
	SET_VAR = 32,
	GET_VAR = 33,
	PUSH_STACK_TOP = 34,
	SWAP_STACK_TOP = 35,
	SET_LOCAL = 36,
	UNUSED_25 = 37,
	REMOVE_LOCAL = 38,
	UNUSED_27 = 39,
	CALL = 40,
	UNUSED_29 = 41,
	UNUSED_2A = 42,
	UNUSED_2B = 43,
	BAND = 44,
	BOR = 45,
	BXOR = 46,
	BNOT = 47,
	AND = 48,
	OR = 49,
	XOR = 50,
	NOT = 51,
	GET_PROPERTY = 52,
	SET_PROPERTY = 53,
	INSTANCEOF = 54,
	CLASSOF = 55,
	WRAP_STRUCT = 56,
	WRAP_ARRAY = 57,
	NEW_OBJECT = 58,
	DELETE_OBJECT = 59,
	BOOL_COERCE = 60,
	WRAP_CLASS = 61,
	PUSH_STACKFLAG = 62,
	CLASS_INIT_STATIC = 63,
	__SIZE__ = 64,
}

/// @ignore
enum COZY_STACKFLAG {
	NONE = 0,
	ARG_END = 1,
	ARRAY_END = 2,
	STRUCT_END = 3,
	__SIZE__ = 4,
}

/// @param {String} name
/// @param {Function|Struct.CozyFunction} staticConstructorFn
/// @param {Function|Struct.CozyFunction} constructorFn
/// @param {Function|Struct.CozyFunction} destructorFn
/// @param {String} parentName
/// @param {Bool} isStrict
/// @param {Array<String>} modifiers
/// @param {Struct} statics
/// @param {Struct} staticProperties
/// @param {Struct.CozyState} owner
function CozyClass(name,staticConstructorFn=undefined,constructorFn=undefined,destructorFn=undefined,parentName="",isStrict=false,modifiers=[],statics={},staticProperties={},owner=undefined) constructor {
	self.name = name;
	self.staticConstructorFn = is_callable(staticConstructorFn) ?
		method(undefined,staticConstructorFn) :
		staticConstructorFn;
	self.constructorFn = is_callable(constructorFn) ?
		method(undefined,constructorFn) :
		constructorFn;
	self.destructorFn = is_callable(destructorFn) ?
		method(undefined,destructorFn) :
		destructorFn;
	self.functions = {};
	self.properties = {};
	self.operators = {};
	self.statics = statics;
	self.staticProperties = staticProperties;
	self.parentName = parentName;
	self.isStrict = isStrict;
	self.modifiers = modifiers;
	
	self.owner = owner;
	
	static staticInit = function() {
		if (self.hasModifier("static") and self.hasModifier("final"))
			throw $"Class {self.name} was given static and final modifiers";
		
		/// static property initializers
		var staticNames = struct_get_names(self.staticProperties);
		for (var i = 0, n = array_length(staticNames); i < n; i++)
		{
			var staticName = staticNames[i];
			var value = self.staticProperties[$ staticName];
		
			if (is_cozyproperty(value) and cozylang_is_callable(value.initializer))
			{
				var result = cozylang_execute(value.initializer,[],self.owner);
			
				if (!result[0])
					continue;
				if (array_length(result) == 1)
					throw $"Static property {staticName} initializer didn't return anything";
			
				self.statics[$ staticName] = result[1];
			}
			else
				self.statics[$ staticName] = undefined;
		}
		
		/// static constructor
		if (cozylang_is_callable(self.staticConstructorFn))
		{
			cozylang_execute(self.staticConstructorFn,[],self.owner);
		}
	}
	
	static hasModifier = function(name) {
		return array_get_index(self.modifiers,name) >= 0;
	}
	
	/// @param {Struct.CozyObject} object
	/// @param {Struct.CozyState} state
	/// @returns {Bool}
	static objectIsInstance = function(object,state=self.owner) {
		if (is_undefined(object))
			return false;
		if (object.class == self)
			return true;
		var parent = object.class.getParentClass(state);
		while (is_cozyclass(parent))
		{
			if (parent == self)
				return true;
			parent = parent.getParentClass(state);
		}
		
		return false;
	}
	
	/// @param {Struct.CozyState} state
	/// @returns {Struct.CozyClass}
	static getParentClass = function(state=self.owner) {
		var parent = state.get(self.parentName);
		/// @feather disable GM1045
		if (!is_cozyclass(parent))
			return undefined;
		/// @feather enable GM1045
		
		if (parent.hasModifier("final"))
			throw $"Class {self.name} cannot inherit from final class {parent.name}";
		if (parent.hasModifier("static"))
			throw $"Class {self.name} cannot inherit from static class {parent.name}";
		
		return parent;
	}
	
	/// @param {String} name
	/// @param {Struct.CozyState} state
	/// @returns {Any}
	static getStatic = function(name,state=self.owner) {
		__cozylang_check_timeout(state);
		
		if (is_cozyproperty(self.staticProperties[$ name]) and !cozylang_is_callable(self.staticProperties[$ name].initializer) and cozylang_is_callable(self.staticProperties[$ name].getter))
			return self.staticProperties[$ name].get([],state);
		if (is_string(name) and is_cozyproperty(self.staticProperties[$ "@"]) and !struct_exists(self.staticProperties,name))
			return self.staticProperties[$ "@"].get([name],state);
		if (is_numeric(name) and is_cozyproperty(self.staticProperties[$ "#"]))
			return self.staticProperties[$ "#"].get([name],state);
		
		if (self.isStrict and !struct_exists(self.statics,name))
			throw $"Property {name} does not exist in class";
		
		if (is_cozyfunc(self.statics[$ name]))
			self.statics[$ name].target = undefined;
		
		return self.statics[$ name];
	}
	
	/// @param {String} name
	/// @param {Any} Value
	/// @param {Struct.CozyState} state
	static setStatic = function(name,value,state=self.owner) {
		__cozylang_check_timeout(state);
		
		if (is_cozyproperty(self.staticProperties[$ name]) and !cozylang_is_callable(self.staticProperties[$ name].initializer) and cozylang_is_callable(self.staticProperties[$ name].setter))
		{
			self.staticProperties[$ name].set([value],state);
			return;
		}
		if (is_string(name) and is_cozyproperty(self.staticProperties[$ "@"]) and !struct_exists(self.staticProperties,name))
		{
			self.staticProperties[$ "@"].set([name,value],state);
			return;
		}
		if (is_numeric(name) and is_cozyproperty(self.staticProperties[$ "#"]))
		{
			self.staticProperties[$ "#"].set([name,value],state);
			return;
		}
		
		if (!struct_exists(self.statics,name))
			throw $"Property {name} does not exist in class";
		
		self.statics[$ name] = value;
	}
	
	/// @param {Array<Any>} args
	/// @param {Struct.CozyState} state
	/// @returns {Struct.CozyObject}
	static newObject = function(args,state=self.owner,__visited=[],__callConstructor=true) {
		if (array_get_index(__visited,self) >= 0)
		{
			array_push(__visited,self);
			
			throw $"Class inheritance loop detected: {__cozylang_concat(__visited," -> ")}";
		}
		
		array_push(__visited,self);
		
		if (self.hasModifier("static"))
			throw $"Class {self.name} cannot be instantiated as it is static";
		
		var object = undefined;
		var parentClass = self.getParentClass(state);
		if (is_undefined(parentClass))
		{
			if (self != global.cozylang.baseClass)
				object = new CozyObject(state);
			else
				object = global.cozylang.baseClass.newObject(args,state,__visited);
		}
		else
			object = parentClass.newObject(args,state,__visited,state.env.flags.alwaysCallParentConstructor);
		
		/// add operators
		var operatorNames = struct_get_names(self.operators);
		for (var i = 0, n = array_length(operatorNames); i < n; i++)
		{
			var name = operatorNames[i];
			var operator = self.operators[$ name];
			
			if (!cozylang_is_callable(operator))
				throw $"Non-callable operator found in class {self.name}?";
			
			if (is_callable(operator))
				operator = method(object,operator);
			else if (is_cozyfunc(operator))
			{
				operator = variable_clone(operator,1);
				operator.target = object;
			}
			
			var firstThree = string_copy(name,1,3);
			var lastChars = string_copy(name,4,string_length(name)-3);
			switch (firstThree)
			{
				case "in$":
					object.operators[$ lastChars] = operator;
					break;
				case "pr$":
					object.prefixOperators[$ lastChars] = operator;
					break;
				case "po$":
					object.postfixOperators[$ lastChars] = operator;
					break;
			}
		}
		
		/// add functions
		var functionNames = struct_get_names(self.functions);
		for (var i = 0, n = array_length(functionNames); i < n; i++)
		{
			var name = functionNames[i];
			var func = self.functions[$ name];
			
			if (is_callable(func))
				func = method(object,func);
			else if (is_cozyfunc(func))
			{
				func = variable_clone(func,1);
				func.target = object;
			}
			
			object.variables[$ name] = func;
		}
		
		/// add properties
		var propertyInitializers = {};
		
		var propertyNames = struct_get_names(self.properties);
		for (var i = 0, n = array_length(propertyNames); i < n; i++)
		{
			var name = propertyNames[i];
			var property = self.properties[$ name];
			
			if (is_cozyfunc(property.getter))
				property.getter.target = object;
			if (is_cozyfunc(property.setter))
				property.setter.target = object;
			if (is_cozyfunc(property.initializer))
				property.initializer.target = object;
			
			if (cozylang_is_callable(property.initializer))
			{
				/// initializer
				propertyInitializers[$ name] = property.initializer;
			}
			
			if (!cozylang_is_callable(property.getter) and !cozylang_is_callable(property.setter))
			{
				object.variables[$ name] = undefined;
				continue;
			}
			
			property = variable_clone(property,1);
			property.object = object;
			
			object.properties[$ name] = property;
		}
		
		object.class = self;
		if (!object.isStrict)
			object.isStrict = self.isStrict;
		
		/// call property initializers
		var initializerNames = struct_get_names(propertyInitializers);
		for (var i = 0, n = array_length(initializerNames); i < n; i++)
		{
			var name = initializerNames[i];
			var initializer = variable_clone(propertyInitializers[$ name],1);
			if (is_cozyfunc(initializer))
				initializer.target = object;
			
			var result = cozylang_execute(initializer,[],state);
			if (!result[0])
			{
				delete initializer;
				continue;
			}
			if (array_length(result) == 1)
			{
				delete initializer;
				throw $"Property {name} initializer didn't return anything";
			}
			
			var returnValue = result[1];
			
			delete initializer;
			
			object.variables[$ name] = returnValue;
		}
		
		if (__callConstructor and cozylang_is_callable(self.constructorFn))
		{
			var constructorFn = variable_clone(self.constructorFn,1);
			if (is_cozyfunc(constructorFn))
				constructorFn.target = object;
			
			var res = cozylang_execute(constructorFn,args,state);
			
			delete constructorFn;
		}
		
		return object;
	}
	
	static toString = function() {
		return $"<cozyclass {self.name}>"
	}
}

/// @param {String} name
/// @param {Struct.CozyObject} object
/// @param {Function|Struct.CozyFunction} getter
/// @param {Function|Struct.CozyFunction} setter
/// @param {Function|Struct.CozyFunction} initializer
/// @param {Array<String>} modifiers
function CozyObjectProperty(name,object,getter,setter,initializer=undefined,modifiers=[]) constructor {
	self.name = name;
	self.object = object;
	self.getter = is_callable(object) ?
		method(self.object,getter) :
		getter;
	self.setter = is_callable(object) ?
		method(self.object,setter) :
		setter;
	self.initializer = is_callable(object) ?
		method(self.object,initializer) :
		initializer;
	self.modifiers = modifiers;
	
	static hasModifier = function(name) {
		return array_get_index(self.modifiers,name) >= 0;
	}
	
	/// @param {Array<Any>} args
	/// @param {Struct.CozyState} state
	static get = function(args,state) {
		if (!cozylang_is_callable(self.getter))
			throw $"Property {self.name} does not have a getter";
		
		var result = cozylang_execute(self.getter,args,state);
		if (array_length(result) == 1)
			throw $"Property {self.name} didn't return anything";
		
		return result[1];
	}
	/// @param {Array<Any>} args
	/// @param {Struct.CozyState} state
	static set = function(args,state) {
		if (!cozylang_is_callable(self.setter))
			throw $"Property {self.name} does not have a setter";
		
		cozylang_execute(self.setter,args,state);
	}
	
	static toString = function() {
		var _get = cozylang_is_callable(self.getter) ? "get " : "";
		var _set = cozylang_is_callable(self.setter) ? "set " : "";
		var equals = cozylang_is_callable(self.initializer) ? "= " : "";
		
		return $"<property {name} {_get}{_set}{equals}>";
	}
}

/// @param {Struct.CozyState} owner
function CozyObject(owner=undefined) constructor {
	self.variables = {};
	self.properties = {};
	self.operators = {};
	self.prefixOperators = {};
	self.postfixOperators = {};
	self.class = global.cozylang.baseClass;
	self.isStrict = false;
	
	self.owner = owner;
	
	/// @param {String} name
	/// @returns {Struct.CozyFunction}
	static getInfixOperator = function(name) {
		if (!struct_exists(self.operators,name))
		{
			/// @feather disable GM1045
			if (cozylang_is_callable(self.class.operators[$ $"infix-{name}"]))
				return self.operators[$ $"infix-{name}"];
			/// @feather enable GM1045
		}
		
		return self.operators[$ name];
	}
	
	/// @param {String} name
	/// @returns {Struct.CozyFunction}
	static getPrefixOperator = function(name) {
		if (!struct_exists(self.operators,name))
		{
			/// @feather disable GM1045
			if (cozylang_is_callable(self.class.operators[$ $"prefix-{name}"]))
				return self.operators[$ $"prefix-{name}"];
			/// @feather enable GM1045
		}
		
		return self.prefixOperators[$ name];
	}
	
	/// @param {String} name
	/// @returns {Struct.CozyFunction}
	static getPostfixOperator = function(name) {
		if (!struct_exists(self.operators,name))
		{
			/// @feather disable GM1045
			if (cozylang_is_callable(self.class.operators[$ $"postfix-{name}"]))
				return self.operators[$ $"postfix-{name}"];
			/// @feather enable GM1045
		}
		
		return self.postfixOperators[$ name];
	}
	
	/// @param {String} name
	/// @param {Any} rhs
	/// @param {Struct.CozyState} state
	/// @returns {Array<Any>}
	static getInfixOperatorResult = function(name,rhs,state=self.owner) {
		/// @feather disable GM1045
		if (!struct_exists(self.operators,name))
			return [false];
		
		var op = self.getInfixOperator(name);
		
		var result = cozylang_execute(op,[rhs],state);
		if (!result[0])
			return [true,undefined];
		
		if (array_length(result) == 1)
			return [true];
		
		return [true,result[1]];
		/// @feather enable GM1045
	}
	
	/// @param {String} name
	/// @param {Struct.CozyState} state
	/// @returns {Array<Any>}
	static getPrefixOperatorResult = function(name,state=self.owner) {
		/// @feather disable GM1045
		if (!struct_exists(self.prefixOperators,name))
			return [false];
		
		var op = self.getPrefixOperator(name);
		
		var result = cozylang_execute(op,[],state);
		if (!result[0])
			return [true,undefined];
		
		if (array_length(result) == 1)
			return [true];
		
		return [true,result[1]];
		/// @feather enable GM1045
	}
	
	/// @param {String} name
	/// @param {Struct.CozyState} state
	/// @returns {Array<Any>}
	static getPostfixOperatorResult = function(name,state=self.owner) {
		/// @feather disable GM1045
		if (!struct_exists(self.postfixOperators,name))
			return [false];
		
		var op = self.getPrefixOperator(name);
		
		var result = cozylang_execute(op,[],state);
		if (!result[0])
			return [true,undefined];
		
		if (array_length(result) == 1)
			return [true];
		
		return [true,result[1]];
		/// @feather enable GM1045
	}
	
	/// @param {String} name
	/// @param {Struct.CozyState} state
	static get = function(name,state=self.owner) {
		__cozylang_check_timeout(state);
		
		if (struct_exists(self.properties,name))
			return self.properties[$ name].get([],state);
		if (is_string(name) and struct_exists(self.properties,"@") and !struct_exists(self.variables,name))
			return self.properties[$ "@"].get([name],state);
		if (is_numeric(name) and struct_exists(self.properties,"#"))
			return self.properties[$ "#"].get([name],state);
		
		if (self.isStrict and !(struct_exists(self.variables,name) or struct_exists(self.properties,name)))
		{
			if (is_cozyclass(self.class) and (struct_exists(self.class.statics,name) or struct_exists(self.class.staticProperties,name)))
				return self.class.getStatic(name,state);
			throw $"Property {name} does not exist in object";
		}
		
		if (struct_exists(self.variables,name))
			return self.variables[$ name];
		
		if (is_cozyclass(self.class) and (struct_exists(self.class.statics,name) or struct_exists(self.class.staticProperties,name)))
		{
			var value = self.class.getStatic(name,state);
			if (is_cozyfunc(value))
				value.target = self;
			return value;
		}
	}
	/// @param {String} name
	/// @param {Any} value
	/// @param {Struct.CozyState} state
	static set = function(name,value,state=self.owner) {
		__cozylang_check_timeout(state);
		
		if (struct_exists(self.properties,name))
		{
			self.properties[$ name].set([value],state);
			return;
		}
		if (is_string(name) and struct_exists(self.properties,"@") and !struct_exists(self.variables,name))
		{
			self.properties[$ "@"].set([name,value],state);
			return;
		}
		if (is_numeric(name) and struct_exists(self.properties,"#"))
		{
			self.properties[$ "#"].set([name,value],state);
			return;
		}
		
		if (self.isStrict and !(struct_exists(self.variables,name) or struct_exists(self.properties,name)))
		{
			if (is_cozyclass(self.class) and (struct_exists(self.class.statics,name) or struct_exists(self.class.staticProperties,name)))
			{
				self.class.setStatic(name,value,state);
				return;
			}
			throw $"Property {name} does not exist in object";
		}
		
		if (is_cozyclass(self.class) and (struct_exists(self.class.statics,name) or struct_exists(self.class.staticProperties,name)))
		{
			self.class.setStatic(name,value,state);
			return;
		}
		
		self.variables[$ name] = value;
	}
	
	/// @param {String} name
	/// @param {Any} value
	static setConstant = function(name,value) {
		self.properties[$ name] = new CozyObjectProperty(name,self,undefined,undefined);
		self.properties[$ name].getter = method({const: value},function() {
			return const;
		});
	}
	
	/// @param {String} name
	/// @param {Function|Struct.CozyFunction} value
	static setDynamicConstant = function(name,value) {
		self.properties[$ name] = new CozyObjectProperty(name,self,value,undefined);
	}
	
	static toString = function() {
		var state = self.owner ?? array_last(global.cozylang.stateStack);
		
		var toStringFn = self.variables[$ "ToString"];
		if (!is_cozyfunc(toStringFn) and is_cozyclass(self.class))
		{
			var temp;
			try {
				temp = self.class.getStatic("ToString",state);
			}
			catch (e) {
				temp = undefined;
			}
			toStringFn = variable_clone(temp,1);
			if (is_cozyfunc(toStringFn))
				toStringFn.target = self;
		}
		
		if (cozylang_is_callable(toStringFn))
		{
			var result = cozylang_execute(toStringFn,[],state);
			if (result[0])
			{
				if (array_length(result) == 1)
					throw $"ToString didn't return anything";
				
				return string(result[1]);
			}
		}
		
		var struct = variable_clone(self.variables,1);
		if (cozylang_is_callable(toStringFn))
			struct.toString = {}.toString;
		
		var propertyNames = struct_get_names(self.properties);
		for (var i = 0; i < array_length(propertyNames); i++)
			struct[$ propertyNames[i]] = "<Property>";
		
		return string(struct);
	}
}

/// @param {String} name
/// @param {Array<Any>|Function} bytecode
/// @param {Array<String>} argNames
/// @param {Bool} hasParams
/// @param {Struct.CozyObject} target
/// @param {Struct.CozyState} owner
function CozyFunction(name,bytecode,argNames=[],hasParams=false,target=undefined,owner=undefined) constructor {
	self.name = name;
	self.bytecode = is_callable(bytecode) ?
		method(target,bytecode) :
		bytecode;
	self.argNames = argNames;
	self.hasParams = hasParams;
	self.target = target;
	
	self.owner = owner;
	
	static toString = function() {
		var _target = is_cozyobject(self.target) ?
			$"{COZY_SELF_NAME} " :
			""
		
		var argStr = "";
		for (var i = 0, n = array_length(self.argNames); i < n; i++)
		{
			var argName = self.argNames[i];
			
			if (i != 0)
				argStr += ",";
			if (i == n-1 and self.hasParams)
				argStr += "params ";
			argStr += string(argName);
		}
		
		return $"<cozyfunction {_target}{self.name}({argStr})>";
	}
}

/// @ignore
/// @param {Enum.COZY_STACKFLAG} value
function CozyStackFlag(value) constructor {
	self.value = value;
	
	static toString = function() {
		var val = "UNKNOWN";
		switch (self.value)
		{
			case COZY_STACKFLAG.NONE:
				val = "NONE";
				break;
			case COZY_STACKFLAG.ARG_END:
				val = "ARG_END";
				break;
			case COZY_STACKFLAG.ARRAY_END:
				val = "ARRAY_END";
				break;
			case COZY_STACKFLAG.STRUCT_END:
				val = "STRUCT_END";
				break;
		}
		
		return $"<CozyStackFlag {val}>";
	}
}

/// @param {Function|Struct.CozyFunction} fn
/// @returns {Bool}
function cozylang_is_callable(fn) {
	if (is_callable(fn) or is_cozyfunc(fn))
		return true;
	return false;
}

/// @param {Struct.CozyFunction} fn
/// @returns {Bool}
function is_cozyfunc(fn) {
	if (is_struct(fn) and is_instanceof(fn,CozyFunction))
		return true;
	return false;
}

/// @param {Struct.CozyClass} class
/// @returns {Bool}
function is_cozyclass(class) {
	if (is_struct(class) and is_instanceof(class,CozyClass))
		return true;
	return false;
}

/// @param {Struct.CozyObject} obj
/// @returns {Bool}
function is_cozyobject(obj) {
	if (is_struct(obj) and is_instanceof(obj,CozyObject))
		return true;
	return false;
}

/// @param {Struct.CozyObjectProperty} prop
/// @returns {Bool}
function is_cozyproperty(prop) {
	if (is_struct(prop) and is_instanceof(prop,CozyObjectProperty))
		return true;
	return false;
}

/// @param {Function|Struct.CozyFunction} fn
/// @param {Array<Any>} args
/// @param {Struct.CozyState} cozyState
/// @returns {Array<Any>}
function cozylang_execute(fn,args,cozyState) {
	if (is_callable(fn))
		return [true,method_call(fn,args)];
	if (is_cozyfunc(fn))
	{
		if (!(is_struct(cozyState) and is_instanceof(cozyState,CozyState)))
		{
			cozyState = fn.owner;
		}
		
		if (is_callable(fn.bytecode))
		{
			var result = method_call(fn.bytecode,args);
			
			var finalArr = [true];
			var returnCount = result[0];
			
			for (var i = 0; i < returnCount; i++)
				array_push(finalArr,result[i+1]);
			
			return finalArr;
		}
		
		if (!is_undefined(fn.target))
			array_insert(args,0,fn.target);
		else
		{
			var firstArgName = undefined;
			if (array_length(args) > 0)
				firstArgName = fn.argNames[0];
			
			if (firstArgName == COZY_SELF_NAME)
				array_insert(args,0,undefined);
		}
		
		var finalArr = [true];
		
		var argStruct = {};
		
		var hasParams = fn.hasParams;
		
		var argCount = array_length(args);
		var maxArgs = array_length(fn.argNames);
		if (hasParams)
			maxArgs--;
		
		for (var i = 0; i < argCount; i++)
		{
			if (i >= maxArgs)
				break;
			
			var argName = fn.argNames[i];
			argStruct[$ argName] = args[i];
		}
		
		// params support
		if (hasParams)
		{
			var paramArgName = fn.argNames[maxArgs];
			argStruct[$ paramArgName] = [];
			for (var i = maxArgs; i < argCount; i++)
			{
				array_push(argStruct[$ paramArgName],args[i]);
			}
		}
		
		var prevLocals = cozyState.removeAllLocals();
		
		var returnCount = cozyState.runFunction(fn,argStruct);
		delete argStruct;
		
		cozyState.restoreAllLocals(prevLocals);
		
		for (var i = 0; i < returnCount; i++)
			array_push(finalArr,cozyState.popStack());
		
		return finalArr;
	}
	/// @feather disable GM1045
	return [false,undefined];
	/// @feather enable GM1045
}

/// @param {Function|Struct.CozyFunction} fn
/// @param {Array<Any>} args
/// @param {Struct.CozyState} cozyState
/// @returns {Array<Any>}
function cozylang_try_execute(fn,args,cozyState) {
	if (cozylang_is_callable(fn))
	{
		try {
			var result = cozylang_execute(fn,args,cozyState);
			return result;
		}
		catch (e) {
			return [false,e];
		}
	}
	return [false,"Invalid function"];
}

/// @ignore
function __cozylang_concat(arr,delim) {
	if (array_length(arr) == 0)
		return "";
	
	var str = string(arr[0]);
	for (var i = 1, n = array_length(arr); i < n; i++)
	{
		str += delim;
		str += string(arr[i]);
	}
	
	return str;
}

/// @param {Any} value
/// @returns {Bool}
function cozylang_is_truthy(value) {
	if (is_bool(value))
		return value;
	if (is_numeric(value))
		return bool(value);
	if (is_undefined(value))
		return false;
	
	return true;
}

/// @ignore
/// @param {Struct.CozyState} state
function __cozylang_check_timeout(state) {
	gml_pragma("forceinline");
	
	if (is_undefined(state.timeoutStart))
		state.timeoutStart = current_time;
	if (current_time > state.timeoutStart+COZY_TIMEOUT_MS)
		throw $"Timeout of {COZY_TIMEOUT_MS}ms exceeded ({current_time-state.timeoutStart}ms > {COZY_TIMEOUT_MS}ms)";
}

/// @param {Struct.CozyEnvironment} env
function CozyState(env) constructor {
	self.env = env;
	
	self.stack = [];
	
	self.globals = {};
	self.consts = {};
	self.dynamicConsts = {};
	self.locals = {};
	self.localConsts = {};
	
	self.timeoutStart = undefined;
	
	self.stdout = "";
	self.stderr = "";
	
	self.callStack = [];
	
	static flushStdout = function() {
		if (is_callable(self.env.stdoutFlush))
			self.env.stdoutFlush(self.stdout);
		self.stdout = "";
	}
	static flushStderr = function() {
		if (is_callable(self.env.stderrFlush))
			self.env.stderrFlush(self.stderr);
		self.stderr = "";
	}
	
	static reset = function() {
		array_resize(self.stack,0);
		array_resize(self.callStack,0);
		self.timeoutStart = undefined;
		
		self.stdout = "";
		self.stderr = "";
		
		var names = struct_get_names(self.globals);
		for (var i = 0, n = array_length(names); i < n; i++)
			struct_remove(self.globals,names[i]);
		
		var names = struct_get_names(self.locals);
		for (var i = 0, n = array_length(names); i < n; i++)
			struct_remove(self.locals,names[i]);
		
		var names = struct_get_names(self.consts);
		for (var i = 0, n = array_length(names); i < n; i++)
			struct_remove(self.consts,names[i]);
		
		var names = struct_get_names(self.dynamicConsts);
		for (var i = 0, n = array_length(names); i < n; i++)
			struct_remove(self.dynamicConsts,names[i]);
		
		var names = struct_get_names(self.localConsts);
		for (var i = 0, n = array_length(names); i < n; i++)
			struct_remove(self.localConsts,names[i]);
	}
	
	/// @returns {Any}
	static popStack = function() {
		if (array_length(self.stack) <= 0)
			throw $"Stack underflow";
		
		return array_pop(self.stack);
	}
	static pushStack = function(value) {
		array_push(self.stack,value);
	}
	static topStack = function() {
		return array_last(self.stack);
	}
	static printStack = function() {
		show_debug_message("<STACK BOTTOM>");
		for (var i = 0; i < array_length(self.stack); i++)
			show_debug_message(self.stack[i]);
		show_debug_message("<STACK TOP>");
	}
	
	/// @param {String} name
	/// @param {Any} value
	static set = function(name,value) {
		if (struct_exists(self.consts,name) or struct_exists(self.dynamicConsts,name) or struct_exists(self.localConsts,name))
			throw $"Attempt to modify constant variable {name}";
		if (struct_exists(self.locals,name))
			self.setLocal(name,value);
		else
			self.setGlobal(name,value);
	}
	
	/// @param {String} name
	/// @returns {Any}
	static get = function(name) {
		if (struct_exists(self.dynamicConsts,name))
			return self.getDynamicConst(name);
		else if (struct_exists(self.localConsts,name))
			return self.getLocalConst(name);
		else if (struct_exists(self.consts,name))
			return self.getConst(name);
		else if (struct_exists(self.locals,name))
			return self.getLocal(name);
		else
			return self.getGlobal(name);
	}
	
	/// @param {Struct|Struct.CozyObject|Struct.CozyFunction|Struct.CozyClass|Id.Instance|Array<Any>} object
	/// @param {String|Real} name
	/// @param {Any} value
	static setProperty = function(object,name,value) {
		if (is_struct(object))
		{
			if (is_instanceof(object,CozyClass))
				object.setStatic(name,value,self);
			else if (is_instanceof(object,CozyFunction))
				throw $"Attempt to modify function";
			else if (is_instanceof(object,CozyObject))
				object.set(name,value,self);
			else
			{
				if (self.env.flags.structGetterSetters and struct_exists(object,COZY_NAME_SET))
				{
					var result = object[$ COZY_NAME_SET](name,value);
					if (!result)
						throw $"Cannot modify {name} property of {instanceof(object)} struct";
				}
				object[$ name] = value;
			}
		}
		else if (is_handle(object) and instance_exists(object))
			variable_instance_set(object,name,value);
		else if (is_array(object))
		{
			if (!is_numeric(name))
				throw $"Attempt to modify an array with a non-numeric index";
						
			object[name] = value;
		}
		else
			throw $"Attempt to modify a {typeof(object)} value";
	}
	
	/// @param {Struct|Struct.CozyObject|Struct.CozyFunction|Struct.CozyClass|Id.Instance|Array<Any>} object
	/// @param {String|Real} name
	/// @returns {Any}
	static getProperty = function(object,name) {
		if (is_struct(object))
		{
			if (is_instanceof(object,CozyClass))
				return object.getStatic(name);
			else if (is_instanceof(object,CozyFunction))
				return undefined;
			else if (is_instanceof(object,CozyObject))
				return object.get(name);
			else
			{
				if (self.env.flags.structGetterSetters and struct_exists(object,COZY_NAME_GET))
					return object[$ COZY_NAME_GET](name);
				
				return object[$ name];
			}
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
		else
			throw $"Attempt to access a {typeof(object)} value";
	}
	
	static getPropertyRaw = function(object,name) {
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
			{
				if (self.env.flags.structGetterSetters and self.env.flags.structsBypassRawAccess and struct_exists(object,COZY_NAME_GET))
					return object[$ COZY_NAME_GET](name);
				
				return object[$ name];
			}
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
		else
			throw $"Cannot use rawget on a {typeof(object)} value";
	}
	
	static setPropertyRaw = function(object,name,value) {
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
			{
				if (self.env.flags.structGetterSetters and self.env.flags.structsBypassRawAccess and struct_exists(object,COZY_NAME_SET))
				{
					var result = object[$ COZY_NAME_SET](name,value);
					if (!result)
						throw $"Cannot modify {name} property of {instanceof(object)} struct";
				}
				
				object[$ name] = value;
			}
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
	}
	
	/// @param {String} name
	/// @param {Any} value
	static setGlobal = function(name,value) {
		if (is_undefined(value))
		{
			struct_remove(self.globals,name);
			return;
		}
		
		self.globals[$ name] = value;
	}
	/// @param {String} name
	/// @returns {Any}
	static getGlobal = function(name) {
		return self.globals[$ name];
	}
	
	/// @param {String} name
	/// @param {Any} value
	static setLocal = function(name,value) {
		self.locals[$ name] = value;
	}
	/// @param {String} name
	/// @returns {Any}
	static getLocal = function(name) {
		return self.locals[$ name];
	}
	/// @param {String} name
	/// @returns {Any}
	static getConst = function(name) {
		return self.consts[$ name];
	}
	/// @param {String} name
	/// @returns {Any}
	static getDynamicConst = function(name) {
		return self.dynamicConsts[$ name]();
	}
	/// @param {String} name
	/// @returns {Any}
	static getLocalConst = function(name) {
		return self.localConsts[$ name];
	}
	
	static removeAllLocals = function() {
		var removedLocals = variable_clone(self.locals,1);
		var removedLocalConsts = variable_clone(self.localConsts,1);
		
		var localNames = struct_get_names(self.locals);
		for (var i = 0, n = array_length(localNames); i < n; i++)
			struct_remove(self.locals,localNames[i]);
			
		var localConstNames = struct_get_names(self.localConsts);
		for (var i = 0, n = array_length(localConstNames); i < n; i++)
			struct_remove(self.localConsts,localConstNames[i]);
		
		return {
			locals : removedLocals,
			localConsts : removedLocalConsts
		}
	}
	/// @param {Struct} prevLocals
	static restoreAllLocals = function(prevLocals) {
		var removedLocals = prevLocals.locals;
		var removedLocalConsts = prevLocals.localConsts;
		
		var localNames = struct_get_names(removedLocals);
		for (var i = 0, n = array_length(localNames); i < n; i++)
			self.locals[$ localNames[i]] = removedLocals[$ localNames[i]];
		
		var localConstNames = struct_get_names(removedLocalConsts);
		for (var i = 0, n = array_length(localConstNames); i < n; i++)
			self.localConsts[$ localConstNames[i]] = removedLocalConsts[$ localConstNames[i]];
	}
	
	/// @param {String} operator
	/// @param {Struct.CozyObject} object
	/// @param {Any} rhs
	/// @returns {Bool}
	static handleInfixOperatorOverload = function(operator,object,rhs) {
		if (is_cozyobject(object))
		{
			var result = object.getInfixOperatorResult(operator,rhs);
			//show_debug_message(result)
			if (result[0])
			{
				if (array_length(result) > 1)
					self.pushStack(result[1]);
				return true;
			}
		}
		return false;
	}
	
	/// @param {String} operator
	/// @param {Struct.CozyObject} object
	/// @returns {Bool}
	static handlePrefixOperatorOverload = function(operator,object) {
		if (is_cozyobject(object))
		{
			var result = object.getPrefixOperatorResult(operator);
			if (result[0])
			{
				if (array_length(result) > 1)
				{
					var val = result[1];
					if (operator == "?")
						val = cozylang_is_truthy(val);
					
					self.pushStack(val);
				}
				else if (operator == "?")
					throw $"Operator overload for ? prefix operator must return a boolean";
				return true;
			}
		}
		return false;
	}
	
	/// @param {String} operator
	/// @param {Struct.CozyObject} object
	/// @returns {Bool}
	static handlePostfixOperatorOverload = function(operator,object) {
		if (is_cozyobject(object))
		{
			var result = object.getPostfixOperatorResult(operator);
			if (result[0])
			{
				if (array_length(result) > 1)
					self.pushStack(result[1]);
				return true;
			}
		}
		return false;
	}
	
	/// @param {Struct.CozyFunction} cozyFunc
	/// @param {Struct} givenLocals
	/// @returns {Real}
	static runFunction = function(cozyFunc,givenLocals={}) {
		if (is_undefined(self.timeoutStart))
			self.timeoutStart = current_time;
		array_push(self.callStack,cozyFunc);
		array_push(global.cozylang.stateStack,self);
		
		if (array_length(self.callStack) >= COZY_CALLSTACK_LIMIT)
			throw $"Call stack limit exceeded ({COZY_CALLSTACK_LIMIT})";
		
		var alreadyExistingLocals = array_union(struct_get_names(self.locals),struct_get_names(self.localConsts));
		
		var localsAdded = struct_get_names(givenLocals);
		for (var i = 0, n = array_length(localsAdded); i < n; i++)
		{
			var name = localsAdded[i];
			self.locals[$ name] = givenLocals[$ name];
		}
		
		var bytecode = cozyFunc.bytecode;
		var bytecodeLen = array_length(bytecode);
		
		var pc = 0;
		var halted = false;
		var returnAmount = 0;
		
		while (!halted)
		{
			__cozylang_check_timeout(self);
			
			if (!is_numeric(pc))
				throw $"Non-numeric program counter of type {typeof(pc)} was reached";
			if (pc < 0 or pc >= bytecodeLen)
				throw $"Out of bounds program counter, {pc} is not in range [0..{bytecodeLen-1}]";
			
			var instruction = bytecode[pc];
			if (!is_numeric(instruction))
				throw $"Found a non-numeric instruction with a type of: {typeof(instruction)}";
			
			switch (instruction)
			{
				default:
					break;
				case COZY_INSTR.PUSH_CONST:
					self.pushStack(bytecode[pc+1]);
					
					pc++;
					break;
				case COZY_INSTR.MAKE_CONST:
					var name = bytecode[pc+1];
					
					if (struct_exists(self.consts,name) or struct_exists(self.dynamicConsts,name))
						throw $"Attempt to modify constant {name}";
					
					self.consts[$ name] = self.popStack();
					
					pc++;
					break;
				case COZY_INSTR.WRAP_FUNCTION:
					var fnArgCount = bytecode[pc+1];
					
					var fnHasParams = self.popStack();
					
					var argNames = [];
					for (var i = 0; i < fnArgCount; i++)
					{
						var argName = self.popStack();
						if (!is_string(argName))
							throw $"Attempt to use non-string argument name for function wrapping";
						
						array_push(argNames,argName);
					}
					
					var fnBytecode = self.popStack();
					var fnName = self.popStack();
					
					self.pushStack(new CozyFunction(fnName,fnBytecode,argNames,fnHasParams,undefined,self));
					
					pc++;
					break;
				case COZY_INSTR.POP_DISCARD:
					var count = bytecode[pc+1];
					
					for (var i = 0; i < count; i++)
						self.popStack();
					
					pc++;
					break;
				case COZY_INSTR.JUMP:
					var newPC = bytecode[pc+1];
					if (!is_numeric(newPC))
						throw $"Attempt to jump to a non-numeric address of type {typeof(newPC)}";
					
					pc = newPC-1;
					break;
				case COZY_INSTR.JUMP_IF_FALSE:
					var newPC = bytecode[pc+1];
					var value = self.popStack();
					
					if (value)
						pc++;
					else
					{
						if (!is_numeric(newPC))
							throw $"Attempt to jump to a non-numeric address of type {typeof(newPC)}";
						pc = newPC-1;
					}
					break;
				case COZY_INSTR.JUMP_IF_TRUE:
					var newPC = bytecode[pc+1];
					var value = self.popStack();
					
					if (value)
					{
						if (!is_numeric(newPC))
							throw $"Attempt to jump to a non-numeric address of type {typeof(newPC)}";
						pc = newPC-1;
					}
					else
						pc++;
					break;
				case COZY_INSTR.MAKE_LOCAL_CONST:
					var name = bytecode[pc+1];
					
					if (struct_exists(self.dynamicConsts,name) or struct_exists(self.localConsts,name))
						throw $"Attempt to modify constant {name}";
					
					array_push(localsAdded,name);
					
					self.localConsts[$ name] = self.popStack();
					
					pc++;
					break;
				case COZY_INSTR.IMPORT:
				case COZY_INSTR.IMPORTONLY:
					var count = bytecode[pc+1];
					
					var fullNameArr = [];
					for (var i = 0; i < count; i++)
						array_push(fullNameArr,self.popStack());
					
					var library = self.env.getLibrary(__cozylang_concat(fullNameArr,"."));
					
					var prevLocals = self.removeAllLocals();
					
					var applyChildren = instruction == COZY_INSTR.IMPORT ?
						self.env.flags.importSubLibraries :
						false
					
					library.applyToState(self,applyChildren);
					
					self.restoreAllLocals(prevLocals);
					
					pc++;
					break;
				case COZY_INSTR.RETURN:
					var amount = bytecode[pc+1];
					returnAmount = amount;
					
					halted = true;
					pc--;
					break;
				case COZY_INSTR.HALT:
					halted = true;
					pc--;
					break;
				case COZY_INSTR.SET_VAR:
					var name = bytecode[pc+1];
					var value = self.popStack();
						
					self.set(name,value);
					
					pc++;
					break;
				case COZY_INSTR.GET_VAR:
					var name = bytecode[pc+1];
					
					self.pushStack(self.get(name));
					
					pc++;
					break;
				case COZY_INSTR.PUSH_STACK_TOP:
					self.pushStack(self.topStack());
					break;
				case COZY_INSTR.SWAP_STACK_TOP:
					var a = self.popStack();
					var b = self.popStack();
					
					self.pushStack(a);
					self.pushStack(b);
					break;
				case COZY_INSTR.SET_LOCAL:
					var name = bytecode[pc+1];
					var value = self.popStack();
					
					self.setLocal(name,value);
					
					if (struct_exists(self.locals,name))
						array_push(localsAdded,name);
					
					pc++;
					break;
				case COZY_INSTR.REMOVE_LOCAL:
					var name = bytecode[pc+1];
					
					if (struct_exists(self.locals,name))
						struct_remove(self.locals,name);
					if (struct_exists(self.localConsts,name))
						struct_remove(self.localConsts,name);
					var localsAddedIndex = array_get_index(localsAdded,name);
					if (localsAddedIndex >= 0)
						array_delete(localsAdded,localsAddedIndex,1);
					
					pc++;
					break;
				case COZY_INSTR.CALL:
					var maxPushCount = bytecode[pc+1];
					var fn = self.popStack();
					
					if (maxPushCount < 0)
						maxPushCount = infinity;
					
					/* disallow cheeky ways of calling functions with numeric IDs
					so you can't do:
					```
					local randomizeID = 223;
					randomizeID();
					```
					
					so you're forced to:
					```
					import gml.random;
					
					random.Randomize();
					```
					
					*/
					if (!is_struct(fn) and !is_method(fn))
					{
						if (is_numeric(fn))
							throw $"Attempt to call a non-callable value of type {typeof(fn)}";
					}
					else if (!is_instanceof(fn,CozyFunction) and instanceof(fn) != "function")
						throw $"Attempt to call a non-callable value of type {typeof(fn)}";
					if (is_undefined(fn))
						throw $"Attempt to call a non-callable value of type {typeof(fn)}";
					
					var callArguments = [];
					
					// get all arguments
					var top = self.topStack();
					while (!(is_struct(top) and is_instanceof(top,CozyStackFlag) and top.value == COZY_STACKFLAG.ARG_END))
					{
						array_push(callArguments,self.popStack());
						top = self.topStack();
					}
					self.popStack();
					
					// get result
					var result = cozylang_execute(fn,callArguments,self);
					
					var resultCount = min(array_length(result)-1,maxPushCount);
					for (var i = 0; i < resultCount; i++)
						self.pushStack(result[i+1]);
					
					pc++;
					break;
				case COZY_INSTR.GET_PROPERTY:
					var name = self.popStack();
					var object = self.popStack();
					
					if (self.env.nameIsBanned(name))
						throw $"Tried to get invalid name {name}";
					
					self.pushStack(self.getProperty(object,name));
					break;
				case COZY_INSTR.SET_PROPERTY:
					var value = self.popStack();
					var name = self.popStack();
					var object = self.popStack();
					
					self.setProperty(object,name,value);
					break;
				case COZY_INSTR.WRAP_STRUCT:
					var arr = [];
					
					var top = self.topStack();
					while (!(is_struct(top) and is_instanceof(top,CozyStackFlag) and top.value == COZY_STACKFLAG.STRUCT_END))
					{
						array_push(arr,self.popStack());
						top = self.topStack();
					}
					self.popStack();
					
					if (array_length(arr)%2 != 0)
						throw $"Wrong struct literal";
					
					var struct = {};
					for (var i = 0, n = array_length(arr); i < n; i += 2)
					{
						var name = arr[i];
						var value = arr[i+1];
						
						struct[$ name] = value;
					}
					
					self.pushStack(struct);
					
					pc++;
					break;
				case COZY_INSTR.WRAP_ARRAY:
					var arr = [];
					
					var top = self.topStack();
					while (!(is_struct(top) and is_instanceof(top,CozyStackFlag) and top.value == COZY_STACKFLAG.ARRAY_END))
					{
						array_push(arr,self.popStack());
						top = self.topStack();
					}
					self.popStack();
					
					self.pushStack(arr);
					
					pc++;
					break;
				case COZY_INSTR.NEW_OBJECT:
					var pushNewObject = bytecode[pc+1];
					
					/// support for GameMaker constructor functions in the future?
					var cozyClass = self.popStack();
					if (!is_cozyclass(cozyClass))
						throw $"Attempt to create an object of a non-class type";
					
					var newArguments = [];
					
					// get all arguments
					var top = self.topStack();
					while (!(is_struct(top) and is_instanceof(top,CozyStackFlag) and top.value == COZY_STACKFLAG.ARG_END))
					{
						array_push(newArguments,self.popStack());
						top = self.topStack();
					}
					self.popStack();
					
					var object = cozyClass.newObject(newArguments,cozyClass.owner,[],self.env.flags.alwaysCallParentConstructor);
					
					if (pushNewObject)
						self.pushStack(object);
					pc++;
					break;
				case COZY_INSTR.WRAP_CLASS:
					var name = bytecode[pc+1];
					
					var classModifiers = self.popStack();
					var classIsStrict = self.popStack();
					var classParent = self.popStack();
					var classStaticConstructor = self.popStack();
					var classConstructor = self.popStack();
					var classDestructor = self.popStack();
					var classFunctions = self.popStack();
					var classProperties = self.popStack();
					var classOperators = self.popStack();
					var classStatics = self.popStack();
					var classStaticProperties = self.popStack();
					
					var wrappedClass = new CozyClass(
						name,
						classStaticConstructor,
						classConstructor,
						classDestructor,
						classParent,
						classIsStrict,
						classModifiers,
						classStatics,
						classStaticProperties,
						self
					);
					
					// add functions
					for (var i = 0, n = array_length(classFunctions); i < n; i++)
					{
						var fn = classFunctions[i];
						var fnName = string_split(fn.name,".")[1];
						fn.owner = self;
						
						wrappedClass.functions[$ fnName] = fn;
					}
					
					// add properties
					for (var i = 0, n = array_length(classProperties); i < n; i++)
					{
						var property = classProperties[i];
						if (is_cozyfunc(property.getter))
							property.getter.owner = self;
						if (is_cozyfunc(property.setter))
							property.setter.owner = self;
						if (is_cozyfunc(property.initializer))
							property.initializer.owner = self;
						wrappedClass.properties[$ property.name] = property;
					}
					
					// add operators
					var classOperatorNames = struct_get_names(classOperators);
					for (var i = 0, n = array_length(classOperatorNames); i < n; i++)
					{
						var operatorName = classOperatorNames[i];
						var operator = classOperators[$ operatorName];
						operator.owner = self;
						wrappedClass.operators[$ operatorName] = operator;
					}
					
					self.pushStack(wrappedClass);
					
					pc++;
					break;
				case COZY_INSTR.PUSH_STACKFLAG:
					var value = bytecode[pc+1];
					if (!is_numeric(value))
						throw $"Attempt to push a non-numeric stack flag"
					
					self.pushStack(new CozyStackFlag(value));
					pc++;
					break;
				case COZY_INSTR.CLASS_INIT_STATIC:
					var class = self.popStack();
					
					class.staticInit();
					break;
				
				/*
					operators
				*/
				
				case COZY_INSTR.ADD:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("+",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA + operandB);
					break;
				case COZY_INSTR.SUB:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("-",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA - operandB);
					break;
				case COZY_INSTR.MUL:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("*",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA * operandB);
					break;
				case COZY_INSTR.DIV:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("/",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA / operandB);
					break;
				case COZY_INSTR.MOD:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("%",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA % operandB);
					break;
				case COZY_INSTR.NULLISH:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					self.pushStack(operandA ?? operandB);
					break;
				case COZY_INSTR.LSHIFT:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("<<",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA << operandB);
					break;
				case COZY_INSTR.RSHIFT:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload(">>",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA >> operandB);
					break;
				case COZY_INSTR.POSITIVE:
					var value = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handlePrefixOperatorOverload("+",value);
						if (stop)
							break;
					}
					
					self.pushStack(+value);
					break;
				case COZY_INSTR.NEGATE:
					var value = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handlePrefixOperatorOverload("-",value);
						if (stop)
							break;
					}
					
					self.pushStack(-value);
					break;
				case COZY_INSTR.POWER:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("**",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(power(operandA,operandB));
					break;
				case COZY_INSTR.IDIV:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("//",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA div operandB);
					break;
				case COZY_INSTR.IS:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					self.pushStack(operandA == operandB);
					break;
				case COZY_INSTR.EQUALS:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("==",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA == operandB);
					break;
				case COZY_INSTR.LESS_THAN:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("<",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA < operandB);
					break;
				case COZY_INSTR.GREATER_THAN:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload(">",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA > operandB);
					break;
				case COZY_INSTR.LESS_OR_EQUALS:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("<=",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA <= operandB);
					break;
				case COZY_INSTR.GREATER_OR_EQUALS:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload(">=",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA >= operandB);
					break;
				case COZY_INSTR.BAND:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("&",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA & operandB);
					break;
				case COZY_INSTR.BOR:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("|",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA | operandB);
					break;
				case COZY_INSTR.BXOR:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("^",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA ^ operandB);
					break;
				case COZY_INSTR.BNOT:
					var value = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handlePrefixOperatorOverload("~",value);
						if (stop)
							break;
					}
					
					self.pushStack(~value);
					break;
				case COZY_INSTR.AND:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("&&",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA && operandB);
					break;
				case COZY_INSTR.OR:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("||",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA || operandB);
					break;
				case COZY_INSTR.XOR:
					var operandB = self.popStack();
					var operandA = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handleInfixOperatorOverload("^^",operandA,operandB);
						if (stop)
							break;
					}
					
					self.pushStack(operandA ^^ operandB);
					break;
				case COZY_INSTR.NOT:
					var value = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handlePrefixOperatorOverload("!",value);
						if (stop)
							break;
					}
					
					self.pushStack(!value);
					break;
				case COZY_INSTR.INSTANCEOF:
					var class = self.popStack();
					var object = self.popStack();
					
					if (!is_cozyclass(class))
						throw $"Cannot use instanceof on {typeof(class)} value";
					if (!(is_cozyobject(object) or is_undefined(object)))
						throw $"Cannot use instanceof on {typeof(object)} value";
					
					self.pushStack(class.objectIsInstance(object));
					
					break;
				case COZY_INSTR.CLASSOF:
					var object = self.popStack();
					
					var class = undefined;
					if (is_cozyobject(object))
						class = object.class;
					
					self.pushStack(class);
					break;
				case COZY_INSTR.DELETE_OBJECT:
					var object = self.popStack();
					
					if (is_cozyclass(object))
						throw $"Cannot delete class";
					if (is_cozyfunc(object))
						throw $"Cannot delete function";
					if (is_struct(object) and !is_cozyobject(object))
					{
						if (!self.env.canDeleteAnyStruct and (!is_callable(object[$ COZY_NAME_CANDELETE]) or !object[$ COZY_NAME_CANDELETE]()))
						{
							throw $"Cannot delete {instanceof(object)} struct";
						}
						
						delete object;
						break;
					}
					if (!is_cozyobject(object))
						throw $"Attempt to delete a {typeof(object)} value";
					
					var class = object.class;
					
					if (cozylang_is_callable(class.destructorFn))
					{
						var destructorFn = variable_clone(class.destructorFn,1);
						if (is_cozyfunc(destructorFn))
							destructorFn.target = object;
						
						cozylang_execute(destructorFn,[],self);
		
						delete destructorFn;
					}
					delete object;
					
					break;
				case COZY_INSTR.BOOL_COERCE:
					var value = self.popStack();
					
					if (self.env.flags.operatorOverloading)
					{
						var stop = self.handlePrefixOperatorOverload("?",value);
						if (stop)
						{
							var value = self.topStack();
							if (!is_numeric(value))
								throw $"Operator overload for ? prefix operator must return a boolean";
							
							self.popStack();
							self.pushStack(bool(value));
							
							break;
						}
					}
					
					self.pushStack(cozylang_is_truthy(value));
					break;
			}
			
			pc++;
		}
		
		for (var i = 0, n = array_length(localsAdded); i < n; i++)
		{
			if (array_get_index(alreadyExistingLocals,localsAdded[i]) >= 0)
				continue;
			
			struct_remove(self.locals,localsAdded[i]);
			struct_remove(self.localConsts,localsAdded[i]);
		}
		
		array_pop(self.callStack);
		array_pop(global.cozylang.stateStack);
		if (array_length(self.callStack) == 0)
			self.timeoutStart = undefined;
		return returnAmount;
	}
}