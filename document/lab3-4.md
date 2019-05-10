# 5.8-

## todo

-至少新增如下指令:LWL、LWR、SWL、SWR
-需要修改mem_control信号 控制读写的位数
-**需要考虑LH等地址是否对齐**

## done

- 源码实现LB、LBU、SB、LH、LHU、SH

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

实现了所有指令,但有误

```c
--------------------------------------------------------------
[ 237745 ns] Error!!!
    reference: PC = 0xbfc43b44, wb_rf_wnum = 0x02, wb_rf_wdata = 0xc822c7e8
    mycpu    : PC = 0xbfc43b44, wb_rf_wnum = 0x02, wb_rf_wdata = 0xc8220000
--------------------------------------------------------------
```

lw错误,dm_rdata和result一样