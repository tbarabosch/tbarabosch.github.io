---
title: 'How to write and load shellcode on macOS'
date: '2020-12-22T09:58:07+00:00'
author: tbarabosch
layout: post
feature_image: /wp-content/uploads/2020/12/shell_beach-1200x800.jpg
categories:
    - 'OS Internals'
tags:
    - macOS
    - radare2
    - shellcode
    - 'x64 assembly'
---

Learning by doing always works quite well. Getting to know the low-level programming tool chain is a vital for understanding the low-level details of the OS in general. So I thought writing some shellcode in x64 assembly and loading it with a simple loader written in C would be a good starting point for becoming acquainted with the basic programming tools on macOS. Just to name a few: IDE (*Xcode*), Compiler (*llvm/clang*) and (dis)assembler (*radare2*). Also, this would be the first encounter with the development documentation provided by Apple.

This blog post shows you how to write and load shellcode on macOS. It seems that there is not that much on x64 assembly on the Internet. Sometimes it can be a little bit tricky when coming from x86 assembly. However, the easiest way is just throwing a binary in a disassembler and see how the compiler translated the code.

<!--more-->

## The Loader

The loader is quite simple, no rocket science at all. Have a quick look at [the code](https://github.com/tbarabosch/MacRE/blob/master/x64-shellcode-loader/main.c)!

First, it loads a file containing the shellcode to memory. Then, it places some code after the shellcode that directs the control flow back to the loader.  
More precisely, a function that cleans up everything and gracefully exits the loader. The next listing shows how to place a *mov rax, VALUE; call rax* sequence after the shellcode.

```c
const char* MOV_RAX = "\x48\xb8";
const char* CALL_RAX = "\xff\xD0";
 
void writeTrampoline(long file_size){
     void (<em>p)(void) = exitGracefully;     </em>
     <em>printf("Writing trampoline to clean up function @%p after shellcode\n", p);     </em>
     <em>memcpy((shellcode_buffer+file_size), MOV_RAX, 2);     </em>
     <em>memcpy((shellcode_buffer+file_size+2), &p, sizeof(void</em>));
     memcpy((shellcode_buffer+file_size+2+sizeof(void*)), CALL_RAX, 2);
}
```

Note that this might not always be possible, e.g. in case the shellcode just calls the exit syscall. Care has to be taken with memory permissions.  
If you allocate memory with malloc then this memory has Read-Write permissions. Therefore, the loader requests memory with *mmap (PROT\_READ|PROT\_WRITE)* and then sets the permissions with *mprotect (PROT\_READ|PROT\_EXEC)*. After having loaded the code to memory, the loader calls the code. It just casts the pointer that points to the shellcode to a function *((void(*)())\*.

## The shellcode

So far, I have analyzed x86 and x64 and I have also written x86 assembly. But this time is the first time that I write x64 assembly. A quick and painless introduction to writing x64 assembly on macOS [here](http://www.idryman.org/blog/2014/12/02/writing-64-bit-assembly-on-mac-os-x/). I prepared two payloads. The first just exits the process immediately. Let’s have a look at the code snippet:

```c
xor %rbx, %rbx
movl $0x2000001, %eax           # exit 0
syscall
```

For exiting immediately, it uses the *exit* syscall. On x64, syscalls are initiated with the [corresponding keyword](https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man2/syscall.2.html).  
The C function takes the syscall number as first argument. The other (n-1) arguments depend on the actual syscall.  
Since the above program is written in assembly, we pass the arguments in the registers. *rax* takes the syscall number, only some registers can be used for passing arguments (e.g. *rdi* or *rsi*).

For more information on the syscall calling conventions refer to [this document](http://people.freebsd.org/~obrien/amd64-elf-abi.pdf) (Chapter A.2.1). Back to the example, first we set *rbx* to zero (result of the *exit* syscall) and we move the value *0x2000001* (*exit* being the [first syscall](http://www.opensource.apple.com/source/xnu/xnu-1504.3.12/bsd/kern/syscalls.master)) to *rax*. And finally, we call into the kernel with syscall. The second payload prints “hello world” to *STDOUT*. Let’s have a look at the code:

```c
xor %rbx, %rbx                 # push the zero terminating C string to the stack
pushq %rbx
movq $0x0a21646c72, %rax
pushq %rax
movq $0x6f77206f6c6c6548, %rax
pushq %rax
movl $0x2000004, %eax           # 4 == write syscall
movl $1, %edi                   # 1 == STDOUT file descriptor
leaq (%rsp), %rsi               # string to print
movq $14, %rdx                  # size of string
syscall
```

At first glance, it looks much more complicated than the first payload. However, there are basically just two things happening.  
First, we push the string “hello world” as zero terminating string to the stack. This is one way to be position-independent.

Note that we don’t know where our payload might get executed.  
Second, we prepare the *write* syscall, which takes a file descriptor (in our case *STDOUT*), a pointer to a string and the string size.

## Putting it all together

Well, we have seen the two components: the loader and the payloads.  
For implementing it, I had to toy around with *Xcode*, *llvm/clang*, *as*, *lldb* and *radare2* just to name the most important tools.

Let’s execute the loader with the two payloads. First, let’s execute it with the exit payload:

```bash
$ ./loader shellcodes/exit.bin
 Opening shellcodes/exit.bin
 Trying to read 9 bytes.
 Hexdump of shellcode:
 1b8db311b8db1b82000001f02000050f020050f0250f5
 Writing trampoline to clean up function @0x1011ee9f0 after shellcode
 Changing protection to RX.
 Loaded shell code to 0x1423000. Calling in…
```

But did it really work? Well, we can’t tell from this output. So we’ve to look into the inside of our process. There are a couple of tools for this job. We could check if everything works by using *dtrace* and truss. A valuable source for quickly writing *dtrace* one-liners is [Brendan Gregg’s blog](http://www.brendangregg.com/DTrace/dtrace_oneliners.txt).

Ok, let’s execute our loader one more time but this time in conjunction with *dtrace*:

```
$ ./loader shellcodes/helloworld.bin
 Opening shellcodes/helloworld.bin
 Trying to read 49 bytes.
 Hexdump of shellcode:
 53db31484853db31b84853db72b848536c72b848646c72b821646c72a21646 [...]
 Writing trampoline to clean up function @0x109abf9f0 after shellcode
 Changing protection to RX.
 Loaded shell code to 0x9cf4000. Calling in…
 Hello world!
 Executed shellcode successfully
 Freed shellcode buffer. Exiting.
```

This time the shellcode did not exit the loader. Therefore, our trampoline directed the control flow to the clean up function that successfully freed the buffer and exited the loader. The code is hosted as usual on [github](https://github.com/tbarabosch/MacRE/tree/master/x64-shellcode-loader).

BTW, there are more elegant and faster ways than writing your shellcode in assembly. Tools like *rang2-cc* (part of the *radare2* reversing framework) [generate shellcode from C programs](http://radare.today/posts/payloads-in-c/). However, for educational purposes, it is advisable to do at least just once.
