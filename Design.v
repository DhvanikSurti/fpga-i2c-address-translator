`timescale 1ns/1ps
module i2c_master #(
    parameter CLK_FREQ = 50_000_000,
    parameter I2C_FREQ = 100_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start_req,
    input  wire [6:0] slave_addr,
    input  wire rw_bit,
    input  wire [7:0] data_in,
    output wire busy,
    output wire ack_error,
    output wire done,
    inout  wire scl,
    inout  wire sda
);

    reg [2:0] state;
    reg [7:0] tx_data;
    reg [3:0] bit_counter;
    reg scl_reg, sda_reg;
    reg ack_err_reg, busy_reg, done_reg;

    localparam S_IDLE=3'b000, S_START=3'b001, S_ADDR=3'b010,
               S_ACK_ADDR=3'b011, S_DATA=3'b100,
               S_ACK_DATA=3'b101, S_STOP=3'b110;

    localparam I2C_HALF = (CLK_FREQ/(2*I2C_FREQ));
    reg [15:0] clk_cnt=0;
    wire scl_toggle = (clk_cnt==(I2C_HALF-1));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            clk_cnt<=0; scl_reg<=1'b1;
        end else if(scl_toggle) begin
            clk_cnt<=0; scl_reg<=~scl_reg;
        end else begin
            clk_cnt<=clk_cnt+1'b1;
        end
    end

    assign scl = scl_reg ? 1'bz : 1'b0;
    assign sda = sda_reg ? 1'bz : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=S_IDLE; tx_data<=0; bit_counter<=0;
            sda_reg<=1; busy_reg<=0; ack_err_reg<=0; done_reg<=0;
        end else begin
            done_reg<=0;
            case(state)
                S_IDLE: begin
                    busy_reg<=0; ack_err_reg<=0; sda_reg<=1;
                    if(start_req && !busy_reg) begin
                        state<=S_START; busy_reg<=1;
                        tx_data<={slave_addr,rw_bit};
                    end
                end
                S_START: if(scl_toggle && scl_reg==1) begin
                    sda_reg<=0; state<=S_ADDR; bit_counter<=7;
                end
                S_ADDR: begin
                    if(scl_toggle && scl_reg==0) sda_reg<=tx_data[bit_counter];
                    else if(scl_toggle && scl_reg==1) begin
                        if(bit_counter==0) state<=S_ACK_ADDR;
                        else bit_counter<=bit_counter-1;
                    end
                end
                S_ACK_ADDR: begin
                    if(scl_toggle && scl_reg==0) sda_reg<=1;
                    else if(scl_toggle && scl_reg==1) begin
                        if(sda==1) begin
                            ack_err_reg<=1; state<=S_STOP;
                        end else begin
                            state<=S_DATA; tx_data<=data_in; bit_counter<=7;
                        end
                    end
                end
                S_DATA: begin
                    if(scl_toggle && scl_reg==0) sda_reg<=tx_data[bit_counter];
                    else if(scl_toggle && scl_reg==1) begin
                        if(bit_counter==0) state<=S_ACK_DATA;
                        else bit_counter<=bit_counter-1;
                    end
                end
                S_ACK_DATA: begin
                    if(scl_toggle && scl_reg==0) sda_reg<=1;
                    else if(scl_toggle && scl_reg==1) begin
                        if(sda==1) ack_err_reg<=1;
                        state<=S_STOP;
                    end
                end
                S_STOP: begin
                    if(scl_toggle && scl_reg==1) sda_reg<=0;
                    else if(scl_toggle && scl_reg==0) begin
                        sda_reg<=1; state<=S_IDLE; done_reg<=1;
                    end
                end
            endcase
        end
    end

    assign busy=busy_reg;
    assign ack_error=ack_err_reg;
    assign done=done_reg;
endmodule



`timescale 1ns/1ps
module i2c_slave #(parameter SLAVE_ADDR=7'b0110100)(
    input  wire clk,
    inout  wire scl,
    inout  wire sda
);

    reg [7:0] rx_data;
    reg sda_out_en, sda_out;
    reg [3:0] bit_counter;
    reg [2:0] state;

    localparam S_IDLE=3'b000, S_ADDR=3'b001, S_ACK_ADDR=3'b010,
               S_DATA=3'b011, S_ACK_DATA=3'b100, S_STOP=3'b101;

    assign sda = sda_out_en ? (sda_out?1'bz:1'b0) : 1'bz;

    always @(posedge clk) begin
        case(state)
            S_IDLE: if(scl==1 && sda==0) begin
                state<=S_ADDR; bit_counter<=7;
            end
            S_ADDR: if(scl==0) begin
                rx_data[bit_counter]<=sda;
                if(bit_counter==0) state<=S_ACK_ADDR;
                else bit_counter<=bit_counter-1;
            end
            S_ACK_ADDR: if(scl==0) begin
                if(rx_data[7:1]==SLAVE_ADDR && rx_data[0]==0) begin
                    sda_out_en<=1; sda_out<=0;
                end else begin
                    sda_out_en<=1; sda_out<=1;
                end
                state<=S_DATA; bit_counter<=7;
            end
            S_DATA: if(scl==0) begin
                rx_data[bit_counter]<=sda;
                if(bit_counter==0) state<=S_ACK_DATA;
                else bit_counter<=bit_counter-1;
            end
            S_ACK_DATA: if(scl==0) begin
                sda_out_en<=1; sda_out<=0;
                state<=S_STOP;
            end
            S_STOP: begin
                sda_out_en<=0;
                if(scl==1 && sda==1) state<=S_IDLE;
            end
        endcase
    end
endmodule
