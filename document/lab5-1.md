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

前面需要溢出报错的指令可能需要检测溢出,然后报错

## done

单纯地给例外增加了信号,和给CAUSE寄存器赋值,具体的细节未实现

## problem

./convert
make[1]: execvp: ./convert: 权限不够
Makefile:16: recipe for target 'compile' failed
make[1]: *** [compile] Error 127
make[1]: Leaving directory '/home/lin/loongson/lab/lab5/lab5-1/lab5_func_1'
Makefile:13: recipe for target 'all' failed
make: *** [all] Error 2
解决方法:把convert.exe文件属性中允许作为程序执行文件勾上
===============

**没有说明断点例外的优先级**
**如何检测到中断**

## thinking

- 考虑中断在该指令的WB阶段才报异常,保证前面的指令能过执行完
- 执行完前面的指令,清空中断后面的流水线来执行中断处理程序
- 需要有eret?来保存处理完中断以后重新执行原来的流水的起始地址,也就是保存中断指令的下一条指令的地址(不知道中断的指令是否需要重新执行一遍)
- 需要重新检查哪些指令需要检查异常,然后传递信号给WB阶段
- **注意中断的优先级,体现在CAUSE寄存器赋值的时候先判断优先级高的中断**
- **出错的时候考虑检测是否是bus位数不对**
- **取指错误(地址错误,保留指令)可能需要立马中断,也可能不需要**

## tips

>例外优先级
中断
地址错例外—取指
保留指令例外
整型溢出例外、陷阱例外、系统调用例外
地址错例外—数据访问

- 所有例外(含中断)的例外入口地址统一为 0xBFC0.0380
- 也需要考虑取指令的地址是否异常
- 当地址错误例外的时候需要用BadVAddr寄存器记录触发例外的虚地址(未实现)

## debug

实现所有异常检测以后

```c
--------------------------------------------------------------
[3351665 ns] Error!!!
    reference: PC = 0xbfc003b8, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00400002
    mycpu    : PC = 0xbfc003b8, wb_rf_wnum = 0x1a, wb_rf_wdata = 0x00000002
--------------------------------------------------------------
```