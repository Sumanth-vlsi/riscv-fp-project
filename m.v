`timescale 1ns / 1ps
module fp_multiply (
    input wire clk,
    input wire reset,
    input wire [31:0] A, B,         // IEEE-754 Single-Precision Floating Point Inputs
    output reg [31:0] Result        // IEEE-754 Output
);

    // Pipeline registers for 3-stage processing
    reg [31:0] A_reg, B_reg;
    reg [47:0] mantissa_mult;
    reg [9:0] exp_sum;
    reg sign_result;
    reg special_case;

    // Floating-Point Components (Stored in Registers)
    reg sign_A, sign_B;
    reg [7:0] exp_A, exp_B;
    reg [23:0] mant_A, mant_B;

    // Intermediate results for normalization
    reg [7:0] final_exp;
    reg [22:0] final_mantissa;

    // Stage 1: Register Inputs & Handle Special Cases
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            A_reg <= 32'b0;
            B_reg <= 32'b0;
            mantissa_mult <= 48'b0;
            exp_sum <= 10'b0;
            sign_result <= 1'b0;
            special_case <= 1'b0;
            Result <= 32'b0;
        end else begin
            A_reg <= A;
            B_reg <= B;

            // Extract sign, exponent, and mantissa
            sign_A <= A[31];
            sign_B <= B[31];
            exp_A <= A[30:23];
            exp_B <= B[30:23];

            mant_A <= (exp_A == 8'b0) ? {1'b0, A[22:0]} : {1'b1, A[22:0]};
            mant_B <= (exp_B == 8'b0) ? {1'b0, B[22:0]} : {1'b1, B[22:0]};

            // Special Cases Handling
            if ((A == 32'h00000000) || (B == 32'h00000000)) begin
                Result <= 32'h00000000; // Zero Case
                special_case <= 1'b1;
            end else if ((exp_A == 8'hFF && A[22:0] != 0) || 
                         (exp_B == 8'hFF && B[22:0] != 0)) begin
                Result <= 32'h7FC00000; // NaN Case
                special_case <= 1'b1;
            end else if ((exp_A == 8'hFF && A[22:0] == 0) || 
                         (exp_B == 8'hFF && B[22:0] == 0)) begin
                Result <= {sign_A ^ sign_B, 8'hFF, 23'b0}; // Infinity Case
                special_case <= 1'b1;
            end else begin
                special_case <= 1'b0;
            end
        end
    end

    // Stage 2: Multiply Mantissas and Sum Exponents
    always @(posedge clk) begin
        if (!special_case) begin
            mantissa_mult <= mant_A * mant_B;
            exp_sum <= exp_A + exp_B - 8'd127; // Bias adjustment
            sign_result <= sign_A ^ sign_B;
        end
    end

    // Stage 3: Normalize Result and Handle Overflow/Underflow
    always @(posedge clk) begin
        if (!special_case) begin
            if (exp_sum >= 255) begin
                final_exp <= 8'hFF;    // Overflow → Infinity
                final_mantissa <= 23'b0;
            end else if (exp_sum <= 0) begin
                final_exp <= 8'h00;    // Underflow → Zero
                final_mantissa <= 23'b0;
            end else begin
                if (mantissa_mult[47]) begin // Normalization: Shift right if MSB is 1
                    final_exp <= exp_sum + 1;
                    final_mantissa <= mantissa_mult[46:24]; // Keep 23 bits
                end else begin
                    final_exp <= exp_sum[7:0];
                    final_mantissa <= mantissa_mult[45:23];
                end
            end
        end
    end

    // Stage 4: Pack IEEE-754 format output
    always @(posedge clk) begin
        if (!special_case) begin
            Result <= {sign_result, final_exp, final_mantissa};
        end
    end

endmodule
