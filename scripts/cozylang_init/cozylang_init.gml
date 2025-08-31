function cozylang_init() {
	global.cozylang = {};
	
	global.cozylang.envFlags = new CozyEnvironmentFlags();
	global.cozylang.stateStack = [];
	global.cozylang.baseClass = new CozyClass("Object");
}