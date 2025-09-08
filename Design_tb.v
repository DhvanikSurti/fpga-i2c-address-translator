`timescale 1ns / 1ps
module i2c_tb;

    localparam CLK_FREQ=50_000_000;
    localparam I2C_FREQ=100_000;
    localparam CLK_PERIOD=1_000_000_000/CLK_FREQ;

    reg clk;
    reg rst_n;
    reg start_req_reg;
    reg [6:0] slave_addr;
    reg rw_bit;
    reg [7:0] data_in;
    wire busy;
    wire ack_error;
    wire done;
    wire scl;
    wire sda;

    i2c_master #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start_req(start_req_reg),
        .slave_addr(slave_addr),
        .rw_bit(rw_bit),
        .data_in(data_in),
        .busy(busy),
        .ack_error(ack_error),
        .done(done),
        .scl(scl),
        .sda(sda)
    );

    i2c_slave #(
        .SLAVE_ADDR(7'b0110100)
    ) slave_inst (
        .clk(clk),
        .scl(scl),
        .sda(sda)
    );

    initial begin
        clk=0;
        forever #(CLK_PERIOD/2) clk=~clk;
    end

    initial begin
        $dumpfile("i2c_dump.vcd");
        $dumpvars(0,i2c_tb);
        rst_n=0;
        start_req_reg=0;
        slave_addr=7'b0110100;
        rw_bit=0;
        data_in=8'hAA;
        #100;
        rst_n=1;
        #200;
        start_req_reg=1;
        @(posedge done);
        $display("Transaction done!");
        $display("ACK Error: %b",ack_error);
        #100;
        $finish;
    end
endmodule
