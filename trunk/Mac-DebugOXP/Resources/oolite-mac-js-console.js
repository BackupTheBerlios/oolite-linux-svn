/*

oolite-mac-js-console.js

JavaScript section of JavaScript console implementation.

This script is attached to a one-off JavaScript object of type Console, which
represents the Objective-C portion of the implementation. Commands entered
into the console are passed to this script’s consolePerformJSCommand()
function. Since console commands are performed within the context of this
script, they have access to any functions in this script. You can therefore
add debugger commands using a customized version of this script.

The following properties are predefined for the script object:
console: the console object.

The console object has the following properties and methods:
global: the global object. Adding properties (including methods) to this
		object makes them available to all JS code in Oolite.

function consoleMessage(colorCode: string, message: string) : void
	Similar to Log(), but takes a colour code which is looked up in
	jsConsoleConfig.plist. null is equivalent to "general".

function clearConsole() : void
	Clear the console.

function scriptStack() : array
	Since a script may perform actions that cause other scripts to run, more
	than one script may be “running” at a time, although only one will be
	actively running at a given time the others are suspended until it
	finishes. For example, if script A causes a ship to be created, and that
	ship has a script B, B will be the active script and A will be suspended.
	The scriptStack() method returns an array of all suspended scripts, with
	the running script at the end. In the example, it would return [A, B] if
	called from B.
	Note that calling a method on an object defined by another script does not
	affect the “script stack”.


Oolite Debug OXP

Copyright © 2007 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

this.name = "oolite-mac-js-console"
this.version = "1.69.2"


// **** Predefined macros -- copy this script and add your own here.

this.macros =
{
	// Predefined macros
	"setM":		"setMacro(PARAM)",
	"delM":		"deleteMacro(PARAM)",
	"showM":	"showMacro(PARAM)",
	
	"listM":	"dumpObject(debugConsole.macros)",
	"ds":		"dumpSystemInfo()",
	"d":		"dumpObject(eval(PARAM))",
	"dl":		"dumpObjectLong(eval(PARAM))",
	"ds":		"dumpObject(debugConsole.settings)",
	
	"clr":		"debugConsole.clearConsole()",
	"clear":	"debugConsole.clearConsole()",
	
	// For creating/testing colour sets. Colours changed in this way aren’t saved.
	"fgColor":	"setColorFromString(PARAM, 'foreground')",
	"bgColor":	"setColorFromString(PARAM, 'background')"
}

// ****  Convenience functions -- copy this script and add your own here.

function setColorFromString(string, typeName)
{ 
	// Slice of the first component, where components are separated by one or more spaces.
	var tok = getOneToken(string)
	var key = tok[0]
	var value = tok[1]
	
	var fullKey = key + "-" + typeName + "-color"
	
	debugConsole.settings[fullKey] = eval(value)
	ConsoleMessage("command-result", "Set " + typeName + " colour “" + key + "” to " + value + ".")
}


// Example: type dumpSystemInfo() at the console to get information about the system.
function dumpSystemInfo()
{
	ConsoleMessage("dumpsysteminfo", "  System ID " + system.ID + " “" + system.name + "”")
	ConsoleMessage("dumpsysteminfo", "  Description: “" + system.description + "”")
	ConsoleMessage("dumpsysteminfo", "  Inhabitants: " + system.population + " * 100 million “" + system.inhabitantsDescription + "”")
	ConsoleMessage("dumpsysteminfo", "  Government: " + system.government + " (“" + system.governmentDescription + "”)")
	ConsoleMessage("dumpsysteminfo", "  Economy: " + system.economy + " (“" + system.economyDescription + "”)")
	ConsoleMessage("dumpsysteminfo", "  Tech Level: " + system.techLevel)
	LogScriptStack()
}


// List the enumerable properties of an object.
function dumpObject(x)
{
	ConsoleMessage("dumpobject", x.toString() + ":")
	for (var prop in x)
	{
		ConsoleMessage("dumpobject", "    " + prop)
	}
}


// List the enumerable properties of an object, and their values.
function dumpObjectLong(x)
{
	ConsoleMessage("dumpobject", x.toString() + ":")
	for (var prop in x)
	{
		ConsoleMessage("dumpobject", "    " + prop + " = " + x[prop])
	}
}


// ****  Conosole command handler

this.consolePerformJSCommand = function(command)
{
	while (command.charAt(0) == " ")
	{
		command = command.substring(1)
	}
	if (command.charAt(0) != ":")
	{
		// No colon prefix, just JavaScript code.
		this.evaluate(command, "command")
	}
	else
	{
		// Colon prefix, this is a macro.
		this.handleMacro(command)
	}
}


this.evaluate = function(command, type, PARAM)
{
	var result = eval(command)
	if (result)  ConsoleMessage("command-result", result.toString())
}


this.handleMacro = function(command)
{
	// Handle macros.
	// Strip the initial colon
	command = command.substring(1)
	
	// Split at first series of spaces
	var tok = getOneToken(command)
	var macroName = tok[0]
	var parameters = tok[1]
	
	this.performMacro(macroName, parameters)
}


// ****  Macro handling

function setMacro(parameters)
{
	// Split at first series of spaces
	var tok = getOneToken(parameters)
	var name = tok[0]
	var body = tok[1]
	
	if (body)
	{
		macros[name] = body
		
		ConsoleMessage("macro-info", "Set macro :" + name + ".")
	}
	else
	{
		ConsoleMessage("macro-error", "setMacro(): a macro definition must have a name and a body.")
	}
}


function deleteMacro(parameters)
{
	var tok = getOneToken(parameters)
	var name = tok[0]
	var tail = tok[1]
	
	if (tail)
	{
		ConsoleMessage("macro-warning", "deleteMacro(): ignoring trailing junk.")
	}
	if (name.charAt(0) == ":")  name = name.substring(1)
	
	if (macros[name])
	{
		delete macros[name]
		ConsoleMessage("macro-info", "Deleted macro :" + name + ".")
	}
	else
	{
		ConsoleMessage("macro-info", "Macro :" + name + " is not defined.")
	}
}


function showMacro(parameters)
{
	var tok = getOneToken(parameters)
	var name = tok[0]
	var tail = tok[1]
	
	if (tail)
	{
		ConsoleMessage("macro-warning", "showMacro(): ignoring trailing junk.")
	}
	if (name.charAt(0) == ":")  name = name.substring(1)
	
	if (macros[name])
	{
		ConsoleMessage("macro-info", ":" + name + " = " + macros[name])
	}
	else
	{
		ConsoleMessage("macro-info", "Macro :" + name + " is not defined.")
	}
}


this.performMacro = function(macroName, parameters)
{
	// Command should be prefixed with :. Parameters are currently ignored.
	var expansion = macros[macroName]
	if (expansion)
	{
		// Show macro expansion.
		var displayExpansion = expansion
		if (parameters)
		{
			// Substitute parameter string into display expansion, going from 'foo(PARAM)' to 'foo("parameters")'.
			// This isn't entirely right; it doesn’t perform proper escaping of quotation marks, for instance.
			var paramString = '"' + parameters + '"'
			var offset = displayExpansion.indexOf("PARAM")
			while (offset != -1)
			{
				displayExpansion = displayExpansion.substring(0, offset) + paramString + displayExpansion.substring(offset + 5)
				
				offset = displayExpansion.indexOf("PARAM")
			}
		}
		ConsoleMessage("macro-expansion", "> " + displayExpansion)
		
		// Perform macro.
		this.evaluate(expansion, "macro", parameters)
	}
	else
	{
		ConsoleMessage("unknown-macro", "Macro :" + macroName + " is not defined.")
	}
}


// ****  Load-time set-up

// Make console globally visible as debugConsole
var global = this.console.global
global.debugConsole = this.console
debugConsole.script = this

// Make console.consoleMessage() globally visible as ConsoleMessage()
global.ConsoleMessage = function()
{
	// Call debugConsole.consoleMessage() with console as "this" and all the arguments passed to ConsoleMessage().
	debugConsole.consoleMessage.apply(console, arguments)
}

// Make console.scriptStack() globally visible as ScriptStack()
global.ScriptStack = function()
{
	// Call debugConsole.scriptStack() with console as "this" and all the arguments passed to ScriptStack().
	return debugConsole.scriptStack.apply(console, arguments)
}

// Add global convenience function to log the script stack.
// FIXME: this is broken! Probably as a result of bugs in the NSArray <-> JS array bridge.
global.LogScriptStack = function(messageClass)
{
	if (!messageClass)
	{
		messageClass = "jsDebug.scriptStack"
	}
	
	var stack = ScriptStack()
	var count = stack.count
	var depth = 0
	for (var i = 0; i < count; i++)
	{
		var message = stack[i].name
		for (var j = 0; j < depth; j++)
		{
			message = "  " + message
		}
		LogWithClass(messageClass, message)
		depth++
	}
}


/*
	Split a string at the first sequence of spaces, returning an array with
	two elements. If there are no spaces, the first element of the result will
	be the input string, and the second will be null. Leading spaces are
	stripped. Examples:
	
	getOneToken("x y") == ["x", "y"]
	getOneToken("x   y") == ["x", "y"]
	getOneToken("  x y") == ["x", "y"]
	getOneToken("xy") == ["xy", null]
	getOneToken(" xy") == ["xy", null]
	getOneToken("") == ["", null]
	getOneToken(" ") == ["", null]
 */
function getOneToken(string)
{
	var matcher = /\s+/g		// Regular expression to match one or more spaces.
	matcher.lastIndex = 0
	var match = matcher.exec(string)
	
	if (match)
	{
		var token = string.substring(0, match.index)	// Text before spaces
		var tail = string.substring(matcher.lastIndex)	// Text after spaces
		
		if (token.length != 0)  return [token, tail]
		else  return getOneToken(tail)  // Handle leading spaces case. This won't recurse more than once.
	}
	else
	{
		// No spaces
		return [string, null]
	}
}
