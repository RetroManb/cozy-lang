#macro COZY_EMPTY_BYTECODE [COZY_INSTR.HALT]
#macro COZY_BYTECODE_ADDRESS_BUFFERTYPE buffer_u32

/// @ignore
enum __COZY_BYTECODE_ANYTYPE {
	UNDEFINED,
	REAL,
	STRING,
	BOOL,
	BYTE,
	INT32,
	INT64,
	PTR,
	ARRAY,
	STRUCT,
	FUNCTION,
	PROPERTY,
	__SIZE__
}

/// @ignore
/// @param {Id.Buffer} buffer
/// @param {Any} value
function __cozylang_buffer_write_any(buffer,value) {
	switch (typeof(value))
	{
		default:
			show_debug_message($"__cozylang_buffer_write_any: Found invalid type {typeof(value)}");
			break;
		case "undefined":
		case "null":
			break;
		case "number":
			if (frac(value) == 0 and value >= 0 and value <= 256)
			{
				buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.BYTE);
				buffer_write(buffer,buffer_u8,value);
			}
			else
			{
				buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.REAL);
				buffer_write(buffer,buffer_f32,value);
			}
			return;
		case "string":
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.STRING);
			buffer_write(buffer,buffer_string,value);
			return;
		case "array":
			var len = array_length(value);
			
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.ARRAY);
			buffer_write(buffer,buffer_u16,len);
			
			for (var i = 0; i < len; i++)
				__cozylang_buffer_write_any(buffer,value[i]);
			return;
		case "bool":
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.BOOL);
			buffer_write(buffer,buffer_u8,bool(value));
			return;
		case "int32":
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.INT32);
			buffer_write(buffer,buffer_s32,value);
			return;
		case "int64":
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.INT64);
			buffer_write(buffer,buffer_u64,value);
			return;
		case "ptr":
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.PTR);
			buffer_write(buffer,buffer_u64,value);
			return;
		case "struct":
			if (is_cozyfunc(value))
			{
				buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.FUNCTION);
				buffer_write(buffer,buffer_string,value.name);
				__cozylang_buffer_write_any(buffer,value.bytecode);
				__cozylang_buffer_write_any(buffer,value.argNames);
				buffer_write(buffer,buffer_u8,bool(value.hasParams));
				
				return;
			}
			if (is_cozyproperty(value))
			{
				buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.PROPERTY);
				buffer_write(buffer,buffer_string,value.name);
				__cozylang_buffer_write_any(buffer,value.getter);
				__cozylang_buffer_write_any(buffer,value.setter);
				__cozylang_buffer_write_any(buffer,value.initializer);
				__cozylang_buffer_write_any(buffer,value.modifiers);
				
				return;
			}
			
			buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.STRUCT);
			var names = struct_get_names(value);
			for (var i = 0, n = array_length(names); i < n; i++)
			{
				var name = names[i];
				buffer_write(buffer,buffer_string,name);
				__cozylang_buffer_write_any(buffer,value[$ name]);
			}
			buffer_write(buffer,buffer_u8,0);
			return;
	}
	
	buffer_write(buffer,buffer_u8,__COZY_BYTECODE_ANYTYPE.UNDEFINED);
}

/// @ignore
/// @param {Id.Buffer} buffer
/// @returns {Any}
function __cozylang_buffer_read_any(buffer) {
	var type = buffer_read(buffer,buffer_u8);
	
	switch (type)
	{
		default:
		case __COZY_BYTECODE_ANYTYPE.UNDEFINED:
			return undefined;
		case __COZY_BYTECODE_ANYTYPE.REAL:
			return buffer_read(buffer,buffer_f32);
		case __COZY_BYTECODE_ANYTYPE.BYTE:
			return buffer_read(buffer,buffer_u8);
		case __COZY_BYTECODE_ANYTYPE.STRING:
			return buffer_read(buffer,buffer_string);
		case __COZY_BYTECODE_ANYTYPE.ARRAY:
			var len = buffer_read(buffer,buffer_u16);
			var arr = array_create(len,undefined);
			
			for (var i = 0; i < len; i++)
				arr[i] = __cozylang_buffer_read_any(buffer);
			
			return arr;
		case __COZY_BYTECODE_ANYTYPE.BOOL:
			return bool(buffer_read(buffer,buffer_u8));
		case __COZY_BYTECODE_ANYTYPE.INT32:
			return buffer_read(buffer,buffer_s32);
		case __COZY_BYTECODE_ANYTYPE.INT64:
			return buffer_read(buffer,buffer_u64);
		case __COZY_BYTECODE_ANYTYPE.PTR:
			return ptr(buffer_read(buffer,buffer_u8));
		case __COZY_BYTECODE_ANYTYPE.STRUCT:
			var struct = {};
			
			while (buffer_peek(buffer,buffer_tell(buffer),buffer_u8) != 0)
			{
				var name = buffer_read(buffer,buffer_string);
				var value = __cozylang_buffer_read_any(buffer);
				
				struct[$ name] = value;
			}
			buffer_read(buffer,buffer_u8);
			return struct;
		case __COZY_BYTECODE_ANYTYPE.FUNCTION:
			var name = buffer_read(buffer,buffer_string);
			var bytecode = __cozylang_buffer_read_any(buffer);
			var argNames = __cozylang_buffer_read_any(buffer);
			var hasParams = bool(buffer_read(buffer,buffer_u8));
			
			var fn = new CozyFunction(name,bytecode,argNames,hasParams);
			return fn;
		case __COZY_BYTECODE_ANYTYPE.PROPERTY:
			var name = buffer_read(buffer,buffer_string);
			var getter = __cozylang_buffer_read_any(buffer);
			var setter = __cozylang_buffer_read_any(buffer);
			var initializer = __cozylang_buffer_read_any(buffer);
			var modifiers = __cozylang_buffer_read_any(buffer);
			
			var property = new CozyObjectProperty(name,undefined,getter,setter,initializer,modifiers);
			return property;
		
	}
}
/// @ignore
/// @param {Id.Buffer} buffer
/// @param {Real} offset
/// @param {Any} value
function __cozylang_buffer_poke_any(buffer,offset,value) {
	var prev = buffer_tell(buffer);
	
	buffer_seek(buffer,buffer_seek_start,offset);
	
	__cozylang_buffer_write_any(buffer,value);
	
	buffer_seek(buffer,buffer_seek_start,prev);
}
/// @ignore
/// @param {Id.Buffer} buffer
/// @param {Real} offset
/// @returns {Any}
function __cozylang_buffer_peek_any(buffer,offset) {
	var prev = buffer_tell(buffer);
	
	buffer_seek(buffer,buffer_seek_start,offset);
	
	var value = __cozylang_buffer_read_any(buffer);
	
	buffer_seek(buffer,buffer_seek_start,prev);
	
	return value;
}

/// @desc
///		This is only for use with CozyCompiler to make array modification easier
function CozyBytecode() constructor {
	self.bytecode = [];
	
	static push = function(value) {
		array_push(self.bytecode,value);
	}
	static pop = function() {
		return array_pop(self.bytecode);
	}
	static get = function(index) {
		return self.bytecode[index];
	}
	static set = function(index,value) {
		self.bytecode[index] = value;
	}
	static length = function() {
		return array_length(self.bytecode);
	}
	static last = function() {
		return self.bytecode[array_length(self.bytecode)-1];
	}
	static move = function(sourceIndex,count,destIndex) {
		var chunk = [];
		array_copy(chunk,0,self.bytecode,sourceIndex,count);
		array_delete(self.bytecode,sourceIndex,count);
		
		for (var i = 0; i < count; i++)
		{
			array_insert(self.bytecode,destIndex+i,chunk[i]);
		}
	}
	/// @param {Id.Buffer} buffer
	static intoBuffer = function(buffer) {
		var constOffsets = ds_map_create();
		var undefinedOffsets = [];
		
		var addToConsts = method({constOffsets : constOffsets,undefinedOffsets : undefinedOffsets,buffer : buffer},function(key,arrayIndex) {
			if (is_undefined(key))
			{
				array_push(undefinedOffsets,buffer_tell(buffer));
				buffer_write(buffer,COZY_BYTECODE_ADDRESS_BUFFERTYPE,0);
				return;
			}
			
			if (!ds_map_exists(constOffsets,key))
				ds_map_add(constOffsets,key,[]);
			
			array_push(constOffsets[? key],buffer_tell(buffer));
			buffer_write(buffer,COZY_BYTECODE_ADDRESS_BUFFERTYPE,0);
		});
		
		try {
			for (var i = 0, n = self.length(); i < n; i++)
			{
				var instruction = self.bytecode[i];
				if (!is_numeric(instruction))
					throw $"Non-numeric instruction {instruction} found in bytecode during serialization";
				var value = undefined;
				if (i < n-1)
					value = self.bytecode[i+1];
				
				buffer_write(buffer,buffer_u8,instruction % COZY_INSTR.__SIZE__);
			
				switch (instruction)
				{
					default:
						throw $"Unknown instruction {instruction} found in bytecode during serialization";
					case COZY_INSTR.PUSH_CONST:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.MAKE_CONST:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.WRAP_FUNCTION:
						buffer_write(buffer,buffer_u16,value);
						i++;
						break;
					case COZY_INSTR.POP_DISCARD:
						break;
					case COZY_INSTR.ADD:
					case COZY_INSTR.SUB:
					case COZY_INSTR.MUL:
					case COZY_INSTR.DIV:
					case COZY_INSTR.MOD:
					case COZY_INSTR.NULLISH:
					case COZY_INSTR.LSHIFT:
					case COZY_INSTR.RSHIFT:
					case COZY_INSTR.POSITIVE:
					case COZY_INSTR.NEGATE:
					case COZY_INSTR.POWER:
					case COZY_INSTR.IDIV:
						break;
					case COZY_INSTR.JUMP:
					case COZY_INSTR.JUMP_IF_FALSE:
					case COZY_INSTR.JUMP_IF_TRUE:
						buffer_write(buffer,COZY_BYTECODE_ADDRESS_BUFFERTYPE,value);
						i++;
						break;
					case COZY_INSTR.IS:
					case COZY_INSTR.EQUALS:
					case COZY_INSTR.LESS_THAN:
					case COZY_INSTR.GREATER_THAN:
						break;
					case COZY_INSTR.MAKE_LOCAL_CONST:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.IMPORT:
					case COZY_INSTR.IMPORTONLY:
						buffer_write(buffer,buffer_u16,value);
						i++;
						break;
					case COZY_INSTR.LESS_OR_EQUALS:
					case COZY_INSTR.GREATER_OR_EQUALS:
						break;
					case COZY_INSTR.RETURN:
						buffer_write(buffer,buffer_u16,value);
						i++;
						break;
					case COZY_INSTR.HALT:
						break;
					case COZY_INSTR.SET_VAR:
					case COZY_INSTR.GET_VAR:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.PUSH_STACK_TOP:
					case COZY_INSTR.SWAP_STACK_TOP:
						break;
					case COZY_INSTR.SET_LOCAL:
					case COZY_INSTR.REMOVE_LOCAL:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.CALL:
						buffer_write(buffer,buffer_s16,value);
						i++;
						break;
					case COZY_INSTR.BAND:
					case COZY_INSTR.BOR:
					case COZY_INSTR.BXOR:
					case COZY_INSTR.BNOT:
					case COZY_INSTR.AND:
					case COZY_INSTR.OR:
					case COZY_INSTR.XOR:
					case COZY_INSTR.NOT:
						break;
					case COZY_INSTR.GET_PROPERTY:
					case COZY_INSTR.SET_PROPERTY:
						break;
					case COZY_INSTR.INSTANCEOF:
					case COZY_INSTR.CLASSOF:
						break;
					case COZY_INSTR.WRAP_ARRAY:
					case COZY_INSTR.WRAP_STRUCT:
						break;
					case COZY_INSTR.NEW_OBJECT:
						buffer_write(buffer,buffer_u8,bool(value));
						i++;
						break;
					case COZY_INSTR.DELETE_OBJECT:
					case COZY_INSTR.BOOL_COERCE:
						break;
					case COZY_INSTR.WRAP_CLASS:
						addToConsts(value,i+1);
						i++;
						break;
					case COZY_INSTR.PUSH_STACKFLAG:
						buffer_write(buffer,buffer_u8,value);
						i++;
						break;
					case COZY_INSTR.CLASS_INIT_STATIC:
						break;
				}
			}
			
			buffer_write(buffer,buffer_u8,0xFF);
			
			var key = ds_map_find_first(constOffsets);
			while (!is_undefined(key))
			{
				var list = constOffsets[? key];
				for (var i = 0, n = array_length(list); i < n; i++)
				{
					var offset = list[i];
					
					buffer_poke(buffer,offset,COZY_BYTECODE_ADDRESS_BUFFERTYPE,buffer_tell(buffer));
				}
				
				__cozylang_buffer_write_any(buffer,key);
				
				key = ds_map_find_next(constOffsets,key);
			}
			
			if (array_length(undefinedOffsets) > 0)
			{
				for (var i = 0, n = array_length(undefinedOffsets); i < n; i++)
				{
					var offset = undefinedOffsets[i];
					
					buffer_poke(buffer,offset,COZY_BYTECODE_ADDRESS_BUFFERTYPE,buffer_tell(buffer));
				}
				
				__cozylang_buffer_write_any(buffer,undefined);
			}
			
			ds_map_destroy(constOffsets);
		}
		catch (e) {
			if (ds_exists(ds_type_map,constOffsets))
				ds_map_destroy(constOffsets);
			
			throw e;
		}
		
		
	}
	/// @param {Id.Buffer} buffer
	static fromBuffer = function(buffer) {
		var constOffsets = [];
		var constValues = {};
		
		var bc = self;
		var addConstOffset = method({bytecode : bc, constOffsets : constOffsets, buffer : buffer},function() {
			array_push(constOffsets,[bytecode.length(),buffer_tell(buffer)]);
			bytecode.push(undefined);
			buffer_read(buffer,COZY_BYTECODE_ADDRESS_BUFFERTYPE);
		})
		
		while (buffer_peek(buffer,buffer_tell(buffer),buffer_u8) != 0xFF)
		{
			var instruction = buffer_read(buffer,buffer_u8);
			if (!is_numeric(instruction))
				throw $"Non-numeric instruction found in bytecode during deserialization";
			
			self.push(instruction);
			
			switch (instruction)
			{
				default:
					//show_debug_message(buffer_tell(buffer));
					throw $"Unknown instruction {instruction} found in bytecode during deserialization";
				case COZY_INSTR.PUSH_CONST:
					addConstOffset();
					break;
				case COZY_INSTR.MAKE_CONST:
					addConstOffset();
					break;
				case COZY_INSTR.WRAP_FUNCTION:
					self.push(buffer_read(buffer,buffer_u16));
					break;
				case COZY_INSTR.POP_DISCARD:
					break;
				case COZY_INSTR.ADD:
				case COZY_INSTR.SUB:
				case COZY_INSTR.MUL:
				case COZY_INSTR.DIV:
				case COZY_INSTR.MOD:
				case COZY_INSTR.NULLISH:
				case COZY_INSTR.LSHIFT:
				case COZY_INSTR.RSHIFT:
				case COZY_INSTR.POSITIVE:
				case COZY_INSTR.NEGATE:
				case COZY_INSTR.POWER:
				case COZY_INSTR.IDIV:
					break;
				case COZY_INSTR.JUMP:
				case COZY_INSTR.JUMP_IF_FALSE:
				case COZY_INSTR.JUMP_IF_TRUE:
					self.push(buffer_read(buffer,COZY_BYTECODE_ADDRESS_BUFFERTYPE));
					break;
				case COZY_INSTR.IS:
				case COZY_INSTR.EQUALS:
				case COZY_INSTR.LESS_THAN:
				case COZY_INSTR.GREATER_THAN:
					break;
				case COZY_INSTR.MAKE_LOCAL_CONST:
					addConstOffset();
					break;
				case COZY_INSTR.IMPORT:
				case COZY_INSTR.IMPORTONLY:
					self.push(buffer_read(buffer,buffer_u16));
					break;
				case COZY_INSTR.LESS_OR_EQUALS:
				case COZY_INSTR.GREATER_OR_EQUALS:
					break;
				case COZY_INSTR.RETURN:
					self.push(buffer_read(buffer,buffer_u16));
					break;
				case COZY_INSTR.HALT:
					break;
				case COZY_INSTR.SET_VAR:
				case COZY_INSTR.GET_VAR:
					addConstOffset();
					break;
				case COZY_INSTR.PUSH_STACK_TOP:
				case COZY_INSTR.SWAP_STACK_TOP:
					break;
				case COZY_INSTR.SET_LOCAL:
				case COZY_INSTR.REMOVE_LOCAL:
					addConstOffset();
					break;
				case COZY_INSTR.CALL:
					self.push(buffer_read(buffer,buffer_s16));
					break;
				case COZY_INSTR.BAND:
				case COZY_INSTR.BOR:
				case COZY_INSTR.BXOR:
				case COZY_INSTR.BNOT:
				case COZY_INSTR.AND:
				case COZY_INSTR.OR:
				case COZY_INSTR.XOR:
				case COZY_INSTR.NOT:
					break;
				case COZY_INSTR.GET_PROPERTY:
				case COZY_INSTR.SET_PROPERTY:
					break;
				case COZY_INSTR.INSTANCEOF:
				case COZY_INSTR.CLASSOF:
					break;
				case COZY_INSTR.WRAP_STRUCT:
				case COZY_INSTR.WRAP_ARRAY:
					break;
				case COZY_INSTR.NEW_OBJECT:
					self.push(bool(buffer_read(buffer,buffer_u8)));
					break;
				case COZY_INSTR.DELETE_OBJECT:
				case COZY_INSTR.BOOL_COERCE:
					break;
				case COZY_INSTR.WRAP_CLASS:
					addConstOffset();
					break;
				case COZY_INSTR.PUSH_STACKFLAG:
					self.push(buffer_read(buffer,buffer_u8));
					break;
				case COZY_INSTR.CLASS_INIT_STATIC:
					break;
			}
		}
		
		buffer_read(buffer,buffer_u8);
		
		var n = buffer_get_size(buffer);
		while (buffer_tell(buffer) < n)
		{
			var off = buffer_tell(buffer);
			constValues[$ string(off)] = __cozylang_buffer_read_any(buffer);
		}
		
		for (var i = 0, n = array_length(constOffsets); i < n; i++)
		{
			var arr = constOffsets[i];
			var arrOffset = arr[0];
			var buffOffset = arr[1];
			
			var constOffset = buffer_peek(buffer,buffOffset,COZY_BYTECODE_ADDRESS_BUFFERTYPE);
			var value = constValues[$ string(constOffset)];
			self.set(arrOffset,value);
		}
	}
}

/// @desc
///		This is only for use with CozyCompiler to store information about the current body
/// @ignore
function CozyBodyInfo() constructor {
	self.pushStackOnReturn = false;
	
	/// @param {Struct.CozyBodyInfo} bodyInfo
	static inheritFrom = function(bodyInfo) {
		if (is_undefined(bodyInfo))
			return;
		
		self.pushStackOnReturn = bodyInfo.pushStackOnReturn;
	}
}

/// @ignore
/// @param {Struct.CozyNode} node
function __cozylang_expr_is_deterministic(node) {
	switch (node.type)
	{
		default:
			break;
		case COZY_NODE.LITERAL:
			return true;
		case COZY_NODE.IDENTIFIER:
		case COZY_NODE.ARRAY_LITERAL:
		case COZY_NODE.STRUCT_LITERAL:
			return false;
	}
	
	for (var i = 0, n = array_length(node.children); i < n; i++)
	{
		var child = node.children[i];
		
		if (!__cozylang_expr_is_deterministic(child))
			return false;
	}
	
	return true;
}

#region Operators

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_add(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.ADD);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_sub(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.SUB);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_mul(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.MUL);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_div(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.DIV);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_mod(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.MOD);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_power(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.POWER);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_idiv(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.IDIV);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_accessor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	switch (rhsNode.type)
	{
		default:
			throw $"Malformed accessor";
		case COZY_NODE.IDENTIFIER:
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(rhsNode.value);
			break;
	}
	bytecode.push(COZY_INSTR.GET_PROPERTY);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_bracket_accessor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.GET_PROPERTY);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_equals(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.EQUALS);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_notequals(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.EQUALS);
	bytecode.push(COZY_INSTR.NOT);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_le_equals(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.LESS_OR_EQUALS);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_gr_equals(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.GREATER_OR_EQUALS);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_lesser(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.LESS_THAN);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_greater(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.GREATER_THAN);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_and(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.AND);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_or(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.OR);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_xor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.XOR);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_nullish(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.NULLISH);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_band(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.BAND);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_bor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.BOR);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_bxor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.BXOR);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_shift_left(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.LSHIFT);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_shift_right(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.RSHIFT);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_instanceof(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.INSTANCEOF);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_is(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	compiler.compileExpression(rhsNode,bytecode);
	bytecode.push(COZY_INSTR.IS);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		bytecode.pop();
		compiler.compileExpression(rhsNode,bytecode);
		
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_add(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.ADD);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.ADD);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_sub(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.SUB);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.SUB);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_mul(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.MUL);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.MUL);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_div(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.DIV);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.DIV);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_mod(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.MOD);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.MOD);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_power(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.POWER);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.POWER);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_idiv(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.IDIV);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.IDIV);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_nullish(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.NULLISH);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.NULLISH);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_shift_left(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.LSHIFT);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.LSHIFT);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_shift_right(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.RSHIFT);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.RSHIFT);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_band(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BAND);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BAND);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_bor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BOR);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BOR);
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(array_last(targetInfo));
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Struct.CozyNode} rhsNode
/// @param {Real} callReturnCount
function __cozylang_op_infix_assign_bxor(compiler,bytecode,lhsNode,rhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
		
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BXOR);
		
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		compiler.compileExpression(rhsNode,bytecode);
		bytecode.push(COZY_INSTR.BXOR);
		
		bytecode.push(COZY_INSTR.SWAP_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_PROPERTY);
	}
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_plus(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.POSITIVE);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_minus(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.NEGATE);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_not(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.NOT);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_bnot(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.BNOT);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_question(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.BOOL_COERCE);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_delete(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.DELETE_OBJECT);
	
	__cozylang_op_infix_assign(compiler,bytecode,lhsNode,new CozyNode(
		COZY_NODE.LITERAL,
		undefined
	),0);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_classof(compiler,bytecode,lhsNode,callReturnCount) {
	compiler.compileExpression(lhsNode,bytecode);
	bytecode.push(COZY_INSTR.CLASSOF);
}

/// @ignore
/// @param {Struct.CozyCompiler} compiler
/// @param {Struct.CozyBytecode} bytecode
/// @param {Struct.CozyNode} lhsNode
/// @param {Real} callReturnCount
function __cozylang_op_prefix_inc(compiler,bytecode,lhsNode,callReturnCount) {
	var targetInfo = compiler.compileAssignGetTarget(lhsNode,bytecode,true);
	/// needs reworked
	if (array_length(targetInfo) == 1) // <identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(1);
		bytecode.push(COZY_INSTR.ADD);
		bytecode.push(COZY_INSTR.GET_VAR);
		bytecode.push(targetInfo[0]);
	}
	else if (array_length(targetInfo) > 1) // <identifier>.<identifier> = <expression>
	{
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(1);
		bytecode.push(COZY_INSTR.ADD);
		bytecode.push(COZY_INSTR.GET_PROPERTY);
		bytecode.push(array_last(targetInfo));
	}
}

#endregion

/// @ignore
/// @param {Array<Any>} bytecode
/// @returns {String}
function __cozylang_debug_disassemble(bytecode) {
	var disassembly = "";
	
	for (var i = 0; i < array_length(bytecode); i++)
	{
		var instruction = bytecode[i];
		var pc = i;
		
		var line = "";
		
		switch (instruction)
		{
			default:
				line = $"UNKNOWN\n";
				break;
			case COZY_INSTR.PUSH_CONST:
				var value = bytecode[i+1];
				var q = is_string(value) ?
					"\"" : "";
				
				line = $"PUSH_CONST {q}{value}{q}\n";
				i++;
				break;
			case COZY_INSTR.MAKE_CONST:
				var name = bytecode[i+1];
				
				line = $"MAKE_CONST {name}\n";
				i++;
				break;
			case COZY_INSTR.WRAP_FUNCTION:
				var argCount = bytecode[i+1];
				
				line = $"WRAP_FUNCTION {argCount}\n";
				i++;
				break;
			case COZY_INSTR.POP_DISCARD:
				var count = bytecode[i+1];
				
				line = $"POP_DISCARD {count}\n";
				i++;
				break;
			case COZY_INSTR.ADD:
				line = $"ADD\n";
				break;
			case COZY_INSTR.SUB:
				line = $"SUB\n";
				break;
			case COZY_INSTR.MUL:
				line = $"MUL\n";
				break;
			case COZY_INSTR.DIV:
				line = $"DIV\n";
				break;
			case COZY_INSTR.MOD:
				line = $"MOD\n";
				break;
			case COZY_INSTR.NULLISH:
				line = $"NULLISH\n";
				break;
			case COZY_INSTR.LSHIFT:
				line = $"LSHIFT\n";
				break;
			case COZY_INSTR.RSHIFT:
				line = $"RSHIFT\n";
				break;
			case COZY_INSTR.POSITIVE:
				line = $"POSITIVE\n";
				break;
			case COZY_INSTR.NEGATE:
				line = $"NEGATE\n";
				break;
			case COZY_INSTR.POWER:
				line = $"POWER\n";
				break;
			case COZY_INSTR.IDIV:
				line = $"IDIV\n";
				break;
			case COZY_INSTR.JUMP:
				var addr = bytecode[i+1];
				
				line = $"JUMP ${addr}\n";
				i++;
				break;
			case COZY_INSTR.JUMP_IF_FALSE:
				var addr = bytecode[i+1];
				
				line = $"JUMP_IF_FALSE ${addr}\n";
				i++;
				break;
			case COZY_INSTR.JUMP_IF_TRUE:
				var addr = bytecode[i+1];
				
				line = $"JUMP_IF_TRUE ${addr}\n";
				i++;
				break;
			case COZY_INSTR.IS:
				line = $"IS\n";
				break;
			case COZY_INSTR.EQUALS:
				line = $"EQUALS\n";
				break;
			case COZY_INSTR.LESS_THAN:
				line = $"LESS_THAN\n";
				break;
			case COZY_INSTR.GREATER_THAN:
				line = $"GREATER_THAN\n";
				break;
			case COZY_INSTR.MAKE_LOCAL_CONST:
				var name = bytecode[i+1];
				
				line = $"MAKE_LOCAL_CONST {name}\n";
				i++;
				break;
			case COZY_INSTR.IMPORT:
				var count = bytecode[i+1];
				
				line = $"IMPORT {count}\n";
				i++;
				break;
			case COZY_INSTR.IMPORTONLY:
				var count = bytecode[i+1];
				
				line = $"IMPORTONLY {count}\n";
				i++;
				break;
			case COZY_INSTR.LESS_OR_EQUALS:
				line = $"LESS_OR_EQUALS\n";
				break;
			case COZY_INSTR.GREATER_OR_EQUALS:
				line = $"GREATER_OR_EQUALS\n";
				break;
			case COZY_INSTR.RETURN:
				var count = bytecode[i+1];
				
				line = $"RETURN {count}\n";
				i++;
				break;
			case COZY_INSTR.HALT:
				line = $"HALT\n";
				break;
			case COZY_INSTR.SET_VAR:
				var name = bytecode[i+1];
				
				line = $"SET_VAR {name}\n";
				i++;
				break;
			case COZY_INSTR.GET_VAR:
				var name = bytecode[i+1];
				
				line = $"GET_VAR {name}\n";
				i++;
				break;
			case COZY_INSTR.PUSH_STACK_TOP:
				line = $"PUSH_STACK_TOP\n";
				break;
			case COZY_INSTR.SWAP_STACK_TOP:
				line = $"SWAP_STACK_TOP\n";
				break;
			case COZY_INSTR.SET_LOCAL:
				var name = bytecode[i+1];
				
				line = $"SET_LOCAL {name}\n";
				i++;
				break;
			case COZY_INSTR.REMOVE_LOCAL:
				var name = bytecode[i+1];
				
				line = $"REMOVE_LOCAL {name}\n";
				i++;
				break;
			case COZY_INSTR.CALL:
				var returnCount = bytecode[i+1];
				
				line = $"CALL {returnCount}\n";
				i++;
				break;
			case COZY_INSTR.BAND:
				line = $"BAND\n";
				break;
			case COZY_INSTR.BOR:
				line = $"BOR\n";
				break;
			case COZY_INSTR.BXOR:
				line = $"BXOR\n";
				break;
			case COZY_INSTR.BNOT:
				line = $"BNOT\n";
				break;
			case COZY_INSTR.AND:
				line = $"AND\n";
				break;
			case COZY_INSTR.OR:
				line = $"OR\n";
				break;
			case COZY_INSTR.XOR:
				line = $"XOR\n";
				break;
			case COZY_INSTR.NOT:
				line = $"NOT\n";
				break;
			case COZY_INSTR.GET_PROPERTY:
				line = $"GET_PROPERTY\n";
				break;
			case COZY_INSTR.SET_PROPERTY:
				line = $"SET_PROPERTY\n";
				break;
			case COZY_INSTR.INSTANCEOF:
				line = $"INSTANCEOF\n";
				break;
			case COZY_INSTR.CLASSOF:
				line = $"CLASSOF\n";
				break;
			case COZY_INSTR.WRAP_STRUCT:
				line = $"WRAP_STRUCT\n";
				break;
			case COZY_INSTR.WRAP_ARRAY:
				line = $"WRAP_ARRAY\n";
				break;
			case COZY_INSTR.NEW_OBJECT:
				var pushNewObject = bytecode[i+1];
				
				line = $"NEW_OBJECT {pushNewObject ? "true" : "false"}\n";
				i++;
				break;
			case COZY_INSTR.DELETE_OBJECT:
				line = $"DELETE_OBJECT\n";
				break;
			case COZY_INSTR.BOOL_COERCE:
				line = $"BOOL_COERCE\n";
				break;
			case COZY_INSTR.WRAP_CLASS:
				var name = bytecode[i+1];
				
				line = $"WRAP_CLASS \"{name}\"\n";
				i++;
				break;
			case COZY_INSTR.PUSH_STACKFLAG:
				var value = bytecode[i+1];
				
				line = $"PUSH_STACKFLAG {value}\n";
				i++;
				break;
			case COZY_INSTR.CLASS_INIT_STATIC:
				line = $"CLASS_INIT_STATIC\n";
				break;
		}
		
		disassembly += $"${pc}\t\t{line}";
	}
	
	return disassembly;
}

/// @param {Struct.CozyEnvironment} env
function CozyCompiler(env) constructor {
	self.env = env;
	
	self.env.infixOpCompilers[$ "+"] = __cozylang_op_infix_add;
	self.env.infixOpCompilers[$ "-"] = __cozylang_op_infix_sub;
	self.env.infixOpCompilers[$ "*"] = __cozylang_op_infix_mul;
	self.env.infixOpCompilers[$ "/"] = __cozylang_op_infix_div;
	self.env.infixOpCompilers[$ "%"] = __cozylang_op_infix_mod;
	self.env.infixOpCompilers[$ "**"] = __cozylang_op_infix_power;
	self.env.infixOpCompilers[$ "//"] = __cozylang_op_infix_idiv;
	self.env.infixOpCompilers[$ "."] = __cozylang_op_infix_accessor;
	self.env.infixOpCompilers[$ "["] = __cozylang_op_infix_bracket_accessor;
	self.env.infixOpCompilers[$ "=="] = __cozylang_op_infix_equals;
	self.env.infixOpCompilers[$ "!="] = __cozylang_op_infix_notequals;
	self.env.infixOpCompilers[$ "<="] = __cozylang_op_infix_le_equals;
	self.env.infixOpCompilers[$ ">="] = __cozylang_op_infix_gr_equals;
	self.env.infixOpCompilers[$ "<"] = __cozylang_op_infix_lesser;
	self.env.infixOpCompilers[$ ">"] = __cozylang_op_infix_greater;
	self.env.infixOpCompilers[$ "&"] = __cozylang_op_infix_band;
	self.env.infixOpCompilers[$ "|"] = __cozylang_op_infix_bor;
	self.env.infixOpCompilers[$ "^"] = __cozylang_op_infix_bxor;
	self.env.infixOpCompilers[$ "&&"] = __cozylang_op_infix_and;
	self.env.infixOpCompilers[$ "||"] = __cozylang_op_infix_or;
	self.env.infixOpCompilers[$ "^^"] = __cozylang_op_infix_xor;
	self.env.infixOpCompilers[$ "??"] = __cozylang_op_infix_nullish;
	self.env.infixOpCompilers[$ "<<"] = __cozylang_op_infix_shift_left;
	self.env.infixOpCompilers[$ ">>"] = __cozylang_op_infix_shift_right;
	self.env.infixOpCompilers[$ "instanceof"] = __cozylang_op_infix_instanceof;
	self.env.infixOpCompilers[$ "is"] = __cozylang_op_infix_is;
	self.env.infixOpCompilers[$ "="] = __cozylang_op_infix_assign;
	self.env.infixOpCompilers[$ "+="] = __cozylang_op_infix_assign_add;
	self.env.infixOpCompilers[$ "-="] = __cozylang_op_infix_assign_sub;
	self.env.infixOpCompilers[$ "*="] = __cozylang_op_infix_assign_mul;
	self.env.infixOpCompilers[$ "/="] = __cozylang_op_infix_assign_div;
	self.env.infixOpCompilers[$ "%="] = __cozylang_op_infix_assign_mod;
	self.env.infixOpCompilers[$ "**="] = __cozylang_op_infix_assign_power;
	self.env.infixOpCompilers[$ "//="] = __cozylang_op_infix_assign_idiv;
	self.env.infixOpCompilers[$ "??="] = __cozylang_op_infix_assign_nullish;
	self.env.infixOpCompilers[$ "<<="] = __cozylang_op_infix_assign_shift_left;
	self.env.infixOpCompilers[$ ">>="] = __cozylang_op_infix_assign_shift_right;
	self.env.infixOpCompilers[$ "&="] = __cozylang_op_infix_assign_band;
	self.env.infixOpCompilers[$ "|="] = __cozylang_op_infix_assign_bor;
	self.env.infixOpCompilers[$ "^="] = __cozylang_op_infix_assign_bxor;
	
	self.env.prefixOpCompilers[$ "+"] = __cozylang_op_prefix_plus;
	self.env.prefixOpCompilers[$ "-"] = __cozylang_op_prefix_minus;
	self.env.prefixOpCompilers[$ "!"] = __cozylang_op_prefix_not;
	self.env.prefixOpCompilers[$ "~"] = __cozylang_op_prefix_bnot;
	self.env.prefixOpCompilers[$ "?"] = __cozylang_op_prefix_question;
	self.env.prefixOpCompilers[$ "delete"] = __cozylang_op_prefix_delete;
	self.env.prefixOpCompilers[$ "classof"] = __cozylang_op_prefix_classof;
	//self.env.prefixOpCompilers[$ "++"] = __cozylang_op_prefix_inc;
	//self.env.prefixOpCompilers[$ "--"] = __cozylang_op_prefix_dec;
	
	//self.env.postfixOpCompilers[$ "++"] = __cozylang_op_postfix_inc;
	//self.env.postfixOpCompilers[$ "--"] = __cozylang_op_postfix_dec;
	
	self.bodyInfoStack = [];
	
	self.directiveNodes = [];
	
	static currentBodyInfo = function() {
		return array_last(self.bodyInfoStack);
	}
	static pushBodyInfo = function(inheritPrevious=true) {
		var bodyInfo = new CozyBodyInfo();
		if (inheritPrevious)
			bodyInfo.inheritFrom(self.currentBodyInfo());
		
		array_push(self.bodyInfoStack,bodyInfo);
		
		return bodyInfo;
	}
	static popBodyInfo = function() {
		return array_pop(self.bodyInfoStack);
	}
	
	/// @param {Struct.CozyNode} importsNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileImports = function(importsNode,bytecode) {
		for (var i = 0; i < array_length(importsNode.children); i++)
		{
			var child = importsNode.children[i];
			
			switch (child.type)
			{
				default:
					throw $"Malformed import";
				case COZY_NODE.IMPORT:
				case COZY_NODE.IMPORTONLY:
					var names = child.value;
					
					for (var j = array_length(names)-1; j >= 0; j--)
					{
						var name = names[j];
						
						bytecode.push(COZY_INSTR.PUSH_CONST);
						bytecode.push(name);
					}
					
					var instr = child.type == COZY_NODE.IMPORT ?
						COZY_INSTR.IMPORT :
						COZY_INSTR.IMPORTONLY;
					bytecode.push(instr);
					bytecode.push(array_length(names));
					break;
			}
		}
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalVariable = function(localNode,bytecode) {
		var localRes = {
			localsCreated : [],
		}
		
		/*
		
		"local <identifier>,<identifier> = <expression>,<expression>;" syntax should be
		tried at some point
		
		*/
		
		var localName = localNode.value;
		var exprNode = localNode.children[0];
		
		self.compileExpression(exprNode,bytecode);
		
		bytecode.push(COZY_INSTR.SET_LOCAL);
		bytecode.push(localName);
		
		array_push(localRes.localsCreated,localName);
		
		return localRes;
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalFunc = function(localNode,bytecode) {
		self.compileFunc(localNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.SET_LOCAL);
		bytecode.push(localNode.value);
		
		return {
			localsCreated : [localNode.value],
		};
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalClass = function(localNode,bytecode) {
		self.compileClass(localNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.SET_LOCAL);
		bytecode.push(localNode.value);
		
		bytecode.push(COZY_INSTR.CLASS_INIT_STATIC);
		
		return {
			localsCreated : [localNode.value],
		};
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileConstVariable = function(constNode,bytecode) {
		var constName = constNode.value;
		var exprNode = constNode.children[0];
		
		self.compileExpression(exprNode,bytecode);
		
		bytecode.push(COZY_INSTR.MAKE_CONST);
		bytecode.push(constName);
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileConstFunc = function(constNode,bytecode) {
		self.compileFunc(constNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.MAKE_CONST);
		bytecode.push(constNode.value);
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileConstClass = function(constNode,bytecode) {
		self.compileClass(constNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.MAKE_CONST);
		bytecode.push(constNode.value);
		
		bytecode.push(COZY_INSTR.CLASS_INIT_STATIC);
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalConstVariable = function(localNode,bytecode) {
		var localConstRes = {
			localsCreated : [],
		}
		
		/*
		
		"local const <identifier>,<identifier> = <expression>,<expression>;" syntax should be
		tried at some point
		
		*/
		
		var localName = localNode.value;
		var exprNode = localNode.children[0];
		
		self.compileExpression(exprNode,bytecode);
		
		bytecode.push(COZY_INSTR.MAKE_LOCAL_CONST);
		bytecode.push(localName);
		
		array_push(localConstRes.localsCreated,localName);
		
		return localConstRes;
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalConstFunc = function(localNode,bytecode) {
		self.compileFunc(localNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.MAKE_LOCAL_CONST);
		bytecode.push(localNode.value);
		
		return {
			localsCreated : [localNode.value],
		};
	}
	
	/// @param {Struct.CozyNode} localNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileLocalConstClass = function(localNode,bytecode) {
		self.compileClass(localNode,bytecode);
		
		bytecode.pop();
		bytecode.pop();
		bytecode.push(COZY_INSTR.MAKE_LOCAL_CONST);
		bytecode.push(localNode.value);
		
		bytecode.push(COZY_INSTR.CLASS_INIT_STATIC);
		
		return {
			localsCreated : [localNode.value],
		};
	}
	
	/// @param {Struct.CozyNode} ifNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileIf = function(ifNode,bytecode) {
		var expressionNode = ifNode.children[0];
		var trueNode = ifNode.children[1];
		var falseNode = ifNode.children[2];
		
		/*
		simplify
		```
		if (...) {}
		```
		into doing nothing
		
		*/
		if (array_length(trueNode.children) == 0 and falseNode.type == COZY_NODE.BODY and array_length(falseNode.children) == 0)
		{
			return {
				continueOffsets : [],
				breakOffsets : [],
			}
		}
		
		/*
		simplify
		```
		if (...) {}
		else
		{
			<statement>
			...
		}
		```
		into
		```
		if (!(...))
		{
			<statement>
			...
		}
		```
		*/
		if (array_length(trueNode.children) == 0)
		{
			trueNode = ifNode.children[2];
			falseNode = ifNode.children[1];
			
			var notNode = new CozyNode(COZY_NODE.PRE_OPERATOR,"!");
			notNode.addChild(expressionNode);
		
			var boolCoerceNode = new CozyNode(
				COZY_NODE.PRE_OPERATOR,
				"?"
			);
			boolCoerceNode.addChild(notNode);
			
			self.compileExpression(boolCoerceNode,bytecode);
		}
		else
		{
			var boolCoerceNode = new CozyNode(
				COZY_NODE.PRE_OPERATOR,
				"?"
			);
			boolCoerceNode.addChild(expressionNode);
			
			self.compileExpression(boolCoerceNode,bytecode);
		}
		
		bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
		var falseJumpAddrOffset = bytecode.length();
		bytecode.push(undefined);
		
		var res = self.compileBody(trueNode,bytecode);
		var endJumpAddrOffset = undefined;
		
		/*
		don't add jump if the false node is an empty body as it would be useless
		*/
		if (falseNode.type == COZY_NODE.BODY and array_length(falseNode.children) > 0)
		{
			bytecode.push(COZY_INSTR.JUMP);
			endJumpAddrOffset = bytecode.length();
			bytecode.push(undefined);
		}
		
		var falseOffset = bytecode.length();
		
		switch (falseNode.type)
		{
			case COZY_NODE.IF:
				var ifRes = self.compileIf(falseNode,bytecode);
				res.continueOffsets = array_union(res.continueOffsets,ifRes.continueOffsets);
				res.breakOffsets = array_union(res.breakOffsets,ifRes.breakOffsets);
				break;
			case COZY_NODE.BODY:
				var bodyRes = self.compileBody(falseNode,bytecode);
				res.continueOffsets = array_union(res.continueOffsets,bodyRes.continueOffsets);
				res.breakOffsets = array_union(res.breakOffsets,bodyRes.breakOffsets);
				break;
		}
		var endOffset = bytecode.length();
		
		bytecode.set(falseJumpAddrOffset,falseOffset);
		if (is_numeric(endJumpAddrOffset))
			bytecode.set(endJumpAddrOffset,endOffset);
		
		return res;
	}
	
	/// @param {Struct.CozyNode} whileNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileWhile = function(whileNode,bytecode) {
		var expressionNode = whileNode.children[0];
		var bodyNode = whileNode.children[1];
		
		var startOffset = bytecode.length();
		
		self.compileExpression(expressionNode,bytecode);
		
		bytecode.push(COZY_INSTR.BOOL_COERCE);
		bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
		var falseJumpAddrOffset = bytecode.length();
		bytecode.push(undefined);
		
		var res = self.compileBody(bodyNode,bytecode);
		
		bytecode.push(COZY_INSTR.JUMP);
		bytecode.push(startOffset);
		
		var bodyEndOffset = res.endOffset;
		var endOffset = bytecode.length();
		bytecode.set(falseJumpAddrOffset,endOffset);
		
		for (var i = 0, n = array_length(res.continueOffsets); i < n; i++)
			bytecode.set(res.continueOffsets[i],startOffset);
		for (var i = 0, n = array_length(res.breakOffsets); i < n; i++)
			bytecode.set(res.breakOffsets[i],endOffset);
			
		bytecode.move(bodyEndOffset,2*array_length(res.localsCreated),endOffset);
	}
	
	/// @param {Struct.CozyNode} forNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileFor = function(forNode,bytecode) {
		var res = {
			localsCreated : []
		};
		
		var initStatementNode = forNode.children[0];
		var checkExprNode = forNode.children[1];
		var loopStatementNode = forNode.children[2];
		var bodyNode = forNode.children[3];
		
		var statementRes = self.compileStatement(initStatementNode,bytecode);
		res.localsCreated = statementRes.localsCreated;
		
		var startOffset = bytecode.length();
		self.compileExpression(checkExprNode,bytecode);
		
		bytecode.push(COZY_INSTR.BOOL_COERCE);
		bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
		var falseJumpAddrOffset = bytecode.length();
		bytecode.push(undefined);
		
		var bodyRes = self.compileBody(bodyNode,bytecode);
		var bodyEndOffset = bodyRes.endOffset;
		
		var loopStatementOffset = bytecode.length();
		var statementRes = self.compileStatement(loopStatementNode,bytecode);
		res.localsCreated = array_union(res.localsCreated,statementRes.localsCreated);
		
		bytecode.push(COZY_INSTR.JUMP);
		bytecode.push(startOffset);
		
		var endOffset = bytecode.length();
		
		bytecode.set(falseJumpAddrOffset,endOffset);
		
		for (var i = 0, n = array_length(bodyRes.continueOffsets); i < n; i++)
			bytecode.set(res.continueOffsets[i],loopStatementOffset);
		for (var i = 0, n = array_length(bodyRes.breakOffsets); i < n; i++)
			bytecode.set(res.breakOffsets[i],endOffset);
			
		bytecode.move(bodyEndOffset,2*array_length(bodyRes.localsCreated),endOffset);
		
		return res;
	}
	
	/// @param {Struct.CozyNode} bodyNode
	/// @param {Struct.CozyBytecode} bytecode
	/// @param {Bool} inheritBodyInfo
	static compileBody = function(bodyNode,bytecode,inheritBodyInfo=true) {
		var res = {
			continueOffsets : [],
			breakOffsets : [],
			localsCreated : [],
			endOffset : 0,
		};
		
		self.pushBodyInfo(inheritBodyInfo);
		
		for (var i = 0; i < array_length(bodyNode.children); i++)
		{
			var child = bodyNode.children[i];
			
			var statementRes = self.compileStatement(child,bytecode);
			res.continueOffsets = array_union(res.continueOffsets,statementRes.continueOffsets);
			res.breakOffsets = array_union(res.breakOffsets,statementRes.breakOffsets);
			res.localsCreated = array_union(res.localsCreated,statementRes.localsCreated);
		}
		
		res.endOffset = bytecode.length();
		
		for (var i = 0; i < array_length(res.localsCreated); i++)
		{
			bytecode.push(COZY_INSTR.REMOVE_LOCAL);
			bytecode.push(res.localsCreated[i]);
		}
		
		self.popBodyInfo();
		
		return res;
	}
	
	/// @param {Struct.CozyNode} bodyNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileBodyStatement = function(bodyNode,bytecode) {
		var res = {
			continueOffsets : [],
			breakOffsets : [],
			localsCreated : [],
			endOffset : 0,
		};
		
		self.pushBodyInfo();
		
		var startOffset = bytecode.length();
		
		for (var i = 0; i < array_length(bodyNode.children); i++)
		{
			var child = bodyNode.children[i];
			
			var statementRes = self.compileStatement(child,bytecode);
			res.continueOffsets = array_union(res.continueOffsets,statementRes.continueOffsets);
			res.breakOffsets = array_union(res.breakOffsets,statementRes.breakOffsets);
			res.localsCreated = array_union(res.localsCreated,statementRes.localsCreated);
		}
		
		res.endOffset = bytecode.length();
		
		for (var i = 0; i < array_length(res.localsCreated); i++)
		{
			bytecode.push(COZY_INSTR.REMOVE_LOCAL);
			bytecode.push(res.localsCreated[i]);
		}
		
		for (var i = 0, n = array_length(res.continueOffsets); i < n; i++)
			bytecode.set(res.continueOffsets[i],startOffset);
		for (var i = 0, n = array_length(res.breakOffsets); i < n; i++)
			bytecode.set(res.breakOffsets[i],res.endOffset);
		
		self.popBodyInfo();
	}
	
	/// @param {Struct.CozyNode} doWhileNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileDoWhile = function(doWhileNode,bytecode) {
		
		var exprNode = doWhileNode.children[0];
		var bodyNode = doWhileNode.children[1];
		
		var startOffset = bytecode.length();
		
		var res = self.compileBody(bodyNode,bytecode);
		
		self.compileExpression(exprNode,bytecode);
		
		bytecode.push(COZY_INSTR.BOOL_COERCE);
		bytecode.push(COZY_INSTR.JUMP_IF_TRUE);
		bytecode.push(startOffset);
		
		var endOffset = bytecode.length();
		var bodyEndOffset = res.endOffset;
		
		for (var i = 0, n = array_length(res.continueOffsets); i < n; i++)
			bytecode.set(res.continueOffsets[i],startOffset);
		for (var i = 0, n = array_length(res.breakOffsets); i < n; i++)
			bytecode.set(res.breakOffsets[i],endOffset);
			
		bytecode.move(bodyEndOffset,2*array_length(res.localsCreated),endOffset);
	}
	
	/// @param {Struct.CozyNode} funcNode
	/// @param {Struct.CozyBytecode} bytecode
	/// @param {String} forceName
	/// @param {Array<String>} argNames
	static compileFunc = function(funcNode,bytecode,forceName=undefined,argNames=[]) {
		var argsNode = funcNode.children[0];
		var bodyNode = funcNode.children[1];
		var funcName = is_string(forceName) ?
			forceName :
			funcNode.value;
		
		var hasParams = false;
		
		for (var i = 0, n = array_length(argsNode.children); i < n; i++)
		{
			var argNode = argsNode.children[i];
			
			array_push(argNames,argNode.value);
			
			if (i == n-1 and argNode.type == COZY_NODE.ARGUMENT_PARAMS)
				hasParams = true;
		}
		
		var fnBytecodeStruct = new CozyBytecode();
		self.compileBody(bodyNode,fnBytecodeStruct,false);
		fnBytecodeStruct.push(COZY_INSTR.HALT);
		var fnBytecode = fnBytecodeStruct.bytecode;
		delete fnBytecodeStruct;
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(funcName);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(fnBytecode);
		for (var i = array_length(argNames)-1; i >= 0; i--)
		{
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(argNames[i]);
		}
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(hasParams);
		bytecode.push(COZY_INSTR.WRAP_FUNCTION);
		bytecode.push(array_length(argNames));
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(funcName);
	}
	
	/// @param {Struct.CozyNode} switchNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileSwitch = function(switchNode,bytecode) {
		var expressionNode = switchNode.children[0];
		var caseCount = array_length(switchNode.children)-1;
		if (caseCount == 0)
			return;
		else if (caseCount == 1)
		{
			var caseNode = switchNode.children[1];
			
			switch (caseNode.type)
			{
				case COZY_NODE.CASE:
					var caseExprNode = caseNode.children[0];
					var caseBodyNode = caseNode.children[1];
					
					self.compileExpression(caseExprNode,bytecode);
					
					bytecode.push(COZY_INSTR.EQUALS);
					bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
					var endJumpAddrOffset = bytecode.length();
					bytecode.push(undefined);
					
					bytecode.push(COZY_INSTR.POP_DISCARD);
					
					var bodyRes = self.compileBody(caseBodyNode,bytecode);
					
					for (var i = 0, n = array_length(bodyRes.breakOffsets); i < n; i++)
						bytecode.set(endJumpAddrOffset,bodyRes.endOffset);
					
					bytecode.set(endJumpAddrOffset,bodyRes.endOffset);
					break;
				case COZY_NODE.CASE_DEFAULT:
					var bodyNode = switchNode.children[0];
					
					if (is_string(defaultNode.value))
					{
						self.compileExpression(switchExpressionNode,bytecode);
						
						bytecode.push(COZY_INSTR.SET_LOCAL);
						bytecode.push(defaultNode.value);
					}
						
					var bodyRes = self.compileBody(bodyNode,byteCode);
					
					if (is_string(defaultNode.value))
					{
						bytecode.push(COZY_INSTR.REMOVE_LOCAL);
						bytecode.push(defaultNode.value);
					}
					
					for (var i = 0, n = array_length(bodyRes.breakOffsets); i < n; i++)
						bytecode.set(bodyRes.breakOffsets[i],bodyRes.endOffset);
					break;
			}
		}
		
		/// Unoptimized switch statement, add optimizations sometime later?
		/*
		my idea of how it would compile unoptimized
		switch (<switch_expr>)
		{
		    case <case1_expr>
		    {
		        <case1_body>
		    }
		    case <case2_expr>
		    {
		        <case2_body>
		    }
		    default
		    {
		        <default_body>
		    }
		}
		<...>
		
			<SWITCH_EXPR>
		.case1
			PUSH_STACK_TOP		--- duplicate switch expression onto top of stack
			<CASE1_EXPR>
			EQUALS				--- check
			JUMP_IF_FALSE .case2
			POP_DISCARD 1		--- pop switch expression
			<CASE1_BODY>
			JUMP .end
		.case2
			PUSH_STACK_TOP		--- duplicate switch expression onto top of stack
			<CASE2_EXPR>
			EQUALS				--- check
			JUMP_IF_FALSE .default
			POP_DISCARD 1		--- pop switch expression
			<CASE2_BODY>
			JUMP .end
		.default
			POP_DISCARD 1		--- pop switch expression
			<DEFAULT_BODY>
		.end
			<...>
		
		if default has an identifier
		switch (<switch_expr>)
		{
		    case <case1_expr>
		    {
		        <case1_body>
		    }
		    case <case2_expr>
		    {
		        <case2_body>
		    }
		    default <identifier>
		    {
		        <default_body>
		    }
		}
		<...>
		
			<SWITCH_EXPR>
		.case1
			PUSH_STACK_TOP		--- duplicate switch expression onto top of stack
			<CASE1_EXPR>
			EQUALS				--- check
			JUMP_IF_FALSE .case2
			POP_DISCARD 1		--- pop switch expression
			<CASE1_BODY>
			JUMP .end
		.case2
			PUSH_STACK_TOP		--- duplicate switch expression onto top of stack
			<CASE2_EXPR>
			EQUALS				--- check
			JUMP_IF_FALSE .default
			POP_DISCARD 1		--- pop switch expression
			<CASE2_BODY>
			JUMP .end
		.default
			SET_LOCAL <identifier>
			<DEFAULT_BODY>
			REMOVE_LOCAL <identifier>
		.end
			<...>
		
		*/
		var caseNodes = [];
		
		var defaultIndex = -1;
		for (var i = 0; i < caseCount; i++)
		{
			var caseNode = switchNode.children[i+1];
			
			switch (caseNode.type)
			{
				case COZY_NODE.CASE:
					array_push(caseNodes,caseNode);
					break;
				case COZY_NODE.CASE_DEFAULT:
					defaultIndex = i;
					break;
			}
		}
		
		if (defaultIndex >= 0)
			array_push(caseNodes,switchNode.children[defaultIndex+1]);
		
		self.compileExpression(expressionNode,bytecode);
		
		var endJumpAddrOffsets = [];
		var nextJumpAddrOffset = undefined;
		
		for (var i = 0; i < caseCount; i++)
		{
			var caseNode = caseNodes[i];
			
			if (is_numeric(nextJumpAddrOffset))
				bytecode.set(nextJumpAddrOffset,bytecode.length());
			
			switch (caseNode.type)
			{
				case COZY_NODE.CASE:
					var caseExprNode = caseNode.children[0];
					var caseBodyNode = caseNode.children[1];
					
					bytecode.push(COZY_INSTR.PUSH_STACK_TOP);
					
					self.compileExpression(caseExprNode,bytecode);
					
					bytecode.push(COZY_INSTR.EQUALS);
					bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
					nextJumpAddrOffset = bytecode.length();
					bytecode.push(undefined);
					
					bytecode.push(COZY_INSTR.POP_DISCARD);
					bytecode.push(1);
					
					var bodyRes = self.compileBody(caseBodyNode,bytecode);
					
					for (var j = 0, n = array_length(bodyRes.breakOffsets); j < n; j++)
						array_push(endJumpAddrOffsets,bodyRes.breakOffsets[j]);
					
					bytecode.push(COZY_INSTR.JUMP);
					array_push(endJumpAddrOffsets,bytecode.length());
					bytecode.push(undefined);
					break;
				case COZY_NODE.CASE_DEFAULT:
					var varName = caseNode.value;
					var defaultBodyNode = caseNode.children[0];
					
					if (is_string(varName))
					{
						bytecode.push(COZY_INSTR.SET_LOCAL);
						bytecode.push(varName);
					}
					else
					{
						bytecode.push(COZY_INSTR.POP_DISCARD);
						bytecode.push(1);
					}
					
					var bodyRes = self.compileBody(defaultBodyNode,bytecode);
					
					var endOffset = bodyRes.endOffset;
					
					if (is_string(varName))
					{
						bytecode.push(COZY_INSTR.REMOVE_LOCAL);
						bytecode.push(varName);
					}
					
					for (var j = 0, n = array_length(bodyRes.breakOffsets); j < n; j++)
						array_push(endJumpAddrOffsets,bodyRes.breakOffsets[j]);
						
					break;
			}
		}
		
		var endOffset = bytecode.length();
		
		for (var i = 0, n = array_length(endJumpAddrOffsets); i < n; i++)
			bytecode.set(endJumpAddrOffsets[i],endOffset);
	}
	
	/// @param {Struct.CozyNode} classNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileClass = function(classNode,bytecode) {
		var className = classNode.value;
		var modifiersNode = classNode.children[0];
		var isStrict = classNode.children[1].value;
		var parentName = classNode.children[2].value;
		
		var modifiers = modifiersNode.getAllChildrenValues();
		
		var staticConstructorNode = undefined;
		var constructorNode = undefined;
		var destructorNode = undefined;
		var funcNodes = [];
		var propertyNodes = [];
		var operatorNodes = [];
		
		var classIsStatic = array_get_index(modifiers,"static") >= 0;
		
		/// find nodes
		for (var i = 3, n = array_length(classNode.children); i < n; i++)
		{
			var node = classNode.children[i];
			
			switch (node.type)
			{
				case COZY_NODE.CLASS_CONSTRUCTOR:
					if (!is_undefined(constructorNode))
						throw $"Duplicate constructor found in class {className}";
					
					var constructorModifiers = node.children[2].getAllChildrenValues();
					
					if (array_get_index(constructorModifiers,"static") >= 0)
					{
						staticConstructorNode = node;
						break;
					}
					else if (classIsStatic)
						throw $"Non-static constructor found in static class {className}";
					
					constructorNode = node;
					break;
				case COZY_NODE.CLASS_DESTRUCTOR:
					if (!is_undefined(destructorNode))
						throw $"Duplicate destructor found in class {className}";
					
					if (classIsStatic)
						throw $"Destructor found in static class {className}";
					
					destructorNode = node;
					break;
				case COZY_NODE.CLASS_FUNC:
					array_push(funcNodes,node);
					break;
				case COZY_NODE.CLASS_PROPERTY:
					array_push(propertyNodes,node);
					break;
				case COZY_NODE.CLASS_OPERATOR:
					array_push(operatorNodes,node);
					break;
			}
		}
		
		var classStatics = {};
		var classStaticProperties = {};
		
		/// operators
		var operatorStruct = {};
		
		for (var i = 0, n = array_length(operatorNodes); i < n; i++)
		{
			var operatorNode = operatorNodes[i];
			
			var operatorModifiersNode = operatorNode.children[0];
			var operatorModifiers = operatorModifiersNode.getAllChildrenValues();
			
			// TODO: static operators
			// var isStatic = array_get_index(operatorModifiers,"static") >= 0;
			
			var typeIdentifierNode = operatorNode.children[1];
			var argsNode = operatorNode.children[2];
			var opBodyNode = operatorNode.children[3];
			
			var shorthand = "";
			switch (typeIdentifierNode.value)
			{
				case "infix":
					shorthand = "in";
					break;
				case "prefix":
					shorthand = "pr";
					break;
				case "postfix":
					shorthand = "po";
					break;
			}
			
			var opName = $"{shorthand}${operatorNode.value}";
			var argNames = [COZY_SELF_NAME];
			
			for (var j = 0, n2 = array_length(argsNode.children); j < n2; j++)
			{
				var argNode = argsNode.children[j];
				
				array_push(argNames,argNode.value);
			}
			
			var opBytecodeStruct = new CozyBytecode();
			self.compileBody(opBodyNode,opBytecodeStruct,false);
			opBytecodeStruct.push(COZY_INSTR.HALT);
			var opBytecode = opBytecodeStruct.bytecode;
			delete opBytecodeStruct;
			
			//show_debug_message(opName);
			//show_debug_message(opBodyNode);
			//show_debug_message(__cozylang_debug_disassemble(opBytecode));
			
			var wrappedFunction = new CozyFunction($"{className}.{typeIdentifierNode.value} {operatorNode.value}",opBytecode,argNames,false);
			
			operatorStruct[$ opName] = wrappedFunction;
		}
		
		/// properties
		var propertyArr = [];
		
		for (var i = 0, n = array_length(propertyNodes); i < n; i++)
		{
			var propertyNode = propertyNodes[i];
			
			var propModifiersNode = propertyNode.children[0];
			var propExprNode = propertyNode.children[1];
			var propModifiers = propModifiersNode.getAllChildrenValues();
			
			var isStatic = array_get_index(propModifiers,"static") >= 0;
			
			var propName = propertyNode.value;
			var propGetter = undefined;
			var propSetter = undefined;
			
			if (classIsStatic and !isStatic)
				throw $"Non-static property {propName} found in static class {className}";
			
			for (var j = 2, n2 = array_length(propertyNode.children); j < n2; j++)
			{
				var node = propertyNode.children[j];
				
				switch (node.type)
				{
					case COZY_NODE.CLASS_PROPERTY_GETTER:
						propGetter = node;
						break;
					case COZY_NODE.CLASS_PROPERTY_SETTER:
						propSetter = node;
						break;
				}
			}
			
			var propGetterFn = undefined;
			var propSetterFn = undefined;
			var propInitializerFn = undefined;
			
			// getter
			if (!is_undefined(propGetter))
			{
				var propArgsNode = propGetter.children[0];
				var propBodyNode = propGetter.children[1];
				
				var argNames = [COZY_SELF_NAME];
					
				for (var j = 0, n2 = array_length(propArgsNode.children); j < n2; j++)
				{
					var argNode = propArgsNode.children[j];
				
					array_push(argNames,argNode.value);
				}
				
				var fnBytecodeStruct = new CozyBytecode();
				self.compileBody(propBodyNode,fnBytecodeStruct,false);
				fnBytecodeStruct.push(COZY_INSTR.HALT);
				var fnBytecode = fnBytecodeStruct.bytecode;
				delete fnBytecodeStruct;
				
				propGetterFn = new CozyFunction($"{className}.{propName}.get",fnBytecode,argNames,false);
			}
			// setter
			if (!is_undefined(propSetter))
			{
				var propArgsNode = propSetter.children[0];
				var propBodyNode = propSetter.children[1];
				
				var argNames = [COZY_SELF_NAME];
				
				for (var j = 0, n2 = array_length(propArgsNode.children); j < n2; j++)
				{
					var argNode = propArgsNode.children[j];
				
					array_push(argNames,argNode.value);
				}
				
				var fnBytecodeStruct = new CozyBytecode();
				self.compileBody(propBodyNode,fnBytecodeStruct,false);
				fnBytecodeStruct.push(COZY_INSTR.HALT);
				var fnBytecode = fnBytecodeStruct.bytecode;
				delete fnBytecodeStruct;
				
				propSetterFn = new CozyFunction($"{className}.{propName}.set",fnBytecode,argNames,false);
			}
			// initializer
			if (!(propExprNode.type == COZY_NODE.LITERAL and propExprNode.value == undefined))
			{
				var argNames = [COZY_SELF_NAME];
				
				var fnBytecodeStruct = new CozyBytecode();
				self.compileExpression(propExprNode,fnBytecodeStruct,false);
				fnBytecodeStruct.push(COZY_INSTR.RETURN);
				fnBytecodeStruct.push(1);
				fnBytecodeStruct.push(COZY_INSTR.HALT);
				var fnBytecode = fnBytecodeStruct.bytecode;
				delete fnBytecodeStruct;
				
				propInitializerFn = new CozyFunction($"{className}.{propName}.init",fnBytecode,argNames,false);
			}
			
			var wrappedProperty = new CozyObjectProperty(propName,undefined,propGetterFn,propSetterFn,propInitializerFn,propModifiers);
			
			if (!isStatic)
				array_push(propertyArr,wrappedProperty);
			else
				classStaticProperties[$ propName] = wrappedProperty;
		}
		
		/// functions
		var funcArr = [];
		
		for (var i = 0, n = array_length(funcNodes); i < n; i++)
		{
			var funcNode = funcNodes[i];
			
			var funcModifiersNode = funcNode.children[0];
			var funcModifiers = funcModifiersNode.getAllChildrenValues();
			
			var isStatic = array_get_index(funcModifiers,"static") >= 0;
			
			var argsNode = funcNode.children[1];
			var fnBodyNode = funcNode.children[2];
			
			var fnName = funcNode.value;
			var argNames = [COZY_SELF_NAME];
			var fnHasParams = false;
			
			if (classIsStatic and !isStatic)
				throw $"Non-static function {fnName} found in static class {className}";
			
			for (var j = 0, n2 = array_length(argsNode.children); j < n2; j++)
			{
				var argNode = argsNode.children[j];
				
				array_push(argNames,argNode.value);
				
				if (j == n2-1 and argNode.type == COZY_NODE.ARGUMENT_PARAMS)
					fnHasParams = true;
			}
			
			var fnBytecodeStruct = new CozyBytecode();
			self.compileBody(fnBodyNode,fnBytecodeStruct,false);
			fnBytecodeStruct.push(COZY_INSTR.HALT);
			var fnBytecode = fnBytecodeStruct.bytecode;
			delete fnBytecodeStruct;
			
			var wrappedFunction = new CozyFunction($"{className}.{fnName}",fnBytecode,argNames,fnHasParams);
			
			if (!isStatic)
				array_push(funcArr,wrappedFunction);
			else
				classStatics[$ fnName] = wrappedFunction;
		}
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(classStaticProperties);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(classStatics);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(operatorStruct);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(propertyArr);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(funcArr);
		
		/// destructor
		if (is_undefined(destructorNode))
		{
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(undefined);
		}
		else
		{
			self.compileFunc(destructorNode,bytecode,$"{className}.destructor",[COZY_SELF_NAME]);
			bytecode.pop();
			bytecode.pop();
		}
		
		/// constructor
		if (is_undefined(constructorNode))
		{
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(undefined);
		}
		else
		{
			show_debug_message(constructorNode);
			self.compileFunc(constructorNode,bytecode,$"{className}.constructor",[COZY_SELF_NAME]);
			bytecode.pop();
			bytecode.pop();
		}
		
		/// static constructor
		if (is_undefined(staticConstructorNode))
		{
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(undefined);
		}
		else
		{
			self.compileFunc(staticConstructorNode,bytecode,$"{className}.static constructor",[COZY_SELF_NAME]);
			bytecode.pop();
			bytecode.pop();
		}
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(parentName);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(isStrict);
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(modifiers);
		bytecode.push(COZY_INSTR.WRAP_CLASS);
		bytecode.push(className);
		bytecode.push(COZY_INSTR.PUSH_STACK_TOP);
		bytecode.push(COZY_INSTR.SET_VAR);
		bytecode.push(className);
	}
	
	/// @param {Struct.CozyNode} returnNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileReturn = function(returnNode,bytecode) {
		var expressionNodes = returnNode.children;
		
		var bodyInfo = self.currentBodyInfo();
		
		if (bodyInfo.pushStackOnReturn)
		{
			var breakJumpAddrOffset = undefined;
			
			if (array_length(expressionNodes) == 0)
			{
				bytecode.push(COZY_INSTR.PUSH_CONST);
				bytecode.push(undefined);
				bytecode.push(COZY_INSTR.PUSH_CONST);
				bytecode.push(1);
			
				bytecode.push(COZY_INSTR.JUMP);
				breakJumpAddrOffset = bytecode.length();
				bytecode.push(undefined);
			}
			else
			{
				for (var i = 0, n = array_length(expressionNodes); i < n; i++)
				{
					self.compileExpression(expressionNodes[i],bytecode);
				}
				bytecode.push(COZY_INSTR.PUSH_CONST);
				bytecode.push(array_length(expressionNodes));
			
				bytecode.push(COZY_INSTR.JUMP);
				breakJumpAddrOffset = bytecode.length();
				bytecode.push(undefined);
			}
			
			return {breakOffsets: [breakJumpAddrOffset]};
		}
		else
		{
			if (array_length(expressionNodes) == 0)
			{
				bytecode.push(COZY_INSTR.PUSH_CONST);
				bytecode.push(undefined);
			
				bytecode.push(COZY_INSTR.RETURN);
				bytecode.push(1);
			}
			else
			{
				for (var i = 0, n = array_length(expressionNodes); i < n; i++)
				{
					self.compileExpression(expressionNodes[i],bytecode);
				}
			
				bytecode.push(COZY_INSTR.RETURN);
				bytecode.push(array_length(expressionNodes));
			}
			
			return {breakOffsets: []};
		}
	}
	
	/// @param {Struct.CozyNode} statementNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileStatement = function(statementNode,bytecode) {
		var res = {
			continueOffsets : [],
			breakOffsets : [],
			localsCreated : []
		};
		
		switch (statementNode.type)
		{
			default:
				throw $"Unexpected node found in body during compilation";
			case COZY_NODE.BIN_OPERATOR:
			case COZY_NODE.PRE_OPERATOR:
			case COZY_NODE.POST_OPERATOR:
			case COZY_NODE.CALL:
			case COZY_NODE.NEW_OBJECT:
				self.compileExpression(statementNode,bytecode,false,0);
				break;
			case COZY_NODE.LOCAL_VARIABLE:
				var localRes = self.compileLocalVariable(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.LOCAL_FUNC:
				var localRes = self.compileLocalFunc(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.LOCAL_CLASS:
				var localRes = self.compileLocalClass(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.CONST_VARIABLE:
				self.compileConstVariable(statementNode,bytecode);
				break;
			case COZY_NODE.CONST_FUNC:
				self.compileConstFunc(statementNode,bytecode);
				break;
			case COZY_NODE.CONST_CLASS:
				self.compileConstClass(statementNode,bytecode);
				break;
			case COZY_NODE.LOCAL_CONST_VARIABLE:
				var localRes = self.compileLocalConstVariable(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.LOCAL_CONST_FUNC:
				var localRes = self.compileLocalConstFunc(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.LOCAL_CONST_CLASS:
				var localRes = self.compileLocalConstClass(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,localRes.localsCreated);
				break;
			case COZY_NODE.IF:
				var ifRes = self.compileIf(statementNode,bytecode);
				res.continueOffsets = array_union(res.continueOffsets,ifRes.continueOffsets);
				res.breakOffsets = array_union(res.breakOffsets,ifRes.breakOffsets);
				break;
			case COZY_NODE.WHILE:
				self.compileWhile(statementNode,bytecode);
				break;
			case COZY_NODE.FOR:
				var forRes = self.compileFor(statementNode,bytecode);
				res.localsCreated = array_union(res.localsCreated,forRes.localsCreated);
				break;
			case COZY_NODE.BODY:
				self.compileBodyStatement(statementNode,bytecode);
				break;
			case COZY_NODE.DO_WHILE:
				self.compileDoWhile(statementNode,bytecode);
				break;
			case COZY_NODE.FUNC_DECLARATION:
				self.compileFunc(statementNode,bytecode);
				break;
			case COZY_NODE.SWITCH:
				self.compileSwitch(statementNode,bytecode);
				break;
			case COZY_NODE.CLASS:
				self.compileClass(statementNode,bytecode);
				
				bytecode.push(COZY_INSTR.CLASS_INIT_STATIC);
				break;
			case COZY_NODE.RETURN:
				var returnRes = self.compileReturn(statementNode,bytecode);
				res.breakOffsets = array_union(res.breakOffsets,returnRes.breakOffsets);
				break;
			case COZY_NODE.BREAK:
				bytecode.push(COZY_INSTR.JUMP);
				var breakOffset = bytecode.length();
				bytecode.push(undefined);
					
				array_push(res.breakOffsets,breakOffset);
				break;
			case COZY_NODE.CONTINUE:
				bytecode.push(COZY_INSTR.JUMP);
				var continueOffset = bytecode.length();
				bytecode.push(undefined);
					
				array_push(res.continueOffsets,continueOffset);
				break;
		}
		
		return res;
	}
	
	/// @param {Struct.CozyNode} funcNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileFuncExpression = function(funcNode,bytecode) {
		var argsNode = funcNode.children[0];
		var bodyNode = funcNode.children[1];
		
		var hasParams = false;
		
		var argNames = [];
		for (var i = 0, n = array_length(argsNode.children); i < n; i++)
		{
			var argNode = argsNode.children[i];
			
			array_push(argNames,argNode.value);
			
			if (i == n-1 and argNode.type == COZY_NODE.ARGUMENT_PARAMS)
				hasParams = true;
		}
		
		var fnBytecodeStruct = new CozyBytecode();
		self.compileBody(bodyNode,fnBytecodeStruct,false);
		fnBytecodeStruct.push(COZY_INSTR.HALT);
		var fnBytecode = fnBytecodeStruct.bytecode;
		delete fnBytecodeStruct;
		
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push($"<anonymousfunction-{ptr(fnBytecode)}>");
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(fnBytecode);
		for (var i = array_length(argNames)-1; i >= 0; i--)
		{
			bytecode.push(COZY_INSTR.PUSH_CONST);
			bytecode.push(argNames[i]);
		}
		bytecode.push(COZY_INSTR.PUSH_CONST);
		bytecode.push(hasParams);
		bytecode.push(COZY_INSTR.WRAP_FUNCTION);
		bytecode.push(array_length(argNames));
	}
	
	/// @param {Struct.CozyNode} expressionNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileExpression = function(expressionNode,bytecode,dontOptimize=false,callReturnCount=1) {
		if (!dontOptimize)
		{
			var isDeterministic = __cozylang_expr_is_deterministic(expressionNode);
			/*
			precompile deterministic expression so that
				`2 + 2`
			
			doesn't become
				PUSH_CONST 2
				PUSH_CONST 2
				ADD
			
			and instead becomes
				PUSH_CONST 4
				ADD
			
			
			*/
			if (isDeterministic)
			{
				switch (expressionNode.type)
				{
					case COZY_NODE.LITERAL:
						break;
					case COZY_NODE.BIN_OPERATOR:
					case COZY_NODE.PRE_OPERATOR:
					case COZY_NODE.POST_OPERATOR:
						var precompiledExprBytecodeStruct = new CozyBytecode();
					
						self.compileExpression(expressionNode,precompiledExprBytecodeStruct,true);
						precompiledExprBytecodeStruct.push(COZY_INSTR.HALT);
						
						var precompiledExprBytecode = precompiledExprBytecodeStruct.bytecode;
						delete precompiledExprBytecodeStruct;
						
						var precompileState = new CozyState(self.env);
						precompileState.runFunction(new CozyFunction($"<precompilation-expression {ptr(expressionNode)}>",precompiledExprBytecode));
					
						var result = precompileState.popStack();
						delete precompileState;
					
						bytecode.push(COZY_INSTR.PUSH_CONST);
						bytecode.push(result);
						return;
				}
			}
		}
		
		switch (expressionNode.type)
		{
			default:
				throw $"Malformed expression";
			case COZY_NODE.SWITCH:
				var bodyInfo = self.currentBodyInfo();
				bodyInfo.pushStackOnReturn = true;
				
				self.compileSwitch(expressionNode,bytecode);
				
				bytecode.push(COZY_INSTR.POP_DISCARD);
				bytecode.push(1);
				
				bodyInfo.pushStackOnReturn = false;
				break;
			case COZY_NODE.BIN_OPERATOR:
				self.env.infixOpCompilers[$ expressionNode.value](self,bytecode,expressionNode.children[0],expressionNode.children[1],callReturnCount);
				break;
			case COZY_NODE.PRE_OPERATOR:
				self.env.prefixOpCompilers[$ expressionNode.value](self,bytecode,expressionNode.children[0],callReturnCount);
				break;
			case COZY_NODE.POST_OPERATOR:
				self.env.postfixOpCompilers[$ expressionNode.value](self,bytecode,expressionNode.children[0],callReturnCount);
				break;
			case COZY_NODE.IDENTIFIER:
				bytecode.push(COZY_INSTR.GET_VAR);
				bytecode.push(expressionNode.value);
				break;
			case COZY_NODE.LITERAL:
				bytecode.push(COZY_INSTR.PUSH_CONST);
				bytecode.push(expressionNode.value);
				break;
			case COZY_NODE.CALL:
				bytecode.push(COZY_INSTR.PUSH_STACKFLAG);
				bytecode.push(COZY_STACKFLAG.ARG_END);
				
				for (var i = array_length(expressionNode.children)-1; i >= 1; i--)
				{
					self.compileExpression(expressionNode.children[i],bytecode,false,-1);
				}
				self.compileExpression(expressionNode.children[0],bytecode);
				
				bytecode.push(COZY_INSTR.CALL);
				bytecode.push(callReturnCount);
				break;
			case COZY_NODE.FUNC_EXPRESSION:
				self.compileFuncExpression(expressionNode,bytecode);
				break;
			case COZY_NODE.NEW_OBJECT:
				self.compileNew(expressionNode,bytecode,callReturnCount);
				break;
			case COZY_NODE.IF_EXPRESSION:
				self.compileIfExpression(expressionNode,bytecode);
				break;
		}
	}
	
	/// @param {Struct.CozyNode} ifExprNode
	/// @param {Struct.CozyBytecode} bytecode
	static compileIfExpression = function(ifExprNode,bytecode) {
		var expressionNode = ifExprNode.children[0];
		var trueNode = ifExprNode.children[1];
		var falseNode = ifExprNode.children[2];
		
		var notNode = new CozyNode(
			COZY_NODE.PRE_OPERATOR,
			"?"
		);
		notNode.addChild(expressionNode);
		
		//show_debug_message(notNode);
		//show_debug_message(trueNode);
		//show_debug_message(falseNode);
		
		self.compileExpression(notNode,bytecode);
		
		bytecode.push(COZY_INSTR.JUMP_IF_FALSE);
		var falseJumpAddrOffset = bytecode.length();
		bytecode.push(undefined);
		
		self.compileExpression(trueNode,bytecode);
		bytecode.push(COZY_INSTR.JUMP);
		var endJumpAddrOffset = bytecode.length();
		bytecode.push(undefined);
		
		var falseOffset = bytecode.length();
		self.compileExpression(falseNode,bytecode);
		
		var endOffset = bytecode.length();
		
		bytecode.set(falseJumpAddrOffset,falseOffset);
		bytecode.set(endJumpAddrOffset,endOffset);
	}
	
	/// @param {Struct.CozyNode} newNode
	/// @param {Struct.CozyBytecode} bytecode
	/// @param {Bool} pushNewObject
	static compileNew = function(newNode,bytecode,pushNewObject) {
		bytecode.push(COZY_INSTR.PUSH_STACKFLAG);
		bytecode.push(COZY_STACKFLAG.ARG_END);
		
		var exprNode = newNode.children[0];
		if (array_length(newNode.children) > 1) // has args
		{
			for (var i = array_length(newNode.children)-1; i >= 1; i--)
			{
				self.compileExpression(newNode.children[i],bytecode,false,-1);
			}
		}
		self.compileExpression(exprNode,bytecode);
		
		bytecode.push(COZY_INSTR.NEW_OBJECT);
		bytecode.push(pushNewObject == 1);
		
	}
	
	/// @param {Struct.CozyNode} expressionNode
	/// @param {Struct.CozyBytecode} bytecode
	/// @param {BooL} modifying
	/// @returns {Array<Any>}
	static compileAssignGetTarget = function(expressionNode,bytecode,modifying=false,__top=true) {
		switch (expressionNode.type)
		{
			default:
				throw $"Malformed assignment";
			case COZY_NODE.BIN_OPERATOR:
				if (expressionNode.value != "." and expressionNode.value != "[")
					throw $"Malformed assignment";
				
				var lhs = expressionNode.children[0];
				var rhs = expressionNode.children[1];
				
				var targetInfo = [];
				
				switch (lhs.type)
				{
					default:
						throw $"Malformed assignment";
					case COZY_NODE.BIN_OPERATOR:
						targetInfo = self.compileAssignGetTarget(lhs,bytecode,modifying,false);
						break;
					case COZY_NODE.IDENTIFIER:
						bytecode.push(COZY_INSTR.GET_VAR);
						bytecode.push(lhs.value);
						
						array_push(targetInfo,lhs.value);
						break;
				}
				switch (rhs.type)
				{
					default:
						throw $"Malformed assignment";
					case COZY_NODE.IDENTIFIER:
					case COZY_NODE.LITERAL:
						if (modifying and __top)
						{
							bytecode.push(COZY_INSTR.PUSH_STACK_TOP);
						}
						bytecode.push(COZY_INSTR.PUSH_CONST);
						bytecode.push(rhs.value);
						bytecode.push(COZY_INSTR.GET_PROPERTY);
						
						array_push(targetInfo,rhs.value);
						break;
				}
				
				return targetInfo;
			case COZY_NODE.IDENTIFIER:
				return [expressionNode.value];
		}
	}
	
	/// @param {Struct.CozyNode} rootNode
	/// @returns {Array<Any>}
	static compile = function(rootNode) {
		if (rootNode.type != COZY_NODE.ROOT)
			throw $"Invalid root node";
		
		var bytecode = new CozyBytecode();
		
		var directivesNode = rootNode.children[0];
		var importsNode = rootNode.children[1];
		var bodyNode = rootNode.children[2];
		
		self.directiveNodes = directivesNode.children;
		
		self.compileImports(importsNode,bytecode);
		self.compileBody(bodyNode,bytecode);
		
		bytecode.push(COZY_INSTR.HALT);
		
		var finalBytecode = bytecode.bytecode;
		delete bytecode;
		
		/// @feather disable GM1045
		return finalBytecode;
		/// @feather enable GM1045
		
	}
}