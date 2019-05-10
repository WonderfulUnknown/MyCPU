# 5.8-

## todo

-至少新增如下指令:LWL、LWR、SWL、SWR
-需要修改mem_control信号 控制读写的位数
-**需要考虑LH等地址是否对齐**

## done

- 源码实现LB、LBU、SB、LH、LHU、SH

## problem

```c
    assign load_result[15:8 ] = (ls_word[1:0]==1'd2 && dm_addr[1]==1'b1)   ? dm_rdata[31:24] :
                                (ls_word[1:0]==1'd2 && dm_addr[1]==1'b0)   ? dm_rdata[15:8 ] : (ls_word[0]==1'b1) ? dm_rdata[15:8 ] : {8 {l_sign & load_sign}};
    assign load_result[15:8 ] = (ls_word[1:0]==2'b10 && dm_addr[1]==1'b1)   ? dm_rdata[31:24] :
                                (ls_word[1:0]==2'b10 && dm_addr[1]==1'b0)   ? dm_rdata[15:8 ] : (ls_word[0]==1'b1) ? dm_rdata[15:8 ] : {8 {l_sign & load_sign}};
```

在ls_word=00的时候,第一种result[15:8]=dm_rdata[15:8],第二种result[15:8]= {8 {l_sign & load_sign}};
**!1'd2代表的是后面跟的是16进制数但是取1位,取到的值希望是2,但实际是0**

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
检查发现是前面的sw出错误

改变load_result[15:8]

```c
--------------------------------------------------------------
[2862145 ns] Error!!!
    reference: PC = 0xbfc45440, wb_rf_wnum = 0x02, wb_rf_wdata = 0xffffffb6
    mycpu    : PC = 0xbfc45440, wb_rf_wnum = 0x02, wb_rf_wdata = 0x000000b6
--------------------------------------------------------------
```

未写LWL、LWR、SWL、SWR

```c
-------------------------------------------------------------- 
[3075085 ns] Error!!!
    reference: PC = 0xbfc0a448, wb_rf_wnum = 0x02, wb_rf_wdata = 0xe8d3ee80  
    mycpu    : PC = 0xbfc0a448, wb_rf_wnum = 0x02, wb_rf_wdata = 0x000000e8  
---------------------------------------------------------------------
```