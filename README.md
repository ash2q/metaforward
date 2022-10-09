# MetaForward

A forth inspired programming langauge designed to fit within a 512 byte boot sector of 16-bit x86 assembly



```
    #comment
    0x100 #push 100 (in hex)
    :new_function
    ~1 #swap to secondary stack
    02 #push 2
    ~0 #swap to primary stack
    "hello world" #create a string in string space. Push pointer of the string to stack
    @hello #store top item in stack to global variable named hello
    p #prints string
    ; #end
    
    `. 0x909090 #create a "keyword" of . which generates assembly code 0x90 (NOP) 3x when used
    `.$ #create keyword of . followed by an identifier, such as .foo or .bar
    `.@ #create keyword of . followed by a number
    `.* #create keyword of . f

```

Keywords work by executing code when encountering a specific character. The only "base" keyword is "`" The syntax being: backtick, address, keyword character (single character), then a string of hex assembly which is executed when that character is encountered as the first character in a line.

If the hex assembly address is 0, then it is added to the next free space in the memory map(?). Otherwise the hex assembly is written to that specific address. Note that this can be used to replace existing keywords. The entire keyword set must exist within a single 64Kb segment. If more than 64kb is required, then it is up to the meta-programmer to load such code into a secondary segment and to then use the hex assembly code to do a far jmp into the secondary segment. Reserved segments are listed in the memory map. 

Operations when a new keyword is created:

* Decode hex code string into raw bytes
* Copy raw bytes into specified address
* Add keyword character into keyword map as the key and the value of the map shall be the address

Execution of keyword:

* setup register and other environment
* call to address listed in keyword map
* execute code for the keyword
* return
* move to next line

Custom keywords are only valid within functions. Outside of functions, the following keywords exist:

* >1234 -- push value 0x1234 onto stack
* @1234 -- push the memory value from 0x1234 onto stack (?)
* !fn -- execute function named fn
* :fn -- begin definition of function named fn
* ?1234:1234 -- print, load, and execute string buffer at address (as if typed into the console)
* '12345678 -- decode specified assembly code into raw bytes, load at specific "assembly address" and execute. Useful for bootstrapping

Default keywords within functions:

* `12345678 -- execute specified hex assembly code
* >1234 -- push specified value to stack
* @1234 -- read from address and push to stack
* *1234 -- pop from stack and write to address
* [1234 -- pop from stack and write the top byte to address
* ]1234 -- pop from stack and write the bottom byte to address
* /02 -- peak 2nd stack item and push it to top of stack (>0 would be top of stack, >1 would be 1 deeper than top of stack)
* n -- trash top item of stack
* # -- reserved for coments, does nothing
* m00 -- "mark" this line of code (adding to a map of marks)
* j00 -- jump to specified marked line of code
* J00 -- push to stack the specified marked line of code's address
* p -- pop top value from stack, and print the bottom byte to screen 
* 'a -- push ascii value of 'a' to the stack, as the bottom byte. Top byte is 0
* 


Restrictions:

* All numbers are hex.
* All numbers must be an even number of digits
* All keywords are one character
* Signed numbers aren't really a thing
* Fixed-size 16-bit stack values


Allowances (if possible): 

* spaces before a keyword will be skipped and ignored, allowing for indentation

TODO:

How to build conditionals?

Maybe keywords just to simply compute the relative address?
Example:
jz00 -- jmp if zero to mark 0

Different idea. Test instructions which push either 1 or 0 to stack
te -- pop top two stack items. Push 1 if equal, push 0 otherwise

Then having an if statement:

? -- executes code until end of scope IFF top of stack is greater than 0.
L --ends scope of IF. If the top of stack was 0 then execute scope below
; --ends scope


Example

```
:test_fn
    >10
    >05
    # duplicate the 10
    /01 
    # duplicate the 5
    /01
    #test if 5 is less than 10
    tl
    #dup
    /00 
    #if trust test (>0)
    ?
        # print correct message
        "correct!
        .print
    ;
    #if false test (==0)
    L
        # print incorrect message
        "incorrect!
        .print
    ;
:

#execute test function
!test_fn 

In order to do a loop:

w -- while top stack item is greater than 0 then loop

```
:test_fn
    # loop 5 times
    >05
    >01
    w
        #dup
        /00 
        #push ASCII code for 0
        '0
        .plus
        #print counter 
        p
        >1
        # subtract counter by 1
        sub
        >0
        #test if equal to 0 
        te
    ;
:
```

## Fixups

During compilation there is a feature known as "fix ups". This allows for code generated by a keyword to be rewritten AFTER the keyword is completed. The most specific use for this is to form "scopes" which can be skipped, such as for the IF keyword

Memory map for fixups:

* current slot (number, not address)
* current scope (number)
* slots[]

Slot Structure:

* code address (what code address to overwrite)
* scope number

Fixups generate `rel16` arguments. Specifically this is computed by `current_code_address - slot.code_address - 1`. Once generated, it is used to overwrite the data at `slot.code_address`

Fixups will be processed while current_scope == slot.scope_number. Once they are not equal, the fixup round is done and current_slow and current_scope are both decremented.

If a fixup is attempted while current_slot is 0, an error will be generated



Segment Memory map:

* 0 - 0xFFFF -- reserved (system use) (note: bootsector loaded at 0x7C00)
* 0x10000 - 0x2FFFF -- compiler code
* 0x20000 - 0x2FFFF -- stack (split between data and call stack. During compilation the data stack is used for "fixups")
* 0x30000 - 0x3FFFF -- Xfunction map
* 0x40000 - 0x4FFFF -- compiled function space
* 0x50000 - 0x5FFFF -- Xfree data space
* 0x60000 - 0x6FFFF -- Xfreestanding code execution space
* 0x70000 - 0x7FFFF -- Xstring construction space (created strings are placed here)
* 0x80000 - 0x8FFFF -- string execution space (lines of code are placed here)
* 0x90000 - 0x9FFFF -- Xkeyword code space
* 0xA0000 - 0xFFFFF -- Reserved (system use)

Stack segment memory layout, segment 0x2000

* 0x8000 -- call stack
* 0xF000 -- data stack

Compiler code layout:

* 0x0000 - 0x0200 -- symbol maps (1 used for keywords, 7 available)
* 0x1000 - 0x1200 -- Initial bootloader code (512 bytes)
* 0x1200 - 0x1400 -- Reserved for bootloader data
* 0x1400 - 0x2000 -- reserved (?)
* 0x2000 - 0xFFFF -- keyword code data

Function code layout:

* 0x0000 - 0x1000 -- reserved
* 0x1000 - 0xFFFF -- function code space

Register Values during meta keyword execution:

* ax, bx, dx -- none (unpreserved)
* mov cx -- length of string to execute
* sp -- call stack
* bp -- same value as sp just before call (sp-2)
* es:si -- string to execute (pointing at keyword)
* ds:di -- target place to write function (preserved, is saved to [cs:next_fn_byte] ?)
* cs -- compiler code section
* fs -- compiler code section

Register Values during function execution:

* ax, cx, dx -- no purpose
* cs -- function section
* fs -- compiler code section
* ds -- stack section
* es -- ?
* bp -- data stack
* di, si -- none


Register layout during function execution (at the point of each keyword code):

* ax, bx, cx, dx -- work registers (unpreserved)
* sp -- data stack
* bp -- call stack (swapped before and after switching functions)
* si, di -- ?
* ds -- free data space (0x5000)
* es -- stack
* gs, fs -- ?
* ss -- stack
* cs -- compiled function space (0x4000)
* FLAGS -- not preserved

Register layout during construction during execution of keywords

* ax, bx, dx -- work registers (unpreserved)
* cx -- length of token (length from keyword to first space or newline)
* sp -- call stack
* si -- string ptr
* di -- compiled function space, current code byte
* bp -- ?
* ds -- compiled function space
* es -- string execution space
* gs, fs -- reserved. fs used for symbol map segment and must not be modified
* cs -- keyword code space
* FLAGS -- not preserved







# Modes

There are two modes for MetaForward

* Meta Mode: In this mode new keywords can be added, functions can be created, and functions can be called. Nothing else is possible
* Construct Mode: In this mode, a function is actively being built and compiled into code. The majority of coding is in this mode.

Construct mode is entered into using `:` keyword, for creation of functions. Construction mode is ended and Meta mode is entered by ending the function scope by using `;`


# Symbol map

Keywords are located at 0x10000. Using a near call would require 2 bytes per entry. Using the lower ASCII map, that would be 128 possible entries, which could actually be easily reduced. 128 * 2 = 512 bytes for the call table. 

All keywords possible are initialized to an "invalid keyword" error handler


# Function Slots

Function slots are basically just a table for where functions exist at. All functions should begin as "0" which causes an error message

The table is located at 0x200 in the compiler segment

Key: value, a 2 byte value up to 0x0700
Value: 2 byte word for function address to call

This allows for a total of up to 1792 number-functions per program
It is expected more "full" versions of the language to define name-functions as a replacement



# Bare keywords

These are the only keywords supported in the bootsector version of MetaForward

* ` -- add new keyword (syntax `x1234 12345678 ; make keyword of x at address 1234, with code listed)
* ~ -- create number function. (syntax ~1234 ; creates a new function, register it to slot 1234)
* ; -- end function (place ret, do various compiler cleanup to prepare for next function)
* x -- begin execution of program, by executing function 1
* $ -- insert call to number function ($1234 ; calls function at slot 1234)
* ' -- insert hex code into current function (syntax '909090 ; inserts 909090 into current function as hex code)
* # -- no-op. functions as comment


