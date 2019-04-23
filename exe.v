`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: exe.v
//   > 描述  :五级流水CPU的执行模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module exe(                         // 执行级
    input              EXE_valid,   // 执行级有效信号
    input      [169:0] ID_EXE_bus_r,// ID->EXE总线
    output             EXE_over,    // EXE模块执行完成
    output     [154:0] EXE_MEM_bus, // EXE->MEM总线
    
    //5级流水新增
    input              clk,         // 时钟
    output     [  4:0] EXE_wdest,   // EXE级要写回寄存器堆的目标地址号
    output             EXE_rf_wen,  // EXE级是否需要写回

    //展示PC
    output     [ 31:0] EXE_pc,

    //旁路数据
    input      [ 31:0] to_alu
);
//-----{ID->EXE总线}begin
    //EXE需要用到的信息
    wire multiply;         //乘法
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;
    //new
    wire checkoverflow;    //是否检测溢出
    //旁路
    wire rs_wait;
    wire rt_wait;

    //访存需要用到的load/store信息
    wire [ 3:0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;  //store操作的存的数据
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    //new 后面所有的bus加一位
    wire overflow; //特定指令需要检测结果是否溢出
    wire cout;     //加法器的进位
    //pc
    wire [31:0] pc;
    assign {multiply,
            mthi,
            mtlo,
            alu_control,
            alu_operand1,
            alu_operand2,
            checkoverflow,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            rf_wen,
            rf_wdest,
            rs_wait,
            rt_wait,
            pc          } = ID_EXE_bus_r;
//-----{ID->EXE总线}end

    assign EXE_rf_wen = rf_wen;

//-----{ALU}begin
    wire [31:0] alu_result;
    
    //旁路 可能有错
    assign alu_operand1 = rs_wait ? to_alu : rs_wait;
    assign alu_operand2 = rt_wait ? to_alu : rt_wait;
    
    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU控制信号
        .alu_src1     (alu_operand1),  // I, 32, ALU操作数1
        .alu_src2     (alu_operand2),  // I, 32, ALU操作数2
        .alu_result   (alu_result  ),  // O, 32, ALU结果
        .cout         (cout)           // O,  1, 是否溢出
    );
//-----{ALU}end

//-----{乘法器}begin
    wire        mult_begin; 
    wire [63:0] product; 
    wire        mult_end;
    
    assign mult_begin = multiply & EXE_valid;
    multiply multiply_module (
        .clk       (clk       ),
        .mult_begin(mult_begin  ),
        .mult_op1  (alu_operand1), 
        .mult_op2  (alu_operand2),
        .product   (product   ),
        .mult_end  (mult_end  )
    );
//-----{乘法器}end

//-----{EXE执行完成}begin
    //对于ALU操作，都是1拍可完成，
    //但对于乘法操作，需要多拍完成
    assign EXE_over = EXE_valid & (~multiply | mult_end);
//-----{EXE执行完成}end

//-----{EXE模块的dest值}begin
   //只有在EXE模块有效时，其写回目的寄存器号才有意义
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXE模块的dest值}end

//-----{EXE->MEM总线}begin
    wire [31:0] exe_result;   //在exe级能确定的最终写回结果
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //要写入HI的值放在exe_result里，包括MULT和MTHI指令,
    //要写入LO的值放在lo_result里，包括MULT和MTLO指令,
    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        multiply ? product[63:32] : alu_result;
    assign lo_result  = mtlo ? alu_operand1 : product[31:0];
    assign hi_write   = multiply | mthi;
    assign lo_write   = multiply | mtlo;
    assign overflow   = checkoverflow ? cout : 0;

    assign EXE_MEM_bus = {mem_control,store_data,          //load/store信息和store数据
                          exe_result,                      //exe运算结果
                          lo_result,                       //乘法低32位结果，新增
                          hi_write,lo_write,               //HI/LO写使能，新增
                          mfhi,mflo,                       //WB需用的信号,新增
                          mtc0,mfc0,cp0r_addr,syscall,eret,//WB需用的信号,新增
                          rf_wen,rf_wdest,                 //WB需用的信号
                          //new
                          overflow,                        //WB需用的信号，异常
                          pc};                             //PC
//-----{EXE->MEM总线}end

//-----{展示EXE模块的PC值}begin
    assign EXE_pc = pc;
//-----{展示EXE模块的PC值}end
endmodule