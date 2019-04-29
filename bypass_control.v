`timescale 1ns / 1ps
//*************************************************************************
//   > 文件  : bypass_control.v
//   > 描述  : 五级流水CPU的旁路控制模块
//   > 日期  : 2019-04-08
//*************************************************************************
module bypass_control(
    input   [4:0] rs,          
    input   [4:0] rt,                  
    input   [4:0] EXE_wdest,
    input   [4:0] MEM_wdest,
    input         EXE_rf_wen,
    input         MEM_rf_wen,

    //旁路数据的去向
    output  forwardA,
    output  forwardB
);   
    //!!!!需要检测发生冒险的情况是否真的需要写回
    //也就是检测处于EXE，MEM阶段的rf_wen信号是否有效
    wire EXE_hazard;
    wire MEM_hazard;
    assign EXE_hazard = (rs==EXE_wdest) | (rt==EXE_wdest);
    assign MEM_hazard = (rs==MEM_wdest) | (rt==MEM_wdest);
    //可能有误
    assign forwardA   = !EXE_rf_wen ? 0 : 
                        EXE_hazard ? 1 : 0;
    assign forwardB   = !MEM_rf_wen ? 0 : 
                        MEM_hazard ? 1 : 0;
endmodule