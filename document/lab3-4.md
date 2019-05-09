# 5.8-

## todo

至少新增如下指令:LH、LHU、LWL、LWR、SH、SWL、SWR
需要修改mem_control信号 控制读写的位数

## done

- 源码实现LB、LBU、SB、

## problem

## thinking

## tips

## debug

未做任何修改

```c
--------------------------------------------------------------
[2978675 ns] Error!!!
    reference: PC = 0xbfc4cde0, wb_rf_wnum = 0x02, wb_rf_wdata = 0x00002560
    mycpu    : PC = 0xbfc4cde4, wb_rf_wnum = 0x05, wb_rf_wdata = 0x80022bc8
--------------------------------------------------------------
```