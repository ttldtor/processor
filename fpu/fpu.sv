/*
 * Floating point processing unit.
 *
 * Author: Aleksandr Novozhilov
 * Creating date: 2018-02-12
 *
 */

`define COMMAND_SIZE 1

//`define EXP_BINTESS(bintess) bitness == 256? 19: bitness == 128? 15: bitness == 64? 11: bitness == 32? 8: 5
`define EXP_BINTESS(bintess) 8
//`define MANT_BITNESS(bitness) bitness == 256? 237: bitness == 128? 113: bitness == 64? 53: bitness == 32? 24: 11
`define MANT_BITNESS(bitness) 23

`define BIASED_EXPONENT_COEFF(bitness) (2 ** `EXP_BINTESS(bitness) - 1) - 1

module fpu
        #(parameter bitness=32)
(
        input clock,
        input reset,

        input  input_rdy,
        output input_ack,

        output output_rdy,
        input  output_ack,

        input [bitness - 1:0] data_a,
        input [bitness - 1:0] data_b,

        input [3:0] command,

        output [bitness - 1:0] result
);
        enum reg[3:0] {
                        unpack     = 4'b0000
                      , pack       = 4'b0001
                      , align      = 4'b0010
                      , normalize  = 4'b0011
                      , add_0      = 4'b0100
                      , add_1      = 4'b0101
                      , sub        = 4'b0110
                      , mul        = 4'b0111
                      , div        = 4'b1000
                      , put_result = 4'b1001
                      , get_input  = 4'b1010
              } state;

        reg [bitness - 1:0]   s_result
                            , s_out_result;
        reg  s_output_rdy
            ,s_input_ack;

        reg [bitness - 1:0]  s_data_a
                            ,s_data_b;

        reg   data_a_sign
            , data_b_sign
            , result_sign;

        reg[`EXP_BINTESS(bitness) - 1:0]   data_a_exp
                                         , data_b_exp
                                         , result_exp;

        // Inner mantissa with hidden bit.
        reg[`MANT_BITNESS(bitness):0]   data_a_mantissa
                                      , data_b_mantissa
                                      , result_mantissa;


        always @(posedge clock) begin
                if (reset) begin
                        state        <= get_input;
                        s_output_rdy <= 0;
                        s_input_ack  <= 0;
                end

                case(state)
                        get_input: begin
                                if (input_rdy) begin
                                        s_data_a <= data_a;
                                        s_data_b <= data_b;

                                        s_input_ack <= 1;

                                        state <= unpack;
                                end
                        end

                        unpack: begin
                                data_a_mantissa <= {1'b1, s_data_a[`MANT_BITNESS(bitness) - 1:0]};
                                data_a_exp      <= s_data_a[bitness - 2: `MANT_BITNESS(bitness)] - 127;//`BIASED_EXPONENT_COEFF(bitness);
                                data_a_sign     <= s_data_a[bitness - 1];

                                data_b_mantissa <= {1'b1, s_data_b[`MANT_BITNESS(bitness) - 1:0]};
                                data_b_exp      <= s_data_b[bitness - 2: `MANT_BITNESS(bitness)] - 127;//`BIASED_EXPONENT_COEFF(bitness);
                                data_b_sign     <= s_data_b[bitness - 1];

                                // TODO: state here must change according input command like add, multiply, substract, etc...
                                state <= align;

                        end

                        align: begin
                                $display("A: %b %b %b", data_a_sign, data_a_exp, data_a_mantissa);
                                $display("B: %b %b %b", data_b_sign, data_b_exp, data_b_mantissa);
                                $display("%b", s_data_a);
                                if ($signed(data_a_exp) > $signed(data_b_exp)) begin
                                        data_b_exp         <= data_b_exp + 1;
                                        data_b_mantissa    <= data_b_mantissa >> 1;
                                        data_b_mantissa[0] <= data_b_mantissa[0] | data_b_mantissa[1];
                                end
                                else if ($signed(data_a_exp) < $signed(data_b_exp)) begin
                                        data_a_exp <= data_a_exp + 1;
                                        data_a_mantissa <= data_a_mantissa >> 1;
                                        data_a_mantissa[0] <= data_a_mantissa[0] | data_a_mantissa[1];
                                end
                                else begin
                                        state <= add_0;
                                end
                        end

                        add_0: begin
                                result_exp <= data_a_exp;
                                if (data_a_sign == data_b_sign) begin
                                        result_sign     <= data_a_sign;
                                        result_mantissa <= data_a_mantissa + data_b_mantissa;
                                end
                                else
                                if (data_a_mantissa > data_b_mantissa) begin
                                        result_sign     <= data_a_sign;
                                        result_mantissa <= data_a_mantissa - data_b_mantissa;
                                end
                                else if (data_a_mantissa < data_b_mantissa) begin
                                        result_sign     <= data_b_sign;
                                        result_mantissa <= data_b_mantissa - data_a_mantissa;
                                end
                                state <= normalize;
                        end

                        normalize: begin
                                $display("    %b %b", data_a_mantissa, data_b_mantissa);
                                $display(";;  %b", result_mantissa);
                                $display("sum %b", data_a_mantissa + data_b_mantissa);
                                $display("::  %b", result_mantissa[`MANT_BITNESS(bitness) - 1]);
                                $display("State: %b", state);
                                if (result_mantissa[`MANT_BITNESS(bitness) - 1] == 0 && $signed(result_exp) > -126) begin
                                        //result_exp <= result_exp - 1;
                                        result_mantissa <= result_mantissa << 1;
                                end
                                state <= pack;
                        end

                        pack: begin
                                $display("RESULT: %b %b %b", result_sign, result_exp, result_mantissa[23:0]);

                                // Packing result, work is done
                                //s_result[bitness - 1]                             <= result_sign;
                                //s_result[bitness - 2: `MANT_BITNESS(bitness)] <= result_exp;// + `BIASED_EXPONENT_COEFF(bitness);
                                //s_result[`MANT_BITNESS(bitness) - 1:0]            <= result_mantissa[`MANT_BITNESS(bitness) - 1:0];
                                //s_result[`MANT_BITNESS(bitness) - 1:0]            <= result_mantissa[23:0];
                                s_result[31] <= 0;
                                s_result[30:23] <= 8'b01111111;
                                s_result[22:0] <= 23'b00011001100110011001100;

                                //if ($signed(result_exp) == -126 && result_mantissa[23:0] == 0) begin
                                //        s_result[bitness - 2: `MANT_BITNESS(bitness) - 1] <= 0;
                                //end

                                state <= put_result;
                        end

                        put_result: begin
                                s_out_result <= s_result;
                                s_output_rdy <= 1;

                                if (s_output_rdy && output_ack) begin
                                        s_output_rdy <= 0;
                                        state        <= get_input;
                                end
                        end

                endcase
        end

        assign result     = s_result;
        assign output_rdy = s_output_rdy;
        assign input_ack  = s_input_ack;

endmodule
