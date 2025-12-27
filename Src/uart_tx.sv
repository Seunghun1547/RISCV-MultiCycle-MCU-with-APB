`timescale 1ns / 1ps
module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       b_tick,
    input  logic       start_trig,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    logic [1:0] state_reg, state_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic tx_busy_reg, tx_busy_next;
    logic tx_reg, tx_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_buf_reg   <= 0;
            tx_busy_reg    <= 0;
            tx_reg         <= 1;
        end else begin
            state_reg      <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_buf_reg   <= data_buf_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
        end
    end

    always_comb begin
        state_next      = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_buf_next   = data_buf_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        case (state_reg)
            IDLE: begin
                tx_next      = 1;
                tx_busy_next = 0;
                if (start_trig) begin
                    data_buf_next = tx_data;
                    state_next    = START;
                end
            end
            START: begin
                tx_next      = 0;
                tx_busy_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        state_next      = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = STOP;
                        end else begin
                            bit_cnt_next  = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        state_next      = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
