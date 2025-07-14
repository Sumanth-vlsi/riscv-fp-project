`timescale 1ns / 1ps

module fpu_top (
    input wire clk,
    input wire reset,
    input wire [1:0] op_mode,           // 00 = add, 01 = sub, 10 = mul, 11 = div
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [31:0] result,
    output wire [31:0] result2,
    output wire [31:0] result3_s20     // NEW: average of two division results
);

    // Internal wires
    wire [31:0] addsub_result;
    wire [31:0] mult_result;
    wire [31:0] div_result, div_result2;
    wire [31:0] div_result3_s20;

    // Instantiate fp_add_sub (for addition and subtraction)
    fp_add_sub addsub_inst (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .op_mode(op_mode),  // 00 = add, 01 = sub
        .result(addsub_result)
    );

    // Instantiate fp_multiply (for multiplication)
    fp_multiply mult_inst (
        .clk(clk),
        .reset(reset),
        .A(a),
        .B(b),
        .Result(mult_result)
    );

    // Instantiate top_pipelined_fp (for division)
 top_pipelined_fp div_inst (
    .clk(clk),
    .reset(reset),
    .d(b),
    .n(a),
    .result(div_result)
);


    // Output selection logic
    assign result = (op_mode == 2'b00 || op_mode == 2'b01) ? addsub_result :
                    (op_mode == 2'b10)                     ? mult_result   :
                    (op_mode == 2'b11)                     ? div_result    : 32'd0;

    assign result2 = (op_mode == 2'b11) ? div_result2 : 32'd0;

endmodule

