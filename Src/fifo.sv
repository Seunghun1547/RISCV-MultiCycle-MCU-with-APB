`timescale 1ns / 1ps
module fifo #(
    parameter DEPTH = 4
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       wr,
    input  logic       rd,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    wire [$clog2(DEPTH)-1:0] w_waddr, w_raddr;

    reg_file #(
        .DEPTH(DEPTH)
    ) U_REG_FILE (
        .clk(clk),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .wr(~full & wr),
        .wdata(wdata),
        .rdata(rdata)
    );

    fifo_control_unit #(
        .DEPTH(DEPTH)
    ) U_FIFO_CU (
        .clk(clk),
        .rst(rst),
        .wr(wr),
        .rd(rd),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .full(full),
        .empty(empty)
    );

endmodule

module fifo_control_unit #(
    parameter DEPTH = 4
) (
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     wr,
    input  logic                     rd,
    output logic [$clog2(DEPTH)-1:0] waddr,
    output logic [$clog2(DEPTH)-1:0] raddr,
    output logic                     full,
    output logic                     empty
);

    logic [$clog2(DEPTH)-1:0] waddr_reg, waddr_next;
    logic [$clog2(DEPTH)-1:0] raddr_reg, raddr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign waddr = waddr_reg;
    assign raddr = raddr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            wr, rd
        })
            2'b10: begin  // wr
                empty_next = 0;
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;
                    if (waddr_next == raddr_reg) begin
                        full_next = 1;
                    end
                end
            end
            2'b01: begin  // rd
                full_next = 0;
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1;
                    end
                end
            end
            2'b11: begin  // wr & rd
                if (empty_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 0;
                end else if (full_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 0;
                end else begin
                    waddr_next = waddr_reg + 1;
                    raddr_next = raddr_reg + 1;
                end
            end
        endcase
    end

endmodule

module reg_file #(
    parameter DEPTH = 4
) (
    input                      clk,
    input  [$clog2(DEPTH)-1:0] waddr,
    input  [$clog2(DEPTH)-1:0] raddr,
    input                      wr,
    input  [              7:0] wdata,
    output [              7:0] rdata
);

    logic [7:0] ram[0:DEPTH-1];
    assign rdata = ram[raddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[waddr] <= wdata;
        end
    end

endmodule
