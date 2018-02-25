/* Add testing bench
 *
 * Author: Aleksandr Novozhilov
 * Date: 2018-02-09
 */


`define TEST_MESSAGE(condition, name) $display("Test \"%s\": %s", name, (condition? "ok" : "failed"));


module add_tb();

        reg clock, reset, input_rdy, output_rdy;

        reg [31:0] left, right;

        wire [31:0] result;

        reg [3:0] command;

        wire input_ack;
        reg output_ack;

        fpu DUT (
                .command(command),
                .clock(clock),
                .reset(reset),
                .data_a(left),
                .data_b(right),
                .output_rdy(output_rdy),
                .output_ack(output_ack),
                .input_rdy(input_rdy),
                .input_ack(input_ack),
                .result(result));

        initial begin
                left = 32'b0_01111111_00000000000000000000000;
                right= 32'b0_01111011_10011001100110011001101;
                    //    b0_01111111_00011001100110011001101
                    //               110011001100110011001101
                    //               011001100110011001100110   1
                    //               001100110011001100110011   2
                    //               000110011001100110011001   3
                    //               000011001100110011001100   4
                //`TEST_MESSAGE(result === left, "summ 1")
                reset = 1'b1;
                input_rdy = 1;
                clock = 1;
                #5;
                reset = 0;
                while(1) begin
                        #1; 
                        clock = ~clock;
                        //$display("Done? %b", output_rdy);
                        if (output_rdy && input_ack) begin
                                $display("   Done! %b %b %b %b %h AND %b", output_rdy, clock, reset, result, result, result == 32'b0_01111111_00011001100110011001101);
                                #1;
                                output_ack <= 1;
                                $finish;
                        end
                        //$display("------");
                end
        end

        initial begin
                #50 $finish;
        end

endmodule
