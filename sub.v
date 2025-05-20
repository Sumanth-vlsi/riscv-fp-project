module fp_add_sub (
    input clk,
    input reset,
    input [31:0] a,
    input [31:0] b,
    input [1:0] op_mode,  // 00 for addition, 01 for subtraction
    output reg [31:0] result
);

    reg sign_a, sign_b, sign_res;
    reg [7:0] exp_a, exp_b, exp_res;
    reg [23:0] mant_a, mant_b;
    reg [24:0] mant_x, mant_y, mant_res;
    reg [7:0] exp_diff;
    reg [4:0] shift_count;

    // Special case flags
    wire a_is_zero = (a[30:23] == 8'd0) && (a[22:0] == 0);
    wire b_is_zero = (b[30:23] == 8'd0) && (b[22:0] == 0);
    wire a_is_inf  = (a[30:23] == 8'hFF) && (a[22:0] == 0);
    wire b_is_inf  = (b[30:23] == 8'hFF) && (b[22:0] == 0);
    wire a_is_nan  = (a[30:23] == 8'hFF) && (a[22:0] != 0);
    wire b_is_nan  = (b[30:23] == 8'hFF) && (b[22:0] != 0);
    wire same_operands = (a == b);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result <= 32'b0;
        end else begin

            // ===== Special case handling =====
            if (a_is_nan || b_is_nan) begin
                result <= 32'h7FC00000; // Quiet NaN
            end else if (a_is_inf && b_is_inf && op_mode == 2'b01 && a[31] != b[31]) begin
                result <= 32'h7FC00000; // INF - INF = NaN
            end else if (a_is_inf) begin
                result <= a;
            end else if (b_is_inf) begin
                result <= (op_mode == 2'b00) ? b : {~b[31], b[30:0]};
            end else if (a_is_zero && b_is_zero) begin
                result <= 32'h00000000; // 0 + 0 or 0 - 0 = 0
            end else if (a_is_zero) begin
                result <= (op_mode == 2'b00) ? b : {~b[31], b[30:0]};
            end else if (b_is_zero) begin
                result <= a;
            end else if (op_mode == 2'b01 && same_operands) begin
                result <= 32'h00000000; // x - x = 0
            end else begin
                // ===== Normal flow =====

                // Extract fields
                sign_a <= a[31];
                sign_b <= b[31] ^ (op_mode == 2'b01); // Flip sign for subtraction
                exp_a <= a[30:23];
                exp_b <= b[30:23];
                mant_a <= (exp_a == 0) ? {1'b0, a[22:0]} : {1'b1, a[22:0]};
                mant_b <= (exp_b == 0) ? {1'b0, b[22:0]} : {1'b1, b[22:0]};

                // Align exponents
                if (exp_a > exp_b) begin
                    exp_diff = exp_a - exp_b;
                    mant_x = mant_a;
                    mant_y = mant_b >> exp_diff;
                    exp_res = exp_a;
                end else begin
                    exp_diff = exp_b - exp_a;
                    mant_x = mant_a >> exp_diff;
                    mant_y = mant_b;
                    exp_res = exp_b;
                end

                // Perform operation
                if (sign_a == sign_b) begin
                    mant_res = mant_x + mant_y;
                    sign_res = sign_a;
                end else begin
                    if (mant_x >= mant_y) begin
                        mant_res = mant_x - mant_y;
                        sign_res = sign_a;
                    end else begin
                        mant_res = mant_y - mant_x;
                        sign_res = sign_b;
                    end
                end

                // Normalize result
                if (mant_res[24]) begin
                    mant_res = mant_res >> 1;
                    exp_res = exp_res + 1;
                end else begin
                    shift_count = 0;
                    while (!mant_res[23] && exp_res > 0 && shift_count < 23) begin
                        mant_res = mant_res << 1;
                        exp_res = exp_res - 1;
                        shift_count = shift_count + 1;
                    end
                end

                // Handle underflow/overflow
                if (exp_res == 8'hFF) begin
                    result <= {sign_res, 8'hFF, 23'b0}; // Infinity
                end else if (mant_res[23:0] == 0) begin
                    result <= {sign_res, 8'b0, 23'b0};  // Zero
                end else begin
                    result <= {sign_res, exp_res, mant_res[22:0]}; // Normal result
                end
            end
        end
    end
endmodule
