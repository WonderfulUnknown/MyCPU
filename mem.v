`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: mem.v
//   > 描述  :五级流水CPU的访存模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module mem(                          // 访存级
    input              clk,          // 时钟
    input              MEM_valid,    // 访存级有效信号
    input      [161:0] EXE_MEM_bus_r,// EXE->MEM总线
    input      [ 31:0] dm_rdata,     // 访存读数据
    output     [ 31:0] dm_addr,      // 访存读写地址
    output reg [  3:0] dm_wen,       // 访存写使能
    output reg [ 31:0] dm_wdata,     // 访存写数据
    output             MEM_over,     // MEM模块执行完成
    output     [155:0] MEM_WB_bus,   // MEM->WB总线
    output     [ 31:0] mem_result,    //MEM传到WB的result为load结果或EXE结果

    //5级流水新增接口
    input              MEM_allow_in, // MEM级允许下级进入
    output     [  4:0] MEM_wdest,    // MEM级要写回寄存器堆的目标地址号
    output             MEM_rf_wen,   // MEM级是否需要写回
     
    //展示PC
    output     [ 31:0] MEM_pc
);
//-----{EXE->MEM总线}begin
    //访存需要用到的load/store信息
    wire [7 :0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;   //store操作的存的数据
    
    //EXE结果和HI/LO数据
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret,break在写回级有特殊的操作 
    wire       eret;
    wire       break;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
   
    //异常
    wire fetch_error;
    wire inst_reserved;
    wire addr_error;
    wire raddr_error;
    wire waddr_error;
    wire overflow;

    assign addr_error = ((ls_word & dm_addr[1:0]!=2'd0) 
                        | (ls_half_word & dm_addr[0]!=1'd0))
                        ? 1'b1 : 1'b0;
    assign raddr_error = (inst_load & addr_error);
    assign waddr_error = (inst_store & addr_error);

    //pc
    wire [31:0] pc;    
    assign {mem_control,
            store_data,
            exe_result,
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
            rf_wen,
            rf_wdest,
            //异常
            fetch_error,
            inst_reserved,
            overflow,
            pc         } = EXE_MEM_bus_r;  
//-----{EXE->MEM总线}end

//-----{load/store访存}begin
    wire inst_load;  //load操作
    wire inst_store; //store操作
    wire l_sign;  //有符号load
    wire ls_word; //load/store为字
    wire ls_byte; //load/store为字节
    wire ls_half_word; //load/store为半字
    wire ls_unaligned;//非对齐存取字
    wire direction;//左拼接还是右拼接  
    assign {inst_load,
            inst_store,
            l_sign,
            ls_word,
            ls_byte,
            ls_half_word,
            ls_unaligned,
            direction } = mem_control;

    //访存读写地址
    assign dm_addr = exe_result;

    //(*)当begin end里面的任意信号发生变化时
    //会在当前begin end重新执行一遍begin end 

    //store操作的写使能
    always @ (*)    // 内存写使能信号
    begin
        // 访存级有效时,写地址无异常,且为store操作
        if (MEM_valid & inst_store & !waddr_error) 
        begin
            if (ls_word)//SW指令
            begin
                dm_wen <= 4'b1111; // 存储字指令，写使能全1
            end
            else if (ls_half_word)//SH指令
            begin 
                case (dm_addr[1])
                    1'b0    : dm_wen <= 4'b0011;
                    1'b1    : dm_wen <= 4'b1100;
                    default : dm_wen <= 4'b0000;
                endcase
            end
            // SB指令，需要依据地址底两位，确定对应的写使能
            else if (ls_byte)
            begin 
                case (dm_addr[1:0])
                    2'b00   : dm_wen <= 4'b0001;
                    2'b01   : dm_wen <= 4'b0010;
                    2'b10   : dm_wen <= 4'b0100;
                    2'b11   : dm_wen <= 4'b1000;
                    default : dm_wen <= 4'b0000;
                endcase
            end
            //SWL,SWR指令，需要依据地址底两位，确定对应的写使能
            else if (ls_unaligned)
            begin 
                if (direction)
                begin
                    case (dm_addr[1:0])
                        2'b00   : dm_wen <= 4'b0001;
                        2'b01   : dm_wen <= 4'b0011;
                        2'b10   : dm_wen <= 4'b0111;
                        2'b11   : dm_wen <= 4'b1111;
                        default : dm_wen <= 4'b0000;
                    endcase
                end
                else
                begin
                    case (dm_addr[1:0])
                        2'b00   : dm_wen <= 4'b1111;
                        2'b01   : dm_wen <= 4'b1110;
                        2'b10   : dm_wen <= 4'b1100;
                        2'b11   : dm_wen <= 4'b1000;
                        default : dm_wen <= 4'b0000;
                    endcase               
                end
            end
        end
        else
        begin
            dm_wen <= 4'b0000;
        end
    end 
    
    //store操作的写数据
    // 对于SB指令，需要依据地址底两位，移动store的字节至对应位置
    // 对于SH指令, 需要依据地址的倒数第二位,移动store的字节至对应位置
    always @ (*)  
    begin
        if (ls_half_word)
        begin
            case (dm_addr[1])
                1'b0    : dm_wdata <= store_data;
                1'b1    : dm_wdata <= {store_data[15:0],16'd0};
                default : dm_wdata <= store_data;
            endcase
        end
        else if (ls_word)
        begin
            dm_wdata <= store_data; 
        end
        else if (ls_byte)
        begin
            case (dm_addr[1:0])
                2'b00   : dm_wdata <= store_data;
                2'b01   : dm_wdata <= {16'd0, store_data[7:0], 8'd0};
                2'b10   : dm_wdata <= {8'd0, store_data[7:0], 16'd0};
                2'b11   : dm_wdata <= {store_data[7:0], 24'd0};
                default : dm_wdata <= store_data;
            endcase
        end
        else if (ls_unaligned)//SWL,SWR
        begin 
            if (direction)
            begin
                case (dm_addr[1:0])
                    2'b00   : dm_wdata <= {24'd0,store_data[31:24]};
                    2'b01   : dm_wdata <= {16'd0,store_data[31:16]};
                    2'b10   : dm_wdata <= { 8'd0,store_data[31: 8]};
                    2'b11   : dm_wdata <= {store_data};
                    default : dm_wdata <= store_data;
                endcase
            end
            else
            begin 
                case (dm_addr[1:0])
                    2'b00   : dm_wdata <= store_data;
                    2'b01   : dm_wdata <= {store_data[23:0], 8'd0};
                    2'b10   : dm_wdata <= {store_data[15:0],16'd0};
                    2'b11   : dm_wdata <= {store_data[ 7:0],24'd0};
                    default : dm_wdata <= store_data;
                endcase      
            end
        end
    end
    
    //load读出的数据
    wire        load_sign;
    wire [31:0] load_result;
    reg  [31:0] unaligned_result;

    assign load_sign = (ls_half_word && dm_addr[1]==1'b0) ? dm_rdata[15] :
                       (ls_byte && dm_addr[1:0]==2'd0) ? dm_rdata[ 7] :
                       (ls_byte && dm_addr[1:0]==2'd1) ? dm_rdata[15] :
                       (ls_byte && dm_addr[1:0]==2'd2) ? dm_rdata[23] : 
                                                         dm_rdata[31] ;
    assign load_result[ 7:0 ] = (ls_half_word && dm_addr[1]==1'b1) ? dm_rdata[23:16] :
                                (ls_byte && dm_addr[1:0]==2'd1) ? dm_rdata[15:8 ] :
                                (ls_byte && dm_addr[1:0]==2'd2) ? dm_rdata[23:16] :
                                (ls_byte && dm_addr[1:0]==2'd3) ? dm_rdata[31:24] :
                                                                  dm_rdata[ 7:0 ] ;
    assign load_result[15:8 ] = (ls_half_word && dm_addr[1]==1'b1)   ? dm_rdata[31:24] :
                                (ls_half_word && dm_addr[1]==1'b0)   ? dm_rdata[15:8 ] :
                                ls_word ? dm_rdata[15:8 ] : {8 {l_sign & load_sign}};
    assign load_result[31:16] = ls_word ? dm_rdata[31:16] : {16{l_sign & load_sign}};

    always @(*) 
    begin
        if (ls_unaligned & direction & !inst_store)  // LWL
        begin
            case (dm_addr[1:0])
                2'b00     : unaligned_result <= {dm_rdata[ 7:0],store_data[23:0]};
                2'b01     : unaligned_result <= {dm_rdata[15:0],store_data[15:0]};
                2'b10     : unaligned_result <= {dm_rdata[23:0],store_data[ 7:0]};
                2'b11     : unaligned_result <= dm_rdata;
                default   : unaligned_result <= dm_rdata;
            endcase
        end
        else if (ls_unaligned & (!direction) & !inst_store) // LWR
        begin
            case (dm_addr[1:0])
                2'b00     : unaligned_result <= dm_rdata;
                2'b01     : unaligned_result <= {store_data[31:24],dm_rdata[31:8 ]};
                2'b10     : unaligned_result <= {store_data[31:16],dm_rdata[31:16]};
                2'b11     : unaligned_result <= {store_data[31:8 ],dm_rdata[31:24]};
                default   : unaligned_result <= dm_rdata;

            endcase
        end
    end

//-----{load/store访存}end

//-----{MEM执行完成}begin
    //由于数据RAM为同步读写的,
    //故对load指令，取数据时，有一拍延时
    //即发地址的下一拍时钟才能得到load的数据
    //故mem在进行load操作时有需要两拍时间才能取到数据
    //而对其他操作，则只需要一拍时间
    reg MEM_valid_r;
    always @(posedge clk)
    begin
        if (MEM_allow_in)
        begin
            MEM_valid_r <= 1'b0;
        end
        else
        begin
            MEM_valid_r <= MEM_valid;
        end
    end
    assign MEM_over = inst_load ? MEM_valid_r : MEM_valid;
    //如果数据ram为异步读的，则MEM_valid即是MEM_over信号，
    //即load一拍完成
//-----{MEM执行完成}end

//-----{MEM模块的dest值}begin
   //只有在MEM模块有效时，其写回目的寄存器号才有意义
    assign MEM_wdest = rf_wdest & {5{MEM_valid}};
//-----{MEM模块的dest值}end

//-----{MEM模块的rf_wen值}begin
    assign MEM_rf_wen = rf_wen;
//-----{MEM模块的rf_wen值}end

//-----{MEM->WB总线}begin
    //wire [31:0] mem_result; //MEM传到WB的result为load结果或EXE结果
    //assign mem_result = inst_load ? load_result : exe_result;
    assign mem_result = ls_unaligned ? unaligned_result :
                        inst_load    ? load_result      : exe_result;   

    assign MEM_WB_bus = {rf_wen,rf_wdest,                   // WB需要使用的信号
                         mem_result,                        // 最终要写回寄存器的数据
                         lo_result,                         // 乘法低32位结果，新增
                         hi_write,lo_write,                 // HI/LO写使能，新增
                         mfhi,mflo,                         // WB需要使用的信号,新增
                         mtc0,mfc0,cp0r_addr,
                         syscall,eret,break,                // WB需要使用的信号,新增
                         //异常
                         fetch_error,inst_reserved,
                         raddr_error,waddr_error,
                         overflow,                          //WB需用的信号，异常
                         dm_addr,
                         pc};                               // PC值
//-----{MEM->WB总线}begin

//-----{展示MEM模块的PC值}begin
    assign MEM_pc = pc;
//-----{展示MEM模块的PC值}end
endmodule
