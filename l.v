`timescale 1ns / 1ps
module ReciprocalLUT (
    input [31:0] d,       // IEEE 754 Floating Point Input
    output reg [31:0] f0  // Output: Approximate 1/d
);

    reg [4:0] lut_index;      // LUT index (5 bits for 32 entries)
    reg [31:0] lut [0:31];    // 32-entry LUT for 1/2^n values
    wire [7:0] exponent;      // Extracted exponent from FP number
    wire is_nan, is_inf, is_zero, sign_bit;

    // Initialize LUT with 1/2^n values
    initial begin
        lut[0]  = 32'h3F800000; // 1.0
        lut[1]  = 32'h3F000000; // 0.5
        lut[2]  = 32'h3E800000; // 0.25
        lut[3]  = 32'h3E000000; // 0.125
        lut[4]  = 32'h3D800000; // 0.0625
        lut[5]  = 32'h3D000000; // 0.03125
        lut[6]  = 32'h3C800000; // 0.015625
        lut[7]  = 32'h3C000000; // 0.0078125
        lut[8]  = 32'h3B800000; // 0.00390625
        lut[9]  = 32'h3B000000; // 0.001953125
        lut[10] = 32'h3A800000; // 0.0009765625
        lut[11] = 32'h3A000000; // 0.00048828125
        lut[12] = 32'h39800000; // 0.000244140625
        lut[13] = 32'h39000000; // 0.0001220703125
        lut[14] = 32'h38800000; // 0.00006103515625
        lut[15] = 32'h38000000; // 0.000030517578125
        lut[16] = 32'h37800000; // 0.0000152587890625
        lut[17] = 32'h37000000; // 0.00000762939453125
        lut[18] = 32'h36800000; // 0.000003814697265625
        lut[19] = 32'h36000000; // 0.0000019073486328125
        lut[20] = 32'h35800000; // 0.00000095367431640625
        lut[21] = 32'h35000000; // 0.000000476837158203125
        lut[22] = 32'h34800000; // 0.0000002384185791015625
        lut[23] = 32'h34000000; // 0.00000011920928955078125
        lut[24] = 32'h33800000; // 0.000000059604644775390625
        lut[25] = 32'h33000000; // 0.0000000298023223876953125
        lut[26] = 32'h32800000; // 0.00000001490116119384765625
        lut[27] = 32'h32000000; // 0.000000007450580596923828125
        lut[28] = 32'h31800000; // 0.0000000037252902984619140625
        lut[29] = 32'h31000000; // 0.00000000186264514923095703125
        lut[30] = 32'h30800000; // 0.000000000931322574615478515625
        lut[31] = 32'h30000000; // 0.0000000004656612873077392578125
    end

    assign exponent = d[30:23];
    assign sign_bit = d[31];

    assign is_zero = (d == 32'h00000000);
    assign is_inf  = (exponent == 8'hFF) && (d[22:0] == 0);
    assign is_nan  = (exponent == 8'hFF) && (d[22:0] != 0);

    always @(*) begin
        if (is_zero) begin
            f0 = 32'h7F800000; // Return Infinity for zero
        end else if (is_inf) begin
            f0 = 32'h00000000; // Return 0 for Infinity
        end else if (is_nan) begin
            f0 = 32'h7FC00000; // Return NaN for NaN input
        end else begin
            // Calculate LUT index
            if (exponent < 8'd127)
                lut_index = 5'd0;
            else if (exponent > 8'd158)
                lut_index = 5'd31;
            else
                lut_index = exponent - 8'd127;

            f0 = lut[lut_index];

            // Apply sign (negate for negative input)
            if (sign_bit) begin
                f0 = {1'b1, f0[30:0]};
            end
        end
    end

endmodule
