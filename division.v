`timescale 1ns / 1ps
module top_pipelined_fp (
    input clk,
    input reset,
    input [31:0] n,
    input [31:0] d,
    output reg [31:0] result
);

    wire [31:0] x0, dx0, two_minus_dx0, x1;
    wire [31:0] dx1, two_minus_dx1, x2;
    wire [31:0] dx2, two_minus_dx2, x3;
    wire [31:0] final_result;

    // Initial approximation of 1/d from LUT
    ReciprocalLUT lut1 (
        .clk(clk),
        .reset(reset),
        .d(d),
        .f0(x0)
    );

    // Iteration 1
    fp_multiply mul1 (.clk(clk), .reset(reset), .A(d), .B(x0), .Result(dx0));
    fp_sub_const sub1 (.clk(clk), .reset(reset), .b(dx0), .result(two_minus_dx0));
    fp_multiply mul2 (.clk(clk), .reset(reset), .A(x0), .B(two_minus_dx0), .Result(x1));

    // Iteration 2
    fp_multiply mul3 (.clk(clk), .reset(reset), .A(d), .B(x1), .Result(dx1));
    fp_sub_const sub2 (.clk(clk), .reset(reset), .b(dx1), .result(two_minus_dx1));
    fp_multiply mul4 (.clk(clk), .reset(reset), .A(x1), .B(two_minus_dx1), .Result(x2));

    // Iteration 3
    fp_multiply mul5 (.clk(clk), .reset(reset), .A(d), .B(x2), .Result(dx2));
    fp_sub_const sub3 (.clk(clk), .reset(reset), .b(dx2), .result(two_minus_dx2));
    fp_multiply mul6 (.clk(clk), .reset(reset), .A(x2), .B(two_minus_dx2), .Result(x3));

    // Final result = n * x3
    fp_multiply mul7 (.clk(clk), .reset(reset), .A(n), .B(x3), .Result(final_result));

    // Registering the result
    always @(posedge clk or posedge reset) begin
        if (reset)
            result <= 32'd0;
        else
            result <= final_result;
    end

endmodule


