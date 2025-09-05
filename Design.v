// i2c_master.v
`timescale 1ns / 1ps

module i2c_master #(
    parameter CLK_FREQ = 50_000_000,   // 50 MHz
    parameter I2C_FREQ = 100_000       // 100 KHz
)(
    input  wire        clk,
    input  wire        rst_n,

    // User Interface
    input  wire        start_req,       // Request to start a transaction
    input  wire [6:0]  slave_addr,      // 7-bit slave address
    input  wire        rw_bit,          // 0 for write, 1 for read
    input  wire [7:0]  data_in,         // Data to write
    output wire        busy,            // High when transaction is in progress
    output wire        ack_error,       // High if an ACK is not received
    output wire        done,            // High for one clock cycle when transaction is complete

    // I2C Bus Interface
    inout  wire        scl,
    inout  wire        sda
);

    // Internal Signals
    reg   [2:0]     state;
    reg   [7:0]     tx_data;
    reg   [3:0]     bit_counter;
    reg             scl_reg;
    reg             sda_reg;
    reg             ack_err_reg;
    reg             busy_reg;
    reg             done_reg;

    // FSM States
    localparam S_IDLE       = 3'b000;
    localparam S_START      = 3'b001;
    localparam S_ADDR       = 3'b010;
    localparam S_ACK_ADDR   = 3'b011;
    localparam S_DATA       = 3'b100;
    localparam S_ACK_DATA   = 3'b101;
    localparam S_STOP       = 3'b110;

    // I2C Clock Generation
    localparam I2C_HALF_PERIOD = (CLK_FREQ / (2 * I2C_FREQ));
    reg [15:0] sclk_counter = 0;
    wire       scl_toggle = (sclk_counter == (I2C_HALF_PERIOD - 1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_counter <= 0;
            scl_reg <= 1'b1;
        end else if (scl_toggle) begin
            sclk_counter <= 0;
            scl_reg <= ~scl_reg;
        end else begin
            sclk_counter <= sclk_counter + 1'b1;
        end
    end

    // I2C Bus control logic
    assign scl = scl_reg ? 1'bz : 1'b0;  // Open-drain output
    assign sda = sda_reg ? 1'bz : 1'b0;  // Open-drain output

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            tx_data <= 8'b0;
            bit_counter <= 4'b0;
            sda_reg <= 1'b1;
            busy_reg <= 1'b0;
            ack_err_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            done_reg <= 1'b0; // Default to low

            case (state)
                S_IDLE: begin
                    busy_reg <= 1'b0;
                    ack_err_reg <= 1'b0;
                    sda_reg <= 1'b1;
                    if (start_req && !busy_reg) begin
                        state <= S_START;
                        busy_reg <= 1'b1;
                        tx_data <= {slave_addr, rw_bit};
                    end
                end

                S_START: begin
                    // SCL high, pull SDA low
                    if (scl_toggle && scl_reg == 1) begin
                        sda_reg <= 1'b0;
                        state <= S_ADDR;
                        bit_counter <= 7;
                    end
                end

                S_ADDR: begin
                    if (scl_toggle && scl_reg == 0) begin
                        // Put data on SDA when SCL is low
                        sda_reg <= tx_data[bit_counter];
                    end else if (scl_toggle && scl_reg == 1) begin
                        if (bit_counter == 0) begin
                            state <= S_ACK_ADDR;
                        end else begin
                            bit_counter <= bit_counter - 1;
                        end
                    end
                end

                S_ACK_ADDR: begin
                    if (scl_toggle && scl_reg == 0) begin
                        // Release SDA for slave ACK
                        sda_reg <= 1'b1;
                    end else if (scl_toggle && scl_reg == 1) begin
                        // Check for ACK from slave
                        if (sda == 1'b1) begin
                            ack_err_reg <= 1'b1;
                            state <= S_STOP;
                        end else begin
                            state <= S_DATA;
                            tx_data <= data_in;
                            bit_counter <= 7;
                        end
                    end
                end

                S_DATA: begin
                    if (scl_toggle && scl_reg == 0) begin
                        // Put data on SDA when SCL is low
                        sda_reg <= tx_data[bit_counter];
                    end else if (scl_toggle && scl_reg == 1) begin
                        if (bit_counter == 0) begin
                            state <= S_ACK_DATA;
                        end else begin
                            bit_counter <= bit_counter - 1;
                        end
                    end
                end

                S_ACK_DATA: begin
                    if (scl_toggle && scl_reg == 0) begin
                        // Release SDA for slave ACK
                        sda_reg <= 1'b1;
                    end else if (scl_toggle && scl_reg == 1) begin
                        // Check for ACK from slave
                        if (sda == 1'b1) begin
                            ack_err_reg <= 1'b1;
                        end
                        state <= S_STOP;
                    end
                end

                S_STOP: begin
                    // SCL high, pull SDA low, then SCL low, pull SDA high
                    if (scl_toggle && scl_reg == 1) begin
                        sda_reg <= 1'b0;
                    end else if (scl_toggle && scl_reg == 0) begin
                        sda_reg <= 1'b1;
                        state <= S_IDLE;
                        done_reg <= 1'b1; // Transaction is complete
                    end
                end
            endcase
        end
    end

    // Assign outputs
    assign busy = busy_reg;
    assign ack_error = ack_err_reg;
    assign done = done_reg;

endmodule

// i2c_slave.v
`timescale 1ns / 1ps

module i2c_slave #(
    parameter SLAVE_ADDR = 7'b0110100
)(
    input  wire  clk,
    inout  wire  scl,
    inout  wire  sda
);

    reg [7:0]   rx_data;
    reg         sda_out_en;
    reg         sda_out;
    reg [3:0]   bit_counter;
    reg         slave_ack;
    reg [2:0]   state;

    // FSM States
    localparam S_IDLE       = 3'b000;
    localparam S_ADDR       = 3'b001;
    localparam S_ACK_ADDR   = 3'b010;
    localparam S_DATA       = 3'b011;
    localparam S_ACK_DATA   = 3'b100;
    localparam S_STOP       = 3'b101;

    assign sda = sda_out_en ? (sda_out ? 1'bz : 1'b0) : 1'bz;

    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                // Wait for a START condition (SCL high, SDA falls)
                if (scl == 1'b1 && sda == 1'b0) begin
                    state <= S_ADDR;
                    bit_counter <= 7;
                end
            end
            S_ADDR: begin
                // Read address byte
                if (scl == 1'b0) begin // Read on falling edge
                    rx_data[bit_counter] <= sda;
                    if (bit_counter == 0) begin
                        state <= S_ACK_ADDR;
                    end else begin
                        bit_counter <= bit_counter - 1;
                    end
                end
            end
            S_ACK_ADDR: begin
                // Check if address matches and send ACK
                if (scl == 1'b0) begin
                    if (rx_data[7:1] == SLAVE_ADDR && rx_data[0] == 0) begin
                        sda_out_en <= 1'b1; // Enable output
                        sda_out <= 1'b0;    // Send ACK (low)
                        slave_ack <= 1'b0;
                    end else begin
                        sda_out_en <= 1'b1;
                        sda_out <= 1'b1;
                        slave_ack <= 1'b1;
                    end
                    state <= S_DATA;
                    bit_counter <= 7;
                end
            end
            S_DATA: begin
                // Read data byte
                if (scl == 1'b0) begin
                    rx_data[bit_counter] <= sda;
                    if (bit_counter == 0) begin
                        state <= S_ACK_DATA;
                    end else begin
                        bit_counter <= bit_counter - 1;
                    end
                end
            end
            S_ACK_DATA: begin
                if (scl == 1'b0) begin
                    sda_out_en <= 1'b1;
                    sda_out <= 1'b0; // Always ACK data for this simple model
                    state <= S_STOP;
                end
            end
            S_STOP: begin
                // Wait for a STOP condition (SDA rising while SCL high)
                sda_out_en <= 1'b0; // Release SDA
                if (scl == 1'b1 && sda == 1'b1) begin
                    state <= S_IDLE;
                end
            end
        endcase
    end

endmodule

