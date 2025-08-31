function cozylang_init() {
	global.cozylang = {};
	
	global.cozylang.stateStack = [];
	global.cozylang.baseClass = new CozyClass("Object");
}