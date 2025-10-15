<picture>
  <img
    align="right"
    width="25%"
    height="25%"
    alt="Cozy Logo"
    src="./logo.png">
</picture>

# Cozy Programming Language

**Cozy** (`.cozy`, `.cz`) is like a weird hybrid of [Catspeak](https://github.com/katsaii/catspeak-lang) (by [@katsaii](https://github.com/katsaii)), Lua, C#, Java, Javascript, Python, and probably some more languages. Cozy is meant to be a GameMaker library where you can write external scripts to be compiled and ran later inside GameMaker games.

Documentation can be found in the [wiki](https://github.com/RetroManB/cozy-lang/wiki).

## Examples

```java
/// FizzBuzz
/// Also yes comments are triple-slashes, not double, sorry.
import cozy.std;
import cozy.string;

local count = 100;

for (local i = 1; i <= count; i++) {
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

## Performance

I dunno it's probably decent
