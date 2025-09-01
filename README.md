<picture>
  <img
    align="right"
    width="25%"
    height="25%"
    alt="Cozy Logo"
    src="./logo.png">
</picture>

# Cozy Programming Language

**Cozy** (`.cozy`, `.cz`) is like the weird lovechild of [Catspeak](https://github.com/katsaii/catspeak-lang) (by [@katsaii](https://github.com/katsaii)), Lua, C#, Java, Javascript, Python, and probably some more languages. Cozy is meant to be a GameMaker library where you can write external scripts to be compiled and ran later inside GameMaker games.

## Examples

```java
/// FizzBuzz
/// Also yes comments are triple-slashes, not double, sorry.
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

# *Everything under here will be put into a wiki when I make this public, I'm lazy*

## All reserved words

`if else while for func switch case default return break continue property import params local const goto do class constructor destructor new delete instanceof classof is operator`

## Performance

I dunno it's probably decent

# Environment flags

Environment flags are boolean values that can be used to toggle features for a specific Cozy Environment. They can be accessed through the `CozyEnvironment` struct like `env.flags.*`.

| Name | Description | Benefits | Default |
| - | - | - | - |
| `operatorOverloading` | Allow operator overloading? | `true` - Allows for operator overloading.<br />`false` - Disallows operator overloading but can reduce overhead on objects that have no overloaded operators. | `true` |
| `structLiteralsAreCozyObject` | Make CozyObjects instead of structs when creating a struct literal? |  | `false` |
| `alwaysCallParentConstructor` | Always call parent constructor? |  | `true` |
| `structGetterSetters` | Use `__CozyGet` and `__CozySet` methods on structs when getting/setting a variable from a struct? | `true` - Allows for getters and setters for non-`CozyObject` structs.<br />`false` - Potentially reduces overhead on structs. | `true` |
| `importSubLibraries` | Import a libraries sub-libraries on import? |  | `true` |

# Libraries

Libraries are a way of including code from other scripts, or built-in libraries. Libraries can have sub-libraries attached to them. By default, importing a library will also import it's sub-libraries, this can be disabled with the environment flag `importSubLibraries`. You can also only import the specified library and none of it's sub-libraries by putting an exclamation-mark (`!`) after the `import` keyword.

## Examples

```java
import cozy; /// Import the entire cozy library, including its sub-libraries
```
```java
import cozy.string; /// Import the entire cozy libraries string sub-library, including its sub-libraries
```
```java
import! cozy; /// Only import the cozy library and none of its sub-libraries
```

## Syntax

`import` \[ `!` ] *identifier* \[ (`.` *identifier*)... ] `;`

# Operators

| Precedence | Internal Precedence | Operator | Description | Associativity |
| - | - | - | - | - |
| 13 | N/A | `(x)` | Grouping | N/A |
| 12 | N/A | `x(...)`<br/>`new x(...)`<br/>`new x` | Function call<br/>New object<br/>New object without arguments | Left to Right |
| 11 | N/A | `+x`<br/>`-x`<br/>`!x`<br/>`~x`<br/>`?x`<br/>`delete x`<br/>`classof x` | Unary plus<br/>Negation<br/>Boolean not<br/>Bit-wise not<br/>Boolean coercion<br/>Delete object<br/>Get class of object | N/A |
| 10 | N/A | `x[y]` | Property accessor | Left to Right |
| 9 | `20` | `x.y` | Property accessor | Left to Right |
| 8 | `18` | `x instanceof y`<br/>`x is y` | Instance of<br/>Is same | Left to Right |
| 7 | `15` | `x & y`<br/>`x \| y`<br/>`x ^ x` | Bit-wise and<br/>Bit-wise or<br/>Bit-wise exclusive or | Left to Right |
| 6 | `12` | `x << y`<br/>`x >> y` | Bit-shift left<br/>Bit-shift right | Left to Right |
| 5 | `12` | `x ** y` | Exponentiation | Right to Left |
| 4 | `11` | `x * y`<br/>`x / y`<br/>`x // y`<br/>`x % y` | Multiplication<br/>Division<br/>Integer division<br/>Modulo | Left to Right |
| 3 | `10` | `x + y`<br/>`x - y` | Addition<br/>Subtraction | Left to Right |
| 2 | `5` | `x == y`<br/>`x != y`<br/>`x < y`<br/>`x > y`<br/>`x <= y`<br/>`x >= y` | Equals<br/>Not equals<br/>Less than<br/>Greater than<br/>Less than or equal to<br/>Greater than or equal to | Left to Right |
| 1 | `0` | `x = y`<br/>`x += y`<br/>`x -= y`<br/>`x *= y`<br/>`x /= y`<br/>`x %= y`<br/>`x // =`<br/>`x **= y`<br/>`x ??= y`<br/>`x <<= y`<br/>`x >>= y`<br/>`x &= y`<br/>`x \|= y`<br/>`x ^= y` | Assign<br/>Add assign<br/>Subtract assign<br/>Multiply assign<br/>Divide assign<br/>Modulus assign<br/>Integer divide assign<br/>Exponent assign<br/>Nullish coalesce assign<br/>Bit-shift left assign<br/>Bit-shift right assign<br/>Bit-wise and assign<br/>Bit-wise or assign<br/>Bit-wise exclusive or assign | Left to Right |
| 0 | `-5` | `x && y`<br/>`x \|\| y`<br/>`x ^^ x` | Boolean and<br/>Boolean or<br/>Boolean exclusive or | Left to Right |

# Directives

## `define` directive

The `define` directive will replace every instance of *identifier* for whatever is supplied in *replacement-list*.

### Examples
```java
import cozy.std;

#define HELLO_WORLD_TEXT "Hello, World!"

print(HELLO_WORLD_TEXT); //prints Hello, World!
```
```java
import cozy.std;

#define MULTILINE_MACRO 1 \
  + \
  2

print(MULTILINE_MACRO); //prints 3
```

### Syntax

`#define` *identifier* *replacement-list*

## `include` directive

The `include` directive will substitute another Cozy script files contents into the position it is located in the file. *filepath* must be a string, and if no file exists there no file will be included.

The entire files contents will be included exactly, meaning defining a class in another script and including it would be defining a seperate class. Use imports if you need this behavior.

### Examples
```java
/// script1.cozy
import cozy.std;

#include "script2.cozy"
/* would be the same as:
#define SCRIPT_NAME "script2.cozy"
#define HEY "Hi from " + SCRIPT_NAME
*/

print(HEY); /// prints Hi from script2.cozy
```
```java
/// script2.cozy

#define SCRIPT_NAME "script2.cozy"
#define HEY "Hi from " + SCRIPT_NAME

```

### Syntax

`#include` *filepath*
