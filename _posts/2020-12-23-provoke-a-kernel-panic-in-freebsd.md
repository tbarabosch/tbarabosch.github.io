---
id: 62
title: 'Provoke a kernel panic in FreeBSD'
date: '2020-12-23T11:52:54+00:00'
author: tbarabosch
layout: post
feature_image: /wp-content/uploads/2021/01/red_panic-1200x800.jpg
---

Throughout the last year’s I found numerous [(security) bugs](https://freshbsd.org/search?q=Barabosch&sort=commit_date) in the BSDs (*FreeBSD*, *OpenBSD*, *NetBSD*). I had a great time researching those kernels. The community is very technically sophisticated and very supportive. Not to forget the great read [“The Design and Implementation of the FreeBSD® Operating System”](https://www.oreilly.com/library/view/the-design-and/9780133761825/) that accompanied my adventures over there. I can recommend this book to everyone working in system security!

<!--more-->

If you dive into BSD research you will probably encounter a point where you will need to write some kernel code. Patching the kernel directly is a great way to do this and there are many great guides out there on how to patch and compile a BSD kernel. Another way is to write kernel modules and to dynamically load them into the kernel space.

I encountered the use case where I had to deliberately crash the operating system. So I wrote a small kernel module to provoke a kernel panic. This module tries to write to offset `0x0` of the address space. Since this is forbidden to counter the exploitation of NULL pointers, this will immediately crash the operating system. The full source code and a simple make file [can be found at github](https://gist.github.com/tbarabosch/bb25c3497bec2413724b010a360e82a3).

```c
#include <sys/param.h>               
#include <sys/module.h>              
#include <sys/kernel.h>           
#include <sys/systm.h>       
                         
static int       
panic_modevent(module_t mod __unused, int event, void* arg __unused){            
        int error = 0;       
      
        switch(event){           
            case MOD_LOAD:       
                uprintf("Goodbye!\n");       
                memset(NULL, 0x42, 1000);       
                break;       
            default:       
                error = EOPNOTSUPP;       
                break;       
        }       
  
        return (error);       
}       
                       
static moduledata_t panic_mod = {           
        "panic",           
        panic_modevent,         
        NULL            
};       
                     
DECLARE_MODULE(panic, panic_mod, SI_SUB_DRIVERS, SI_ORDER_MIDDLE);
```
