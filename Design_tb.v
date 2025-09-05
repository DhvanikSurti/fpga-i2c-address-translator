// i2c_tb.v
`timescale 1ns / 1ps

module i2c_tb;

    // Parameters
    localparam CLK_FREQ   = 50_000_000; // 50 MHz
    localparam I2C_FREQ   = 100_000;    // 100 KHz
    localparam CLK_PERIOD = 1_000_000_000 / CLK_FREQ;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    wire        start_req;
    reg         start_req_reg;
    reg  [6:0]  slave_addr;
    reg         rw_bit;
    reg  [7:0]  data_in;
    wire        busy;
    wire        ack_error;
    wire        done;
    wire        scl;
    wire        sda;
    reg         scl_drive, sda_drive;

    // Bidirectional bus model
    wire scl_master_out, scl_slave_out;
    wire sda_master_out, sda_slave_out;

    assign scl = scl_master_out & scl_slave_out;
    assign sda = sda_master_out & sda_slave_out;

    // Instantiate I2C Master
    i2c_master #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    ) master_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .start_req  (start_req_reg),
        .slave_addr (slave_addr),
        .rw_bit     (rw_bit),
        .data_in    (data_in),
        .busy       (busy),
        .ack_error  (ack_error),
        .done       (done),
        .scl        (scl),
        .sda        (sda)
    );

    // Instantiate I2C Slave
    i2c_slave #(
        .SLAVE_ADDR(7'b0110100)
    ) slave_inst (
        .clk        (clk),
        .scl        (scl),
        .sda        (sda)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Testbench Stimulus
    initial begin
        // Dump VCD file for waveform viewing
        $dumpfile("i2c_dump.vcd");
        $dumpvars(0, i2c_tb);

        // Initial values
        rst_n       = 0;
        start_req_reg = 0;
        slave_addr  = 7'b0110100;
        rw_bit      = 0;  // Write operation
        data_in     = 8'hAA;

        // Reset the design
        #100;
        rst_n = 1;

        // Start a transaction
        #200;
        start_req_reg = 1;

        // Wait for the transaction to complete
        @(posedge done);
        $display("Transaction done!");
        $display("ACK Error: %b", ack_error);

        // End simulation
        #100;
        $finish;
    end
endmodule