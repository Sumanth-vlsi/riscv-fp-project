`timescale 1ns / 1ps

module fp_multiply (
    input wire clk,
    input wire reset,
    input wire [31:0] A,
    input wire [31:0] B,
    output reg [31:0] Result
);

    // FSM States
    reg [1:0] state;
    parameter IDLE = 2'b00, STAGE1 = 2'b01, STAGE2 = 2'b10, STAGE3 = 2'b11;

    // Stage 1: Extraction
    reg [31:0] A_reg, B_reg;
    reg sign_A, sign_B;
    reg [7:0] exp_A, exp_B;
    reg [23:0] mant_A, mant_B;

    // Stage 2: Multiplication
    reg [47:0] mantissa_mult;
    reg [9:0] exp_sum;
    reg sign_result;

    // Stage 3: Normalization and Packing
    reg [7:0] final_exp;
    reg [22:0] final_mantissa;
    reg special_case;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            Result <= 32'b0;
            special_case <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    A_reg <= A;
                    B_reg <= B;
                    state <= STAGE1;
                end

                STAGE1: begin
                    sign_A <= A_reg[31];
                    sign_B <= B_reg[31];
                    exp_A <= A_reg[30:23];
                    exp_B <= B_reg[30:23];

                    mant_A <= (A_reg[30:23] == 8'd0) ? {1'b0, A_reg[22:0]} : {1'b1, A_reg[22:0]};
                    mant_B <= (B_reg[30:23] == 8'd0) ? {1'b0, B_reg[22:0]} : {1'b1, B_reg[22:0]};

                    // Handle special cases
                    if (A_reg == 32'd0 || B_reg == 32'd0) begin
                        Result <= 32'd0;
                        special_case <= 1'b1;
                        state <= IDLE;
                    end else if ((exp_A == 8'hFF && A_reg[22:0] != 0) || 
                                 (exp_B == 8'hFF && B_reg[22:0] != 0)) begin
                        Result <= 32'h7FC00000; // NaN
                        special_case <= 1'b1;
                        state <= IDLE;
                    end else if ((exp_A == 8'hFF && A_reg[22:0] == 0) || 
                                 (exp_B == 8'hFF && B_reg[22:0] == 0)) begin
                        Result <= {sign_A ^ sign_B, 8'hFF, 23'd0}; // Infinity
                        special_case <= 1'b1;
                        state <= IDLE;
                    end else begin
                        special_case <= 1'b0;
                        state <= STAGE2;
                    end
                end

                STAGE2: begin
                    mantissa_mult <= mant_A * mant_B;
                    exp_sum <= exp_A + exp_B - 8'd127;
                    sign_result <= sign_A ^ sign_B;
                    state <= STAGE3;
                end

                STAGE3: begin
                    if (exp_sum >= 10'd255) begin
                        final_exp <= 8'hFF;
                        final_mantissa <= 23'd0;
                    end else if (exp_sum <= 0) begin
                        final_exp <= 8'h00;
                        final_mantissa <= 23'd0;
                    end else begin
                        if (mantissa_mult[47]) begin
                            final_exp <= exp_sum[7:0] + 1;
                            final_mantissa <= mantissa_mult[46:24];
                        end else begin
                            final_exp <= exp_sum[7:0];
                            final_mantissa <= mantissa_mult[45:23];
                        end
                    end

                    Result <= {sign_result, final_exp, final_mantissa};
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

//-------------------------------------------
// Interface for DUT connection
//---------------------------------------------------
interface fp_if;
  logic clk;
  logic reset;
  logic [31:0] A, B;
  logic [31:0] Result;
endinterface
