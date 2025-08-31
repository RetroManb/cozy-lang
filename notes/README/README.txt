CozyLang (*.cozy) is like the weird lovechild of Catspeak (by @katsaii), Lua, and other programming
languages.

Example code below:

```
/// FizzBuzz
/// Also yes comments are triple-slashes, sorry.
import cozy.std;
import cozy.string;

local count = 100;

for (local i = 1; i <= count; i += 1) {
	local out = "";
	
	if (i % 3 == 0) {
		out += "Fizz";
	}
	if (i % 5 == 0) {
		out += "Buzz";
	}
	if (out == "") { // OR string.IsEmpty(out)
		out = string.ToString(i);
	}
	
	print(out);
}
```