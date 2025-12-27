`timescale 1ns / 1ps

module UART_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // External Port
    output logic        tx,
    input  logic        rx,
    output logic [ 7:0] rx_data_led
);

    logic [7:0] rx_data_reg;
    
    assign rx_data_led = rx_data_reg;

    logic       tx_push;
    logic [7:0] tx_push_data;
    logic       tx_fifo_full;
    logic       rx_pop;
    logic [7:0] rx_pop_data;
    logic       rx_fifo_empty;
    logic       tx_busy;

    APB_SlaveIntf_UART U_APB_SlaveIntf_UART (.*);
    UART U_UART (
        .*,
        .clk(PCLK),
        .rst(PRESET)
    );

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) rx_data_reg <= 8'h00;
        else if (rx_pop) rx_data_reg <= rx_pop_data;
    end

endmodule

module APB_SlaveIntf_UART (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // Internal Port
    output logic        tx_push,
    output logic [ 7:0] tx_push_data,
    input  logic        tx_fifo_full,
    output logic        rx_pop,
    input  logic [ 7:0] rx_pop_data,
    input  logic        rx_fifo_empty,
    input  logic        tx_busy

);
    logic [31:0] uart_status, uart_ctrl, tx_data_reg, rx_data_reg;

    // uart control
    // assign tx_push = uart_ctrl[0];
    // assign rx_pop = uart_ctrl[1];
    // uart input data
    assign tx_push_data = tx_data_reg[7:0];
    logic tx_push_armed;
    logic rx_pop_armed;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            uart_status   <= 0;
            uart_ctrl     <= 0;
            tx_data_reg   <= 0;
            rx_data_reg   <= 0;
            tx_push       <= 0;
            rx_pop        <= 0;
            tx_push_armed <= 1'b1;
            rx_pop_armed  <= 1'b1;
        end else begin
            PREADY  <= 1'b0;
            tx_push <= 0;
            rx_pop  <= 0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: ;
                        2'd1: begin
                            uart_ctrl <= PWDATA;
                            if (PWDATA[0] && tx_push_armed) begin
                                tx_push <= 1'b1;
                                tx_push_armed <= 1'b0;
                            end
                            if (PWDATA[1] && rx_pop_armed) begin
                                rx_pop       <= 1'b1;
                                rx_pop_armed <= 1'b0;
                                rx_data_reg  <= {24'b0, rx_pop_data};
                            end
                        end
                        2'd2: begin
                            tx_data_reg   <= PWDATA;
                            tx_push_armed <= 1'b1;
                            rx_pop_armed  <= 1'b1;
                        end
                        2'd3: ;
                    endcase
                end else begin
                    uart_ctrl <= 0;
                    case (PADDR[3:2])
                        2'd0: begin
                            uart_status <= {
                                29'b0, tx_fifo_full, rx_fifo_empty, tx_busy
                            };
                            PRDATA <= uart_status;
                        end
                        2'd1: ;
                        2'd2: ;
                        2'd3: PRDATA <= rx_data_reg;
                    endcase
                end
            end
        end
    end
endmodule

module UART (
    // global signals
    input  logic       clk,
    input  logic       rst,
    // external port
    output logic       tx,
    input  logic       rx,
    // inf to uart
    input  logic       tx_push,
    input  logic [7:0] tx_push_data,
    output logic       tx_fifo_full,
    //uart to inf
    input  logic       rx_pop,
    output logic [7:0] rx_pop_data,
    output logic       rx_fifo_empty,
    //status
    output logic       tx_busy
);

    logic       b_tick;

    // TX FIFO signals
    logic       tx_fifo_wr;
    logic       tx_fifo_rd;
    logic [7:0] tx_fifo_wdata;
    logic [7:0] tx_fifo_rdata;
    logic       tx_fifo_empty;
    logic       tx_fifo_full_int;

    // CPU → TX FIFO write side
    assign tx_fifo_wr    = tx_push && !tx_fifo_full_int;
    assign tx_fifo_wdata = tx_push_data;
    assign tx_fifo_full = tx_fifo_full_int;

    // UART TX → TX FIFO read side
    assign tx_fifo_rd    = (!tx_busy) && (!tx_fifo_empty);

    // RX FIFO signals
    logic       rx_fifo_wr;
    logic       rx_fifo_rd;
    logic [7:0] rx_fifo_wdata;
    logic [7:0] rx_fifo_rdata;
    logic       rx_fifo_empty_int;
    logic       rx_fifo_full;

    // uart_rx outputs
    logic [7:0] rx_data_int;
    logic       rx_done_int;

    // RX FIFO write
    assign rx_fifo_wr    = rx_done_int && !rx_fifo_full;
    assign rx_fifo_wdata = rx_data_int;
    assign rx_fifo_rd    = rx_pop && !rx_fifo_empty_int;

    // expose to CPU
    assign rx_pop_data   = rx_fifo_rdata;
    assign rx_fifo_empty = rx_fifo_empty_int;

    tick_gen #(
        .FREQ(9_600 * 16)
    ) U_BAUD_TICK (
        .*,
        .o_tick(b_tick)
    );

    fifo #(
        .DEPTH(16)
    ) U_FIFO_TX (
        .*,
        .wr   (tx_fifo_wr),
        .rd   (tx_fifo_rd),
        .wdata(tx_fifo_wdata),
        .rdata(tx_fifo_rdata),
        .full (tx_fifo_full_int),
        .empty(tx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .*,
        .start_trig(!tx_busy && !tx_fifo_empty),
        .tx_data   (tx_fifo_rdata),
        .tx_busy   (tx_busy)
    );

    uart_rx U_UART_RX (
        .*,
        .rx_data(rx_data_int),
        .rx_done(rx_done_int)
    );

    fifo #(
        .DEPTH(16)
    ) U_FIFO_RX (
        .*,
        .wr   (rx_fifo_wr),
        .rd   (rx_fifo_rd),
        .wdata(rx_fifo_wdata),
        .rdata(rx_fifo_rdata),
        .full (rx_fifo_full),
        .empty(rx_fifo_empty_int)
    );



endmodule

module tick_gen #(
    parameter FREQ = 1_000_000
) (
    input  logic clk,
    input  logic rst,
    output logic o_tick
);

    localparam F_COUNT = 100_000_000 / FREQ;

    logic [$clog2(F_COUNT)-1:0] r_cnt;
    logic r_tick;
    assign o_tick = r_tick;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            r_cnt  <= 0;
            r_tick <= 1'b0;
        end else begin
            if (r_cnt == F_COUNT - 1) begin
                r_cnt  <= 0;
                r_tick <= 1'b1;
            end else begin
                r_cnt  <= r_cnt + 1;
                r_tick <= 1'b0;
            end
        end
    end

endmodule
