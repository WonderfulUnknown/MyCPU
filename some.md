# 4.18-4.25

## todo

- 完成lab3-2
- 修改接口，总线

## done

- 控制单元
- cpu对byclass_control给出的信号进行处理
- 所有旁路相关的信号,总线

## problem

```verilog
   //对于分支跳转指令，只有在IF执行完成后，才可以算ID完成；
    //否则，ID级先完成了，而IF还在取指令，则next_pc不能锁存到PC里去，
    //那么等IF完成，next_pc能锁存到PC里去时，jbr_bus上的数据已变成无效，
    //导致分支跳转失败
    //(~inst_jbr | IF_over)即是(~inst_jbr | (inst_jbr & IF_over))
    assign ID_over = ID_valid & ~rs_wait & ~rt_wait & (~inst_jbr | IF_over);
```

```c
[1187235 ns] Error!!!
    reference: PC = 0xbfc0b530, wb_rf_wnum = 0x0a, wb_rf_wdata = 0x80020010
    mycpu    : PC = 0xbfc0b530, wb_rf_wnum = 0x0a, wb_rf_wdata = 0x80025020
```

>没加旁路时候错误的位置,加了旁路全部崩盘
>修改了旁路一直死循环0xbfc00004
![死循环时的波形图](/picture/cycle.png)

- **是否真的是因为数据相关导致未能通过检测**
- 可能需要区分是在EXE写回还是在MEM写回
- 未验证溢出信号

>
- 非R型指令的时候也可能会给旁路使能的信号,此时exe_result或mem_result为xxxx
需要加上R型指令控制信号

## thinking

- 需要在ID阶段检测是否存在数据相关
- 检测到数据相关传递信号给专门的控制单元
- 源代码在ID阶段判断过rs_wait和rt_wait，是直接使用还是bypass_control中再判断，是否影响性能。
- bypass中的简单判断是否会出错
- 考虑给旁路什么数据,以及ALU接受以后是给rs还是rt
- ID检测到冲突以后应该下一个周期才把旁路的数据交给ALU
（将ID阶段的rs_wait,rt_wait通过总线传给EXE）
- **注意总线位数的一致**

## tips

- **需要在cpu.v中检测处于EXE，MEM阶段是否需要写回，也就是去检测rf_wen**
- 模仿计组书上实现
- **使用 ？ ： 不用if_else**
- !需要支持语法的插件
- 接口位数不对不会报错,但是会在波形图中显示XXXX