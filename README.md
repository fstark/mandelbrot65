# An 6502 assembly Mandelbrot drawing for the Apple1

The title says it all. This is the fastest Mandelbrot calculator for the Apple1. At minimum zoom, it computes the Mandelbrot 3 times faster than the Apple1 can display it.

![Mandelbrot 65](images/Mandelbrot1.jpg)

# How do I get it?

This demo as been designed for Aberco/SiliconInsider yet-to-be-released Apple1 ROM card.

If you want to use the demo standalone, use either the binary file [mandelbrot65.o65](mandelbrot65.o65) or the [hex file](mandelbrot65.hex).

You can also copy/paste the hex file on an [Apple1 emulator](https://www.scullinsteel.com/apple1/) (Reset key+Load button+copy/paste hex (with a CR at the end)+wait text stops scrolling+``280R``)

# How do I run it?

The demo is made to be loaded at address 0x0280 and run with a ``280R`` (or launched from the menu of the Apple1 1 ROM card).

You will need 8K of RAM between 0000-1FFF to run it.

The demo will wait for a key press (to initialize its internal random number generator) then draw a Mandelbrot set and perform a series of 4 level of zooms.

At any time, you can press a key to skip the initial messages or the mandelbrot displays.

# The hidden CRC checker

Since version 1.1, there is a hidden CRC checker, usefull when the loaded binary doesn't fully work
Using 283R, you will be presented with two CRC numbers, like:
```
1)0280-0594:C1
2)0594-08A9:3A
```
Do the same on two machines, one known good (use an emulator, like https://www.scullinsteel.com/apple1/ , copy/pasting the ```.hex`` file)
Press ``1`` or ``2`` depending on which CRC differs.
It will then present 2 CRCs for this memory range:
```
1)0280-040A:35
2)040A-0594:8A
```
Repeat until the range is one byte. This should help you identify which part of Mandelbrot65 failed to load.

# How do I build it?

Use the ``xa`` assembler and the top level Makefile.

``make`` will make the binary and the hex file.
``make mandelbrot.o65`` will make the binary only.
``make clean`` to remove binaries and compilation artificats.

The content of ``others`` directory contains a C++ program that was used to validate during the development. It is trash undocumented code (but has been very helpful).

# Why did you do this?

We wanted to include a Mandelbrot demo on the ROM card, but the existing demos were using AppleSoft Basic, which will not be present on the default 32K version of the card. I wasn't able to find a good version of Mandelbrot, so decided to write one.

See the blog post on http://stark.fr/blog/mandelbrot65 for additional details.
