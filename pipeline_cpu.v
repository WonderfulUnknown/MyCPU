`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: pipeline_cpu.v
//   > 描述  :五级流水CPU模块，共实现XX条指令
//   >        指令rom和数据ram均实例化xilinx IP得到，为同步读写
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
//module pipeline_cpu(  // 多周期cpu
module mycpu_top(
    input clk,           // 时钟
    input resetn,        // 复位信号，低电平有效
    
    //display data
    input  [ 4:0] rf_addr,
    //input  [31:0] mem_addr,
    output [31:0] rf_data,
    // output [31:0] mem_data,
    output [31:0] IF_pc,
    output [31:0] IF_inst,
    output [31:0] ID_pc,
    output [31:0] EXE_pc,
    output [31:0] MEM_pc,
    output [31:0] WB_pc,
    
    //5级流水新增
    output [31:0] cpu_5_valid,
    output [31:0] HI_data,
    output [31:0] LO_data,

    //the signal for soc_lite_top.v
    input        inst_sram_en,
    // input [3 :0] inst_sram_wen,
    input [31:0] inst_sram_addr,
    // input [31:0] inst_sram_wdata,
    input [31:0] inst_sram_rdata,

    input        data_sram_en,
    input [3 :0] data_sram_wen,
    input [31:0] data_sram_addr,
    input [31:0] data_sram_wdata,
    input [31:0] data_sram_rdata,

    //debug
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
    );
//------------------------{5级流水控制信号}begin-------------------------//
    //5模块的valid信号
    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5模块执行完成信号,来自各模块的输出
    wire IF_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;
    //5模块允许下一级指令进入
    wire IF_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    // syscall和eret到达写回级时会发出cancel信号，
    wire cancel;    // 取消已经取出的正在其他流水级执行的指令
    
    //各级允许进入信号:本级无效，或本级执行完成且下级允许进入
    assign IF_allow_in  = (IF_over & ID_allow_in) | cancel;
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid，在复位后，一直有效
   always @(posedge clk)
    begin
        if (!resetn)
        begin
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end
    
    //ID_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            ID_valid <= 1'b0;
        end
        else if (ID_allow_in)
        begin
            ID_valid <= IF_over;
        end
    end
    
    //EXE_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            EXE_valid <= 1'b0;
        end
        else if (EXE_allow_in)
        begin
            EXE_valid <= ID_over;
        end
    end
    
    //MEM_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in)
        begin
            MEM_valid <= EXE_over;
        end
    end
    
    //WB_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            WB_valid <= 1'b0;
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;
        end
    end

    //inst_sram && data_sram信号 
    assign inst_sram_en = {IF_valid};
    assign data_sram_en = {MEM_valid};

    //展示5级的valid信号
    assign cpu_5_valid = {12'd0         ,{4{IF_valid }},{4{ID_valid}},
                         {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
//-------------------------{5级流水控制信号}end--------------------------//

//--------------------------{5级间的总线}begin---------------------------//
    wire [ 65:0] IF_ID_bus;   // IF->ID级总线
    wire [181:0] ID_EXE_bus;  // ID->EXE级总线
    wire [162:0] EXE_MEM_bus; // EXE->MEM级总线
    wire [156:0] MEM_WB_bus;  // MEM->WB级总线
    
    //锁存以上总线信号
    reg [ 65:0] IF_ID_bus_r;
    reg [181:0] ID_EXE_bus_r;
    reg [162:0] EXE_MEM_bus_r;
    reg [156:0] MEM_WB_bus_r;
    
    //!修改总线的时候记得修改清空流水线的位数
    //*为了debug方便没有清空pc
    //IF到ID的锁存信号
    always @(posedge clk)
    begin
        if (cancel)
        begin 
            IF_ID_bus_r[65:32] <= 24'd0;
            IF_ID_bus_r[31:0 ] <= IF_ID_bus[31:0];
        end
        else if (IF_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID到EXE的锁存信号
    always @(posedge clk)
    begin
        if (cancel)
        begin 
            ID_EXE_bus_r[181:32] <= 150'b0;
            ID_EXE_bus_r[ 31:0 ] <= ID_EXE_bus[31:0];
        end
        else if (ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE到MEM的锁存信号
    always @(posedge clk)
    begin
        if (cancel)
        begin 
            EXE_MEM_bus_r[162:32] <= 131'd0;
            EXE_MEM_bus_r[ 31:0 ] <= EXE_MEM_bus[31:0];
        end
        else if (EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM到WB的锁存信号
    always @(posedge clk)
    begin
        if (cancel)
        begin 
            MEM_WB_bus_r[156:32] <= 125'b0;
            MEM_WB_bus_r[ 31:0 ] <= MEM_WB_bus[31:0];
        end
        else if (MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
    // always @(posedge clk)
    // begin
    //     if (!resetn)
    //     begin
    //         MEM_WB_bus_r <= 161'd0;
    //     end
    //     else if (MEM_over && WB_allow_in)
    //     begin
    //         MEM_WB_bus_r <= MEM_WB_bus;
    //     end
    // end

//---------------------------{5级间的总线}end----------------------------//

//--------------------------{其他交互信号}begin--------------------------//
    wire [32:0] jbr_bus;    //跳转总线
    wire [ 4:0] WB_wdest;

    wire delay_slot;
    wire inst_jbr;
    assign delay_slot = inst_jbr;

    //MEM与data_ram交互    
    wire [ 3:0] dm_wen;
    assign data_sram_wen = dm_wen & {4{~cancel}};

    //ID与regfile交互
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB与regfile交互
    wire [ 3:0] rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;    
    
    //WB与IF间的交互信号
    wire [32:0] exc_bus;
//---------------------------{其他交互信号}end---------------------------//

//--------------------------{旁路信号}begin--------------------------//
    wire       EXE_rf_wen;
    wire       MEM_rf_wen;
    wire [4:0] EXE_wdest;
    wire [4:0] MEM_wdest;
    wire         forwardA;
    wire         forwardB;
    wire         rs_wait;
    wire         rt_wait;

    //某些特殊指令需要
    wire        id_need_rs;
    wire        id_need_rt;
    wire [31:0] to_id_rs;
    wire [31:0] to_id_rt;

    //旁路数据通道
    wire [31:0] to_alu;
    wire [31:0] exe_result;
    wire [31:0] mem_result;

    //应该在下一个周期才把数据给出
    assign to_alu     = forwardA ? exe_result : 
                        forwardB ? mem_result : 32'h0000;

    assign to_id_rs   = !(id_need_rs & rs_wait) ? rs_value :
                        forwardA    ? exe_result :
                        forwardB    ? mem_result : rs_value;
    assign to_id_rt   = !(id_need_rt & rt_wait) ? rt_value :
                        forwardA    ? exe_result :
                        forwardB    ? mem_result : rt_value;  
//---------------------------{旁路信号}end---------------------------//

//-------------------------{各模块实例化}begin---------------------------//
    wire next_fetch; //即将运行取指模块，需要先锁存PC值
    //IF允许进入时，即锁存PC值，取下一条指令
    assign next_fetch = IF_allow_in;
    fetch IF_module(             // 取指级
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF_valid  (IF_valid  ),  // I, 1
        .next_fetch(next_fetch),  // I, 1
        .inst      (inst_sram_rdata),
        .jbr_bus   (jbr_bus   ),  // I, 33
        .inst_addr (inst_sram_addr),
        .IF_over   (IF_over   ),  // O, 1
        .IF_ID_bus (IF_ID_bus ),  // O, 64
        .delay_slot(inst_jbr  ),

        //5级流水新增接口
        .exc_bus   (exc_bus   ),  // I, 32
        
        //展示PC和取出的指令
        .IF_pc     (IF_pc     ),  // O, 32
        .IF_inst   (IF_inst   )   // O, 32
    );

    decode ID_module(               // 译码级
        .ID_valid   (ID_valid   ),  // I, 1
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        // .rs_value   (rs_value   ),  // I, 32
        // .rt_value   (rt_value   ),  // I, 32
        .rs_value   (to_id_rs   ),
        .rt_value   (to_id_rt   ),
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus    ),  // O, 33
        .inst_jbr   (inst_jbr   ),  // O, 1
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        
        //5级流水新增
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest   (EXE_wdest   ),// I, 5
        .MEM_wdest   (MEM_wdest   ),// I, 5
        .WB_wdest    (WB_wdest    ),// I, 5
        
        //旁路信号
        .id_need_rs  (id_need_rs  ),
        .id_need_rt  (id_need_rt  ),
        .rs_wait     (rs_wait     ),
        .rt_wait     (rt_wait     ),

        //cancel 
        .cancel      (cancel      ),

        //展示PC
        .ID_pc       (ID_pc       ) // O, 32
    ); 

    exe EXE_module(                   // 执行级
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        .exe_result  (exe_result  ),

        //5级流水新增
        .clk         (clk         ),  // I, 1
        .EXE_wdest   (EXE_wdest   ),  // O, 5
        .EXE_rf_wen  (EXE_rf_wen  ),

        //展示PC
        .EXE_pc      (EXE_pc      ),   // O, 32
        
        //旁路数据
        .to_alu      (to_alu      )
    );

    mem MEM_module(                     // 访存级
        .clk          (clk          ),  // I, 1 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        // .dm_rdata     (dm_rdata     ),  // I, 32
        // .dm_addr      (dm_addr      ),  // O, 32
        // .dm_wen       (dm_wen       ),  // O, 4 
        // .dm_wdata     (dm_wdata     ),  // O, 32
      
        .dm_rdata     (data_sram_rdata),
        .dm_addr      (data_sram_addr),
        // .dm_wen       (data_sram_wen),
        .dm_wen       (dm_wen),
        .dm_wdata     (data_sram_wdata),
      
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        .mem_result   (mem_result   ),

        //5级流水新增接口
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest    (MEM_wdest    ),  // O, 5
        .MEM_rf_wen   (MEM_rf_wen   ),

        //展示PC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(                     // 写回级
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
        .WB_over     (WB_over     ),  // O, 1
        
        //5级流水新增接口
        .clk         (clk         ),  // I, 1
        .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest    (WB_wdest    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        //展示PC和HI/LO值
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     )   // O, 32
    );

    regfile rf_module(        // 寄存器堆模块
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value ),  // O, 32

        //display rf
        .test_addr(rf_addr),  // I, 5
        .test_data(rf_data)   // O, 32
    );
    
    bypass_control bypass_module(
        .rs         (rs        ),
        .rt         (rt        ),
        .EXE_wdest  (EXE_wdest ),
        .MEM_wdest  (MEM_wdest ),
        .EXE_rf_wen (EXE_rf_wen),
        .MEM_rf_wen (MEM_rf_wen),

        .forwardA   (forwardA  ),
        .forwardB   (forwardB  )
    );

    //测试程序testbench需要
    assign debug_wb_pc = WB_pc;
    assign debug_wb_rf_wen = rf_wen;
    assign debug_wb_rf_wdata = rf_wdata;
    assign debug_wb_rf_wnum = rf_wdest;
//--------------------------{各模块实例化}end----------------------------//
endmodule