`timescale 1ns / 1ps

module fp_sub_const (
    input wire clk,               // Clock input
    input wire reset,             // Reset signal
    input wire [31:0] b,          // Input floating-point number
    output reg [31:0] result      // Floating-point result
);

    // Constant input a = 2.0 (IEEE 754: 0x40000000)
    wire [31:0] a = 32'h40000000;

    // Internal registers and wires
    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b, exp_res;
    reg [23:0] mant_a, mant_b;
    reg [24:0] sum_diff;
    reg [7:0] exp_diff;
    reg [4:0] shift_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 32'b0;
        end else begin
            // Extract sign, exponent, and mantissa
            sign_a <= a[31];
            sign_b <= ~b[31]; // Flip sign of b
            exp_a  <= a[30:23];
            exp_b  <= b[30:23];

            mant_a <= (exp_a == 8'b0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
            mant_b <= (exp_b == 8'b0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

            // Align exponents
            if (exp_a > exp_b) begin
                exp_diff = exp_a - exp_b;
                mant_b = mant_b >> exp_diff;
                exp_res = exp_a;
            end else if (exp_b > exp_a) begin
                exp_diff = exp_b - exp_a;
                mant_a = mant_a >> exp_diff;
                exp_res = exp_b;
            end else begin
                exp_res = exp_a;
            end

            // Perform addition/subtraction
            if (sign_a == sign_b) begin
                sum_diff = mant_a + mant_b;
                sign_res = sign_a;
            end else begin
                if (mant_a >= mant_b) begin
                    sum_diff = mant_a - mant_b;
                    sign_res = sign_a;
                end else begin
                    sum_diff = mant_b - mant_a;
                    sign_res = sign_b;
                end
            end

            // Normalize result
            shift_count = 0;
            if (sum_diff[24]) begin
                sum_diff = sum_diff >> 1;
                exp_res = exp_res + 1;
            end else begin
                while (!sum_diff[23] && exp_res > 0 && shift_count < 23) begin
                    sum_diff = sum_diff << 1;
                    exp_res = exp_res - 1;
                    shift_count = shift_count + 1;
                end
            end

            // Pack result or handle special cases
            if (exp_res == 8'hFF) begin
                result <= {sign_res, 8'hFF, 23'b0}; // Infinity
            end else if (sum_diff == 25'b0) begin
                result <= 32'b0; // Zero
            end else begin
                result <= {sign_res, exp_res, sum_diff[22:0]};
            end
        end
    end
endmodule
