`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: wb.v
//   > 描述  :五级流水CPU的写回模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
`define EXC_ENTER_ADDR 32'hBFC00380     // Excption入口地址，

module wb(                       // 写回级
    input          WB_valid,     // 写回级有效
    input  [156:0] MEM_WB_bus_r, // MEM->WB总线
    output [  3:0] rf_wen,       // 寄存器写使能
    output [  4:0] rf_wdest,     // 寄存器写地址
    output [ 31:0] rf_wdata,     // 寄存器写数据
    output         WB_over,      // WB模块执行完成

    //5级流水新增接口
    input             clk,       // 时钟
    input             resetn,    // 复位信号，低电平有效
    output [ 32:0] exc_bus,      // Exception pc总线
    output [  4:0] WB_wdest,     // WB级要写回寄存器堆的目标地址号
    output         cancel,       // syscall和eret到达写回级时会发出cancel信号，
                                 // 取消已经取出的正在其他流水级执行的指令
 
    //展示PC和HI/LO值
    output [ 31:0] WB_pc,
    output [ 31:0] HI_data,
    output [ 31:0] LO_data
);
//-----{MEM->WB总线}begin    
    //MEM传来的result
    wire [31:0] mem_result;
    //HI/LO数据
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
    //寄存器堆写使能和写地址
    wire wen;
    wire [4:0] wdest;
    
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7:0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;

    //异常
    wire break;
    wire fetch_error;
    wire inst_reserved;
    wire raddr_error;
    wire waddr_error;
    wire overflow; 
    wire exc_happen;

    assign exc_happen = fetch_error | inst_reserved | raddr_error 
                        | waddr_error | overflow | syscall | break;

    wire [31:0] dm_addr;
    wire delay_slot;

    //pc
    wire [31:0] pc;    
    assign {wen,
            wdest,
            mem_result,
            lo_result,
            hi_write,
            lo_write,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            break,
            fetch_error,
            inst_reserved,
            raddr_error,
            waddr_error,
            overflow,
            dm_addr,
            delay_slot,
            pc} = MEM_WB_bus_r;
//-----{MEM->WB总线}end

//-----{HI/LO寄存器}begin
    //HI用于存放乘法结果的高32位
    //LO用于存放乘法结果的低32位
    reg [31:0] hi;
    reg [31:0] lo;
    
    //要写入HI的数据存放在mem_result里
    always @(posedge clk)
    begin
        if (hi_write)
        begin
            hi <= mem_result;
        end
        else if (!resetn)
        begin 
            hi <= 32'd0;
        end
    end
    //要写入LO的数据存放在lo_result里
    always @(posedge clk)
    begin
        if (lo_write)
        begin
            lo <= lo_result;
        end
        else if (!resetn)
        begin
            lo <= 32'd0; 
        end
    end
//-----{HI/LO寄存器}end

//-----{cp0寄存器}begin
// cp0寄存器即是协处理器0寄存器
// 每个CP0寄存器都是使用5位的cp0号
    wire [31:0] cp0r_status;
    wire [31:0] cp0r_cause;
    wire [31:0] cp0r_epc;
    wire [31:0] cp0r_badvaddr;
    wire [31:0] cp0r_count;
    wire [31:0] cp0r_compare;

    //写使能
    wire status_wen;
    wire epc_wen;
    wire count_wen;
    wire compare_wen;

    assign status_wen  = mtc0 & (cp0r_addr=={5'd12,3'd0});//0x60
    assign epc_wen     = mtc0 & (cp0r_addr=={5'd14,3'd0});
    assign count_wen   = mtc0 & (cp0r_addr=={5'd9 ,3'd0});
    assign compare_wen = mtc0 & (cp0r_addr=={5'd11,3'd0});
   
    //cp0寄存器读
    wire [31:0] cp0r_rdata;
    assign cp0r_rdata = (cp0r_addr=={5'd8 ,3'd0}) ? cp0r_badvaddr :
                        (cp0r_addr=={5'd9 ,3'd0}) ? cp0r_count    :
                        (cp0r_addr=={5'd11,3'd0}) ? cp0r_compare  : 
                        (cp0r_addr=={5'd12,3'd0}) ? cp0r_status   :
                        (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause    :
                        (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;
   
    //STATUS寄存器
    //目前只实现STATUS[1]位，即EXL域
    //EXL域为软件可读写，故需要statu_wen
    reg [31:0]status_r;
    assign cp0r_status = status_r;
    always @(posedge clk)
    begin
        if (!resetn)
        begin      
            status_r[31:23] <= 9'd0;
		    status_r[22]    <= 1'b1;
            status_r[21:0 ] <= 22'b0;
        end
        else if (eret)
        begin
            status_r[1] <= 1'b0;
        end
        else if (exc_happen)
        begin 
            status_r[1] <= 1'b1;
        end 
        else if (status_wen)
        begin 
            status_r <= mem_result;
        end
    end
   
    //CAUSE寄存器
    //ExcCode域为软件只读，不可写，故不需要cause_wen
    reg [31:0] cause_r;
    assign cp0r_cause = cause_r;
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            cause_r[31:7] <= 25'd0;
            cause_r[ 1:0] <=  2'd0;
        end
        //时钟中断
        if (cp0r_count==cp0r_compare)
        begin
            cause_r[30] <= 1'b1;
            cause_r[15] <= 1'b1;
        end
        else
        begin 
            cause_r[30] <= 1'b0;
            cause_r[15] <= 1'b0;                 
        end
        //发生异常的指令是否在延迟槽中
        if (exc_happen | int_happen)
        begin
            cause_r[31] <= delay_slot;
        end
        //根据不同类型的异常赋值
        if (fetch_error)
        begin 
            cause_r[6:2] <= 5'd4;
        end
        else if (inst_reserved)
        begin
            cause_r[6:2] <= 5'ha;
        end
        else if (syscall)
        begin
            cause_r[6:2] <= 5'd8;
        end
        else if (overflow)
        begin 
            cause_r[6:2] <= 5'hc;
        end
        else if (raddr_error)
        begin 
            cause_r[6:2] <= 5'd4;
        end
        else if (waddr_error)
        begin 
            cause_r[6:2] <= 5'd5;
        end
        else if (break)
        begin
            cause_r[6:2] <= 5'd9;
        end
    end
   
    //EPC寄存器
    //存放产生例外的地址
    //EPC整个域为软件可读写的，故需要epc_wen
    reg [31:0] epc_r;
    assign cp0r_epc = epc_r;
    always @(posedge clk)
    begin
        if (exc_happen | int_happen)
        begin
            if (delay_slot)
            begin
                epc_r <= pc - 32'd4;
            end
            else
            begin
                epc_r <= pc;
            end
        end
        else if (epc_wen)
        begin
            epc_r <= mem_result;
        end
    end

    //BadVAddr寄存器
    reg [31:0] badvaddr_r;
    assign cp0r_badvaddr = badvaddr_r;
    always @(posedge clk)
    begin
        if (raddr_error | waddr_error)
        begin 
            badvaddr_r <= dm_addr;
        end
        else if (fetch_error)
        begin 
            badvaddr_r <= pc;
        end
    end

    //Count寄存器
    reg [31:0] count_r;
    reg flag;
    assign cp0r_count = count_r;
    always @(posedge clk)
    begin
        if (!resetn)
        begin
            count_r <= 32'b0;
            flag    <=  1'b0;
        end
        else if (flag)
        begin 
            count_r <= count_r + 1'b1;
            flag    <= 1'b0;
        end
        else if (!flag)
        begin 
            flag    <= 1'b1;
        end
        if (count_wen)
        begin 
            count_r <= mem_result;
        end
    end  

    //Compare寄存器
    reg [31:0] compare_r;
    assign cp0r_compare = compare_r;
    always @(posedge clk)
    begin
        if (compare_wen)
        begin
            compare_r <= mem_result;
        end
    end

    //所有异常,中断和eret发出的cancel信号
    assign cancel = (exc_happen | eret) & WB_over;
    //assign cancel = (exc_happen | int_happen | eret) & WB_over;
//-----{cp0寄存器}end

//-----{中断}begin
    wire int_en;//intterupt
    wire int_happen;
    wire hard_int;
    wire soft_int;
    wire clock_int;

    assign int_en       = (status_r[0]==1'b1 && status_r[1]==1'b0);
    assign hard_int     = !int_en ? 1'b0 :
                         ((status_r[10] & cause_r[10]) |
                          (status_r[11] & cause_r[11]) |
                          (status_r[12] & cause_r[12]) |
                          (status_r[13] & cause_r[13]) |
                          (status_r[14] & cause_r[14]) |
                          (status_r[15] & cause_r[15])) ? 1'b1 : 1'b0;
    assign soft_int     = !int_en ? 1'b0 :
                         ((status_r[8] & cause_r[8]) |
                          (status_r[9] & cause_r[9])) ? 1'b1 : 1'b0;
    assign clock_int    = !int_en ? 1'b0 :
                          (status_r[15] & cause_r[15]) ? 1'b1 : 1'b0;
    assign int_happen   = hard_int | soft_int | clock_int;
//-----{中断}end

//-----{WB执行完成}begin
    //WB模块所有操作都可在一拍内完成
    //故WB_valid即是WB_over信号
    assign WB_over = WB_valid;
//-----{WB执行完成}end

//-----{WB->regfile信号}begin
    assign rf_wen   = exc_happen ? 4'b0 : {4{wen & WB_over}};
    assign rf_wdest = wdest;
    assign rf_wdata = mfhi ? hi :
                      mflo ? lo :
                      mfc0 ? cp0r_rdata : mem_result;
//-----{WB->regfile信号}end

//-----{Exception pc信号}begin
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign exc_valid = (exc_happen | int_happen | eret) & WB_valid;
    //eret返回地址为EPC寄存器的值
    assign exc_pc = (exc_happen | int_happen) ? `EXC_ENTER_ADDR : cp0r_epc;
    assign exc_bus = {exc_valid,exc_pc};
//-----{Exception pc信号}end

//-----{WB模块的dest值}begin
   //只有在WB模块有效时，其写回目的寄存器号才有意义
    assign WB_wdest = rf_wdest & {5{WB_valid}};
//-----{WB模块的dest值}end

//-----{展示WB模块的PC值和HI/LO寄存器的值}begin
    assign WB_pc = pc;
    assign HI_data = hi;
    assign LO_data = lo;
//-----{展示WB模块的PC值和HI/LO寄存器的值}end
endmodule
