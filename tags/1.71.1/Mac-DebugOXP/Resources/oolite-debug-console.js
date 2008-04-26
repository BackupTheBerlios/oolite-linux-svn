/*

oolite-debug-console.js

JavaScript section of JavaScript console implementation.

This script is attached to a one-off JavaScript object of type Console, which
represents the Objective-C portion of the implementation. Commands entered
into the console are passed to this script’s consolePerformJSCommand()
function. Since console commands are performed within the context of this
script, they have access to any functions in this script. You can therefore
add debugger commands using a customized version of this script.

The following properties are predefined for the script object:
	console: the console object.

The console object has the following methods:

function consoleMessage(colorCode : String, message : String)
	Similar to Log(), but takes a colour code which is looked up in
	jsConsoleConfig.plist. null is equivalent to "general".

function clearConsole()
	Clear the console.

function inspectEntity(entity : Entity)
	Show inspector palette for entity (Mac OS X only).


Oolite Debug OXP

Copyright © 2007-2008 Jens Ayton

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

this.name			= "oolite-debug-console";
this.author			= "Jens Ayton";
this.copyright		= "© 2007-2008 the Oolite team.";
this.description	= "Debug console script.";
this.version		= "1.71.1";


// **** Macros

// Normally, these will be overwritten with macros from the config plist.
this.macros =
{
	setM:		"setMacro(PARAM)",
	delM:		"deleteMacro(PARAM)",
	showM:		"showMacro(PARAM)"
};


// ****  Convenience functions -- copy this script and add your own here.

// List the enumerable properties of an object.
this.dumpObjectShort = function (x)
{
	consoleMessage("dumpObject", x.toString() + ":");
	for (let prop in x)
	{
		consoleMessage("dumpObject", "    " + prop);
	}
}


this.performLegacyCommand = function (x)
{
	let [command, params] = x.getOneToken();
	return player.call(command, params);
}


// List the enumerable properties of an object, and their values.
this.dumpObjectLong = function (x)
{
	consoleMessage("dumpObject", x.toString() + ":");
	for (let prop in x)
	{
		consoleMessage("dumpObject", "    " + prop + " = " + x[prop]);
	}
}


// Print the objects in a list on lines.
this.printList = function (l)
{
	let length = l.length;
	
	consoleMessage("printList", length.toString() + " items:");
	for (let i = 0; i != length; i++)
	{
		consoleMessage("printList", "  " + l[i].toString());
	}
}


this.setColorFromString = function (string, typeName)
{ 
	// Slice of the first component, where components are separated by one or more spaces.
	let [key, value] = string.getOneToken();
	let fullKey = key + "-" + typeName + "-color";
	
	/*	Set the colour. The "let c" stuff is so that JS property lists (like
		{ hue: 240, saturation: 0.12 } will work -- this syntax is only valid
		in assignments.
	*/
	debugConsole.settings[fullKey] = eval("let c=" + value + ";c");
	
	consoleMessage("command-result", "Set " + typeName + " colour “" + key + "” to " + value + ".");
}


// ****  Conosole command handler

this.consolePerformJSCommand = function (command)
{
	while (command.charAt(0) == " ")
	{
		command = command.substring(1);
	}
	
	// Echo input to console, emphasising the command itself.
	consoleMessage("command", "> " + command, 2, command.length);
	
	if (command.charAt(0) != ":")
	{
		// No colon prefix, just JavaScript code.
		this.evaluate(command, "command");
	}
	else
	{
		// Colon prefix, this is a macro.
		this.performMacro(command);
	}
}


this.evaluate = function (command, type, PARAM)
{
	let result = eval(command);
	if (result === null)  result = "null";
	if (result !== undefined)
	{
		consoleMessage("command-result", result.toString());
	}
}


// ****  Macro handling

this.setMacro = function (parameters)
{
	if (!parameters)  return;
	
	// Split at first series of spaces
	let [name, body] = parameters.getOneToken();
	
	if (body)
	{
		macros[name] = body;
		debugConsole.settings["macros"] = macros;
		
		consoleMessage("macro-info", "Set macro :" + name + ".");
	}
	else
	{
		consoleMessage("macro-error", "setMacro(): a macro definition must have a name and a body.");
	}
}


this.deleteMacro = function (parameters)
{
	if (!parameters)  return;
	
	let [name, ] = parameters.getOneToken();
	
	if (name.charAt(0) == ":" && name != ":")  name = name.substring(1);
	
	if (macros[name])
	{
		delete macros[name];
		debugConsole.settings["macros"] = macros;
		
		consoleMessage("macro-info", "Deleted macro :" + name + ".");
	}
	else
	{
		consoleMessage("macro-info", "Macro :" + name + " is not defined.");
	}
}


this.showMacro = function (parameters)
{
	if (!parameters)  return;
	
	let [name, ] = parameters.getOneToken();
	
	if (name.charAt(0) == ":" && name != ":")  name = name.substring(1);
	
	if (macros[name])
	{
		consoleMessage("macro-info", ":" + name + " = " + macros[name]);
	}
	else
	{
		consoleMessage("macro-info", "Macro :" + name + " is not defined.");
	}
}


this.performMacro = function (command)
{
	if (!command)  return;
	
	// Strip the initial colon
	command = command.substring(1);
	
	// Split at first series of spaces
	let [macroName, parameters] = command.getOneToken();
	if (macros[macroName] !== undefined)
	{
		let expansion = macros[macroName];
		
		if (expansion)
		{
			// Show macro expansion.
			let displayExpansion = expansion;
			if (parameters)
			{
				// Substitute parameter string into display expansion, going from 'foo(PARAM)' to 'foo("parameters")'.
				displayExpansion = displayExpansion.replace(/PARAM/g, '"' + parameters.substituteEscapeCodes() + '"');
			}
			consoleMessage("macro-expansion", "> " + displayExpansion);
			
			// Perform macro.
			this.evaluate(expansion, "macro", parameters);
		}
	}
	else
	{
		consoleMessage("unknown-macro", "Macro :" + macroName + " is not defined.");
	}
}


// ****  Utility functions

/*
	Split a string at the first sequence of spaces, returning an array with
	two elements. If there are no spaces, the first element of the result will
	be the input string, and the second will be null. Leading spaces are
	stripped. Examples:
	
	"x y"   -->  ["x", "y"]
	"x   y" -->  ["x", "y"]
	"  x y" -->  ["x", "y"]
	"xy"    -->  ["xy", null]
	" xy"   -->  ["xy", null]
	""      -->  ["", null]
	" "     -->  ["", null]
 */
String.prototype.getOneToken = function ()
{
	let matcher = /\s+/g;		// Regular expression to match one or more spaces.
	matcher.lastIndex = 0;
	let match = matcher.exec(this);
	
	if (match)
	{
		let token = this.substring(0, match.index);		// Text before spaces
		let tail = this.substring(matcher.lastIndex);	// Text after spaces
		
		if (token.length != 0)  return [token, tail];
		else  return tail.getOneToken();	// Handle leading spaces case. This won't recurse more than once.
	}
	else
	{
		// No spaces
		return [this, null];
	}
}



/*
	Replace special characters in string with escape codes, for displaying a
	string literal as a JavaScript literal. (Used in performMacro() to echo
	macro expansion.)
 */
String.prototype.substituteEscapeCodes = function ()
{
	let string = this.replace(/\\/g, "\\\\");	// Convert \ to \\ -- must be first since we’ll be introducing new \s below.
	
	string = string.replace(/\x08/g, "\\b");	// Backspace to \b
	string = string.replace(/\f/g, "\\f");		// Form feed to \f
	string = string.replace(/\n/g, "\\n");		// Newline to \n
	string = string.replace(/\r/g, "\\r");		// Carriage return to \r
	string = string.replace(/\t/g, "\\t");		// Horizontal tab to \t
	string = string.replace(/\v/g, "\\v");		// Vertical ab to \v
	string = string.replace(/\'/g, '\\\'');		// ' to \'
	string = string.replace(/\"/g, "\\\"");		// " to \"

	return string;
}


// ****  Load-time set-up

// Get the global object for easy reference
this.console.global = (function () { return this; } ).call();

// Make console globally visible as debugConsole
this.console.global.debugConsole = this.console;
debugConsole.script = this;

if (debugConsole.settings["macros"])  this.macros = debugConsole.settings["macros"];

// As a convenience, make player, system and missionVariables available to console commands as single-letter variables:
this.P = player;
this.S = system;
this.M = missionVariables;


// Make console.consoleMessage() globally visible
function consoleMessage()
{
	// Call debugConsole.consoleMessage() with console as "this" and all the arguments passed to consoleMessage().
	debugConsole.consoleMessage.apply(debugConsole, arguments);
}


// Also make console.consoleMessage() globally visible as ConsoleMessage() for backwards-compatibility. this will be removed before next stable.
function ConsoleMessage()
{
	debugConsole.consoleMessage("warning", "Warning: ConsoleMessage() is deprecated. Use consoleMessage() instead.", 0, 8);
	debugConsole.consoleMessage.apply(debugConsole, arguments);
}


// Add inspect() method to all entities, to show inspector palette (Mac OS X only; no effect on other platforms).
Entity.__proto__.inspect = function ()
{
	debugConsole.inspectEntity(this);
}
