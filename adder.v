`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: adder.v
//   > 描述  ：加法器，直接使用"+"，会自动调用库里的加法器
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module adder(
    input  [31:0] operand1,
    input  [31:0] operand2,
    input         cin,
    output [30:0] result,
    output [ 1:0] cout
    );

    wire [32:0] op1 = {operand1[31],operand1};
    wire [32:0] op2 = {operand2[31],operand2};
    //assign {cout,result} = operand1 + operand2 + cin;
    assign {cout,result} = op1 + op2 + cin;

endmodule