`timescale 1ns / 1ps
module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    logic [1:0] state_reg, state_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    // state SL
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= 0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_data_reg    <= 0;
            rx_done_reg    <= 0;
        end else begin
            state_reg      <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_data_reg    <= rx_data_next;
            rx_done_reg    <= rx_done_next;
        end
    end

    // next CL
    always_comb begin
        state_next      = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_data_next    = rx_data_reg;
        rx_done_next    = rx_done_reg;
        case (state_reg)
            IDLE: begin
                rx_done_next = 0;
                if (!rx) begin
                    state_next = START;
                end
                // if (b_tick) begin
                // end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        state_next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_data_next = {rx, rx_data_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        b_tick_cnt_next = 0;
                        rx_done_next = 1;
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
