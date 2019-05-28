`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: exe.v
//   > 描述  :五级流水CPU的执行模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module exe(                         // 执行级
    input              EXE_valid,   // 执行级有效信号
    input      [181:0] ID_EXE_bus_r,// ID->EXE总线
    output             EXE_over,    // EXE模块执行完成
    output     [162:0] EXE_MEM_bus, // EXE->MEM总线
    output     [ 31:0] exe_result,  // EXE阶段的结果

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
    wire divide;           //除法
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire mult_sign;
    wire div_sign;
    wire [11:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    //异常
    wire fetch_error;   
    wire inst_reserved;
    wire check_overflow;    //是否检测溢出
    wire overflow;          //特定指令需要检测结果是否溢出
    wire [1:0] adder_cout;  //加法器的进位
    
    wire syscall;   //syscall和eret,break在写回级有特殊的操作 
    wire eret;
    wire break;

    assign overflow   = !check_overflow ? 0 :
                        (adder_cout[0]!=alu_result[31]) ? 1 : 0;
    
    //旁路
    wire rs_wait;
    wire rt_wait;
    wire inst_R;

    //访存需要用到的load/store信息
    wire [ 7:0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;  //store操作的存的数据
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7:0] cp0r_addr;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    wire delay_slot;

    //pc
    wire [31:0] pc;
    assign {multiply,
            divide,
            mthi,
            mtlo,
            mult_sign,
            div_sign,
            alu_control,
            alu_operand1,
            alu_operand2,
            check_overflow,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            break,
            rf_wen,
            rf_wdest,
            rs_wait,
            rt_wait,
            inst_R,
            fetch_error,
            inst_reserved,
            delay_slot,
            pc          } = ID_EXE_bus_r;
//-----{ID->EXE总线}end

//-----{ALU}begin
    wire [31:0] alu_result;
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;

    //旁路
    assign alu_src1 = (inst_R & rs_wait) ? to_alu : alu_operand1;
    assign alu_src2 = (inst_R & rt_wait) ? to_alu : alu_operand2;
    alu alu_module(
        .alu_control  (alu_control),  // I, 12, ALU控制信号
        .alu_src1     (alu_src1),
        .alu_src2     (alu_src2),
        .alu_result   (alu_result),  // O, 32, ALU结果
        .adder_cout   (adder_cout)
    );
//-----{ALU}end

//-----{乘法器}begin
    wire        mult_begin; 
    wire [63:0] product; 
    wire        mult_end;

    assign mult_begin = multiply & EXE_valid;
    multiply multiply_module (
        .clk       (clk       ),
        .mult_begin(mult_begin),
        .mult_sign (mult_sign ),
        .mult_op1  (alu_operand1), 
        .mult_op2  (alu_operand2),
        .product   (product   ),
        .mult_end  (mult_end  )
    );
//-----{乘法器}end

//-----{除法器}begin
    wire        div_begin; 
    wire [31:0] quotient;
    wire [31:0] remainder; 
    wire        div_end;

    assign div_begin = divide & EXE_valid;
    divide divide_module (
        .clk          (clk         ),
        .div_begin    (div_begin   ),
        .div_sign     (div_sign    ),
        .div_op1      (alu_operand1), 
        .div_op2      (alu_operand2),
        .div_result   (quotient    ),
        .div_remainder(remainder   ),
        .div_end      (div_end     )
    );
//-----{除法器}end

//-----{EXE执行完成}begin
    //对于ALU操作，都是1拍可完成，
    //但对于乘除法操作，需要多拍完成
    assign EXE_over = EXE_valid & (~multiply | mult_end) 
                      & (~divide | div_end);
//-----{EXE执行完成}end

//-----{EXE模块的dest值}begin
   //只有在EXE模块有效时，其写回目的寄存器号才有意义
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXE模块的dest值}end

//-----{EXE模块的rf_wen值}begin
    assign EXE_rf_wen = rf_wen;
//-----{EXE模块的rf_wen值}end

//-----{EXE->MEM总线}begin
    //wire [31:0] exe_result;   //在exe级能确定的最终写回结果
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //要写入HI的值放在exe_result里，包括MULT和MTHI指令,
    //要写入LO的值放在lo_result里，包括MULT和MTLO指令,
    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        multiply ? product[63:32] : 
                        divide   ? remainder : alu_result;
    assign lo_result  = mtlo ? alu_operand1 : 
                        multiply ? product[31:0] :
                        divide   ? quotient : 32'd0;
    assign hi_write   = multiply | divide | mthi;
    assign lo_write   = multiply | divide | mtlo;

    assign EXE_MEM_bus = {mem_control,store_data,          //load/store信息和store数据
                          exe_result,                      //exe运算结果
                          lo_result,                       //乘法低32位结果，新增
                          hi_write,lo_write,               //HI/LO写使能，新增
                          mfhi,mflo,                       //WB需用的信号,新增
                          mtc0,mfc0,cp0r_addr,
                          syscall,eret,break,              //WB需用的信号,新增
                          rf_wen,rf_wdest,                 //WB需用的信号
                          //异常
                          fetch_error,inst_reserved,       //WB需用的信号，异常
                          overflow,                        //WB需用的信号，异常
                          delay_slot,
                          pc};                             //PC
//-----{EXE->MEM总线}end

//-----{展示EXE模块的PC值}begin
    assign EXE_pc = pc;
//-----{展示EXE模块的PC值}end
endmodule