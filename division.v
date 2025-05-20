`timescale 1ns / 1ps

module top_pipelined_fp (
    input clk,
    input reset,
    input [31:0] d,
    input [31:0] n,
    output reg [31:0] result,
    output reg [31:0] result2
);

    // Stage 1: f0 = 1 / d (LUT)
    wire [31:0] f0;
    ReciprocalLUT lut1 (
        .d(d),
        .f0(f0)
    );

    // Internal wires and registers for pipelining
    reg [31:0] d_s1, f0_s1;
    wire [31:0] mult_d_f0_s2;
    wire [31:0] y1_s3;

    wire [31:0] d1_s4, n1_s4;
    wire [31:0] f1_s5;
    wire [31:0] mult_d1_f1_s6;
    wire [31:0] y2_s7;

    wire [31:0] d2_s8, n2_s8;
    wire [31:0] f2_s9;
    wire [31:0] result_s10;
    wire [31:0] mult_d2_f2_s11;
    wire [31:0] y3_s12;

    wire [31:0] d3_s13, n3_s13;
    wire [31:0] f3_s14;
    wire [31:0] result2_s15;

    // Stage 1 registers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            d_s1 <= 32'd0;
            f0_s1 <= 32'd0;
        end else begin
            d_s1 <= d;
            f0_s1 <= f0;
        end
    end

    // Stage 2: mult_d_f0 = d * f0
    fp_multiply mul1 (
        .clk(clk), .reset(reset),
        .A(d_s1), .B(f0_s1), .Result(mult_d_f0_s2)
    );

    // Stage 3: y1 = 2 - mult_d_f0
    fp_sub_const sub1 (
        .clk(clk), .reset(reset),
        .b(mult_d_f0_s2), .result(y1_s3)
    );

    // Stage 4: d1 = d_s1 * y1, n1 = n * y1
    fp_multiply mul_d1 (
        .clk(clk), .reset(reset),
        .A(d_s1), .B(y1_s3), .Result(d1_s4)
    );
    fp_multiply mul_n1 (
        .clk(clk), .reset(reset),
        .A(n), .B(y1_s3), .Result(n1_s4)
    );

    // Stage 5: f1 = y1 * f0
    fp_multiply mul2 (
        .clk(clk), .reset(reset),
        .A(y1_s3), .B(f0_s1), .Result(f1_s5)
    );

    // Stage 6: mult_d1_f1 = d1 * f1
    fp_multiply mul3 (
        .clk(clk), .reset(reset),
        .A(d1_s4), .B(f1_s5), .Result(mult_d1_f1_s6)
    );

    // Stage 7: y2 = 2 - mult_d1_f1
    fp_sub_const sub2 (
        .clk(clk), .reset(reset),
        .b(mult_d1_f1_s6), .result(y2_s7)
    );

    // Stage 8: d2 = d1 * y2, n2 = n1 * y2
    fp_multiply mul_d2 (
        .clk(clk), .reset(reset),
        .A(d1_s4), .B(y2_s7), .Result(d2_s8)
    );
    fp_multiply mul_n2 (
        .clk(clk), .reset(reset),
        .A(n1_s4), .B(y2_s7), .Result(n2_s8)
    );

    // Stage 9: f2 = y2 * f1
    fp_multiply mul4 (
        .clk(clk), .reset(reset),
        .A(y2_s7), .B(f1_s5), .Result(f2_s9)
    );

    // Stage 10: result = n2 * f2
    fp_multiply mul5 (
        .clk(clk), .reset(reset),
        .A(n2_s8), .B(f2_s9), .Result(result_s10)
    );

    // Stage 11: d2 * f2
    fp_multiply mul6 (
        .clk(clk), .reset(reset),
        .A(d2_s8), .B(f2_s9), .Result(mult_d2_f2_s11)
    );

    // Stage 12: y3 = 2 - mult_d2_f2
    fp_sub_const sub3 (
        .clk(clk), .reset(reset),
        .b(mult_d2_f2_s11), .result(y3_s12)
    );

    // Stage 13: d3 = d2 * y3, n3 = n2 * y3
    fp_multiply mul_d3 (
        .clk(clk), .reset(reset),
        .A(d2_s8), .B(y3_s12), .Result(d3_s13)
    );
    fp_multiply mul_n3 (
        .clk(clk), .reset(reset),
        .A(n2_s8), .B(y3_s12), .Result(n3_s13)
    );

    // Stage 14: f3 = y3 * f2
    fp_multiply mul7 (
        .clk(clk), .reset(reset),
        .A(y3_s12), .B(f2_s9), .Result(f3_s14)
    );

    // Stage 15: result2 = n3 * f3
    fp_multiply mul8 (
        .clk(clk), .reset(reset),
        .A(n3_s13), .B(f3_s14), .Result(result2_s15)
    );

    // Final output register
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 32'd0;
            result2 <= 32'd0;
        end else begin
            result <= result_s10;
            result2 <= result2_s15;
        end
    end

endmodule
