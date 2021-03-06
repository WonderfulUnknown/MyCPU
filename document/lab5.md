# 5.15-

## todo

**实现检测保留指令以及如何检测中断**
(1) CPU 增加 MTC0、MFC0、ERET 指令。
(2) CPU 增加 CP0 寄存器 STATUS、CAUSE、EPC。
(3) CPU 增加 SYSCALL 指令,也就是增加 syscall 例外支持。
(4) 运行功能测试通过。功能测试程序为 lab5_func_1,是在 lab3_func_4 的基础上增加第 69 个功能点测试,也就是 SYSCALL 例外测试

(1) CPU 增加 BREAK 指令,也就是增加 break 例外支持,。
(2) CPU 增加地址错、整数溢出、保留指令例外支持。
(3) CPU 增加 CP0 寄存器 COUNT、COMPARE。
(4) CPU 增加时钟中断支持,时钟中断要求固定绑定在硬件中断 5 号上,也就是CAUSE 对应的 IP7 上。
(5) CPU 增加 6 个硬件中断支持,编号为 0~5,对应 CAUSE 的 IP7~IP2。
(6) CPU 增加 2 个软件中断支持,对应 CAUSE 的 IP1~IP0。
(7) 完成 lab5_fun_2 功能测试。
(8) 在 myCPU 上运行 lab4 的电子表程序,要求能实现相同功能。
(9) 在 myCPU 上运行记忆游戏程序,要求能正确运行。

## done

pass test73

## problem

>./convert
make[1]: execvp: ./convert: 权限不够
Makefile:16: recipe for target 'compile' failed
make[1]: *** [compile] Error 127
make[1]: Leaving directory '/home/lin/loongson/lab/lab5/lab5-1/lab5_func_1'
Makefile:13: recipe for target 'all' failed
make: *** [all] Error 2
解决方法:把convert.exe文件属性中允许作为程序执行文件勾上
===============

- 没有说明断点例外的优先级
- **如何检测到中断**
- 不太理解IF_allow_in IF_vaild IF_over等

## thinking

- 考虑中断在该指令的WB阶段才报异常,保证前面的指令能过执行完
- **执行完前面的指令,清空中断后面的流水线来执行中断处理程序(实际上只要保证后面的指令不会写sram和寄存器就可以,发生异常后的写使能为0即可)(未处理)**
- 需要有eret?来保存处理完中断以后重新执行原来的流水的起始地址,也就是保存中断指令的下一条指令的地址(不知道中断的指令是否需要重新执行一遍)
- inst_R信号可能会有误,把很多不是的也归为inst_R(但是应该不影响结果,就算打开旁路给出数据,但是没有使用,只是可能会影响性能)
- 在WB阶段处理异常指令,此时下一个周期才会取到异常的地址,因此中间会有4条指令不应该被执行,需要用信号将这4条指令的写使能清零,需要注意的是**在WB阶段处理异常指令的时候,MEM阶段可能已经在处理后一条指令,而此时IF阶段的指令还不确定写使能**
- 计组的代码通过延迟进入的时间,使得不应该被执行的指令被忽略

## tips

>例外优先级
中断
地址错例外—取指
保留指令例外
整型溢出例外、陷阱例外、系统调用例外
地址错例外—数据访

- 只能注释前68个功能测试点
- 假设在wb阶段将exc_happened信号传出能够及时使得上一阶段的MEM_en清空(否则需要单独考虑异常指令的下一条指令为sw指令的情况),同时使用cancel指令传给CPU使得前面指令的写使能都清空.
- 考虑把是分支跳转指令的信号传给cpu,用reg存储,然后下个周期传给ID,使得is_delay_slot信号为1,然后通过bus向后传递(也可以传给CPU,然后CPU传给IF阶段,然后通过bus把信号传递下来给is_delay_slot)
- 使用if (!resetn)来初始化

## debug

实现所有异常检测以后

```c
--------------------------------------------------------------
[3351665 ns] Error!!!
    reference: PC = 0xbfc003b8, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00400002
    mycpu    : PC = 0xbfc003b8, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000002
--------------------------------------------------------------
```

注释前面通过的测试点

```c
--------------------------------------------------------------
[   2725 ns] Error!!!
    reference: PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000000
    mycpu    : PC = 0xbfc04934, wb_rf_wnum = 0x09, wb_rf_wdata = 0x01000000
--------------------------------------------------------------
```

跑lab5-2

```c
--------------------------------------------------------------
[   2725 ns] Error!!!
    reference: PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000000
    mycpu    : PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xxxxxxxxx
--------------------------------------------------------------
```

补上前面mul等指令

```c
--------------------------------------------------------------
[ 770615 ns] Error!!!
    reference: PC = 0xbfc749c4, wb_rf_wnum = 0x17, wb_rf_wdata = 0x8001fff0
    mycpu    : PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xxxxxxxxx
--------------------------------------------------------------
```

解决overflow判断

```c
--------------------------------------------------------------
[3361005 ns] Error!!!
    reference: PC = 0xbfc00438, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xbfc859ac
    mycpu    : PC = 0xbfc00438, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x80000000
--------------------------------------------------------------
```

syscall->exc_happend

```c
--------------------------------------------------------------
[3370665 ns] Error!!!
    reference: PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00010000
    mycpu    : PC = 0xbfc32c8c, wb_rf_wnum = 0x02, wb_rf_wdata = 0x64c76d7c
--------------------------------------------------------------
```

使发生异常的指令不写回后(73 pass) n74_lw_adel_ex_test

```c
--------------------------------------------------------------
[3407175 ns] Error!!!
    reference: PC = 0xbfc6a5c0, wb_rf_wnum = 0x16, wb_rf_wdata = 0x8001fde1
    mycpu    : PC = 0xbfc6a5c0, wb_rf_wnum = 0x16, wb_rf_wdata = 0x00000000
--------------------------------------------------------------
```

用dm_addr给BadVAddr寄存器赋值

```c
--------------------------------------------------------------
[3407755 ns] Error!!!
    reference: PC = 0xbfc0038c, wb_rf_wnum = 0x1b, wb_rf_wdata = 0x00000004
    mycpu    : PC = 0xbfc0038c, wb_rf_wnum = 0x1b, wb_rf_wdata = 0xbfc6a608
--------------------------------------------------------------
```

保证了发出cancel信号的时候不会写sram(感觉后面几个周期应该都不能写sram和寄存器,一直到bfc03800被写回之前)

```c
--------------------------------------------------------------
[3417555 ns] Error!!!
    reference: PC = 0xbfc004bc, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xbfc6a808
    mycpu    : PC = 0xbfc004bc, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x80000000
--------------------------------------------------------------
```

使用暴力清空流水线的方式,在检测到cancel信号后,把五级流水段间寄存器全部清为0

```c
--------------------------------------------------------------
[3475685 ns] Error!!!
    reference: PC = 0xbfc28db0, wb_rf_wnum = 0x16, wb_rf_wdata = 0xb27f9789
    mycpu    : PC = 0xbfc28db0, wb_rf_wnum = 0x16, wb_rf_wdata = 0x00000000
--------------------------------------------------------------
```

修改badvaddr_r,test80 pass,死循环

```c
[3502000 ns] Test is running, debug_wb_pc = 0xbfc17fb8
        [3512000 ns] Test is running, debug_wb_pc = 0xbfc17fb8
        [3522000 ns] Test is running, debug_wb_pc = 0xbfc17fb8
        [3532000 ns] Test is running, debug_wb_pc = 0xbfc17fb8
```

支持时钟中断

```c
--------------------------------------------------------------
[ 439309 ns] Error!!!
    reference: PC = 0xbfc00384, wb_rf_wnum = 0x1b, wb_rf_wdata = 0x00000000
    mycpu    : PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00038000
--------------------------------------------------------------
```

使得时钟中断信号只维持一个周期

```c
--------------------------------------------------------------
[ 440119 ns] Error!!!
    reference: PC = 0xbfc005d0, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xbfc17fb8
    mycpu    : PC = 0xbfc005d0, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x80000000
--------------------------------------------------------------
```

发生中断的时候也会给cp0r_epc赋值
(可能是延迟槽指令,需要回退到上一条指令)

```c
--------------------------------------------------------------
[  21468 ns] Error!!!
    reference: PC = 0xbfc005d0, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xbfc011f8
    mycpu    : PC = 0xbfc005d0, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xbfc011fc
--------------------------------------------------------------
```

完成延迟槽指令的识别,仍有错误

```c
--------------------------------------------------------------
[  18880 ns] Error!!!
    reference: PC = 0xbfc00544, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xb27f97ab
    mycpu    : PC = 0xbfc00544, wb_rf_wnum = 0x1a, wb_rf_wdata = 0xb27f97a7
--------------------------------------------------------------
```

提高cancel清除流水线的优先级,使得dealy_slot信号能够被正确清除

```c
--------------------------------------------------------------
[  21504 ns] Error!!!
    reference: PC = 0xbfc00604, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000000
    mycpu    : PC = 0xbfc00604, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000028
--------------------------------------------------------------
```

晚一拍才发出时钟中断,死循环

```c
[  22000 ns] Test is running, debug_wb_pc = 0xbfc011fc
```

使用reg存储int_happen信号,test12 pass

```c
--------------------------------------------------------------
[  20658 ns] Error!!!
    reference: PC = 0xbfc00384, wb_rf_wnum = 0x1b, wb_rf_wdata = 0x00000000
    mycpu    : PC = 0xbfc00380, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00038000
--------------------------------------------------------------
```

将int_happen恢复为0,nop前的mtc0不应该检测到中断,发生异常时将jbr_taken清空
一开始给compare赋值的时候,如果正好和count相等,不应该触发中断
死循环

```c
[  22000 ns] Test is running, debug_wb_pc = 0xbfc011fc
```

因为int_happen开启的时候导致statu_r[1] <= 1'b1,屏蔽了中断,所以导致后续时钟中断信号无法持续为1,需要改为在中断响应的请求发出去以后才关闭中断,避免因为WB_vaild导致中断信号无法发出,然后关闭了中断响应(注意很多信号需要在WB_valid有效的时候执行)

```c
--------------------------------------------------------------
[  21519 ns] Error!!!
    reference: PC = 0xbfc00614, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x0040ff03
    mycpu    : PC = 0xbfc00614, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x0040ff02
--------------------------------------------------------------
```

发生中断和例外的时候不对status_r[0]位进行修改(可能确实只是在编程的时候被修改)
pass test93

```c
--------------------------------------------------------------
[  69973 ns] Error!!!
    reference: PC = 0xbfc00100, wb_rf_wnum = 0x08, wb_rf_wdata = 0x00000002
    mycpu    : PC = 0xbfc00100, wb_rf_wnum = 0x08, wb_rf_wdata = 0x00000003
--------------------------------------------------------------
```

最后没跳出test_finish的beq死循环,将clk_pll的频率降低即可通过测试
cpu_clk和time_clk设为400MHz出错,设为200MHz不会出错
