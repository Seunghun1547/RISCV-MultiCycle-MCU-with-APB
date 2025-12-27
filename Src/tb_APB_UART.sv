`timescale 1ns / 1ps

interface apb_master_if (
    input logic clk,
    input logic reset
);
    logic        transfer;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        ready;
endinterface  //apb_interf

class transaction;

    logic             transfer;
    logic             write;
    logic      [31:0] addr;
    rand logic [31:0] wdata;
    logic      [31:0] rdata;
    logic             ready;

    rand logic [ 7:0] tx_byte;
    logic      [ 7:0] rx_byte;

    task automatic print(string name);
        $display(
            "[%s], transfer = %h, write = %h, addr = %h, wdata = %h, rdata = %h",
            name, transfer, write, addr, wdata, rdata);
    endtask  //automatic

    task automatic print_uart(string name);
        $display("[%s], tx_byte = %h, rx_byte = %h", name, tx_byte, rx_byte);
    endtask  //automatic

endclass  //transaction

class apbSignal;

    transaction t;
    virtual apb_master_if m_if;
    int pass_count, fail_count;

    localparam logic [31:0] UART_BASE_ADDR = 32'h1000_4000;
    localparam logic [31:0] UART_STATUS_ADDR = 32'h1000_4000;  // offset 0x0
    localparam logic [31:0] UART_CTRL_ADDR = 32'h1000_4004;  // offset 0x4
    localparam logic [31:0] UART_TXDATA_ADDR = 32'h1000_4008;  // offset 0x8
    localparam logic [31:0] UART_RXDATA_ADDR = 32'h1000_400C;  // offset 0xC

    function new(virtual apb_master_if m_if);
        this.m_if = m_if;
        this.t = new();
        this.pass_count = 0;
        this.fail_count = 0;
    endfunction  //new()

    task automatic write_reg(input logic [31:0] addr, input logic [31:0] data);
        t.addr  = addr;
        t.wdata = data;
        send();
    endtask

    task automatic read_reg(input logic [31:0] addr, output logic [31:0] data);
        t.addr = addr;
        receive();
        data = t.rdata;
    endtask

    task automatic send();
        t.transfer = 1'b1;
        t.write    = 1'b1;
        m_if.transfer <= t.transfer;
        m_if.write    <= t.write;
        m_if.addr     <= t.addr;
        m_if.wdata    <= t.wdata;
        t.print_uart("SEND");
        @(posedge m_if.clk);
        m_if.transfer <= 1'b0;
        @(posedge m_if.clk);
        wait (m_if.ready);
        @(posedge m_if.clk);
    endtask  //automatic

    task automatic receive();
        t.transfer = 1'b1;
        t.write    = 1'b0;
        m_if.transfer <= t.transfer;
        m_if.write    <= t.write;
        m_if.addr     <= t.addr;
        @(posedge m_if.clk);
        m_if.transfer <= 1'b0;
        @(posedge m_if.clk);
        wait (m_if.ready);
        t.rdata = m_if.rdata;
        t.print_uart("RECEIVE");
        @(posedge m_if.clk);
    endtask  //automatic

    task automatic uart_load_tx_byte();
        logic [31:0] tx_word;

        tx_word = {24'h000000, t.tx_byte};

        write_reg(UART_TXDATA_ADDR, tx_word);

        $display(
            "[%0t][UART_LOAD_TX_BYTE] byte=0x%02h (word=0x%08h) -> TXDATA(0x%08h)",
            $time, t.tx_byte, tx_word, UART_TXDATA_ADDR);
    endtask  // uart_load_tx_byte

    task automatic uart_push_tx();
        logic [31:0] ctrl_word;

        ctrl_word = 32'h0000_0001;  // bit0 = 1 (tx_push pulse)

        write_reg(UART_CTRL_ADDR, ctrl_word);

        $display("[%0t][UART_PUSH_TX] CTRL<=0x%08h (tx_push=1 @ 0x%08h)",
                 $time, ctrl_word, UART_CTRL_ADDR);
    endtask

    task automatic uart_wait_rx_ready();
        logic [31:0] status;
        bit rx_fifo_empty;

        do begin
            read_reg(UART_STATUS_ADDR, status);
            rx_fifo_empty = status[1];  // rx_fifo_empty
            $display("[%0t][UART_WAIT_RX_READY] status=0x%08h empty=%0b",
                     $time, status, rx_fifo_empty);
            @(posedge m_if.clk);
        end while (rx_fifo_empty);
        $display("[%0t][UART_WAIT_RX_READY] RX AVAILABLE", $time);
    endtask

    task automatic uart_pop_rx();
        logic [31:0] ctrl_word;

        ctrl_word = 32'h0000_0002;  // bit1 = 1 (rx_pop pulse)

        write_reg(UART_CTRL_ADDR, ctrl_word);

        $display("[%0t][UART_POP_RX] CTRL<=0x%08h (rx_pop=1 @ 0x%08h)", $time,
                 ctrl_word, UART_CTRL_ADDR);
    endtask

    task automatic uart_read_rx_byte();
        logic [31:0] rx_word;

        read_reg(UART_RXDATA_ADDR, rx_word);

        t.rx_byte = rx_word[7:0];

        $display("[%0t][UART_READ_RX_BYTE] RXDATA=0x%02h (0x%08h @ 0x%08h)",
                 $time, t.rx_byte, rx_word, UART_RXDATA_ADDR);
    endtask

    task automatic compare();
        if (t.tx_byte == t.rx_byte) begin
            $display("[%0t][COMPARE] PASS expected=0x%02h received=0x%02h",
                     $time, t.tx_byte, t.rx_byte);
            pass_count++;
        end else begin
            $display("[%0t][COMPARE] FAIL expected=0x%02h received=0x%02h",
                     $time, t.tx_byte, t.rx_byte);
            fail_count++;
        end
    endtask

    task automatic uart_wait_tx_idle();
        logic [31:0] status;
        bit tx_busy_b;
        do begin
            read_reg(UART_STATUS_ADDR, status);
            tx_busy_b = status[0];  // bit0 = tx_busy
            @(posedge m_if.clk);
        end while (tx_busy_b);
        $display("[%0t][UART_WAIT_TX_IDLE] tx_busy=0", $time);
    endtask

    task automatic run(int loop);
        repeat (loop) begin
            t.randomize();

            uart_load_tx_byte();
            uart_push_tx();

            uart_wait_tx_idle();

            uart_wait_rx_ready();
            uart_pop_rx();
            uart_read_rx_byte();

            compare();

            t.print_uart("LOOP_DONE");
        end
        $display("========================================");
        $display("[UART LOOPBACK RESULT] PASS=%0d / FAIL=%0d (total=%0d)",
                 pass_count, fail_count, pass_count + fail_count);
        $display("========================================");
    endtask  //automatic
endclass  //apbSignal


module tb_APB ();

    // global signals
    logic        PCLK;
    logic        PRESET;
    // APB Interface Signals
    logic [31:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;
    logic        PSEL0;
    logic        PSEL1;
    logic        PSEL2;
    logic        PSEL3;
    logic        PSEL4;
    logic [31:0] PRDATA0;
    logic [31:0] PRDATA1;
    logic [31:0] PRDATA2;
    logic [31:0] PRDATA3;
    logic [31:0] PRDATA4;
    logic        PREADY0;
    logic        PREADY1;
    logic        PREADY2;
    logic        PREADY3;
    logic        PREADY4;

    logic        uart_line;

    apb_master_if m_if (
        .clk  (PCLK),
        .reset(PRESET)
    );

    APB_Master dut_manager (
        .*,
        .transfer(m_if.transfer),
        .ready   (m_if.ready),
        .write   (m_if.write),
        .addr    (m_if.addr),
        .wdata   (m_if.wdata),
        .rdata   (m_if.rdata)
    );
    UART_Periph dut_uart (
        .*,
        .PSEL  (PSEL4),
        .PRDATA(PRDATA4),
        .PREADY(PREADY4),
        .tx    (uart_line),
        .rx    (uart_line)
    );



    always #5 PCLK = ~PCLK;

    initial begin
        #00 PCLK = 0;
        PRESET = 1;
        #10 PRESET = 0;
    end

    apbSignal apbSignalTester;  // handler

    initial begin
        apbSignalTester = new(m_if);

        repeat (3) @(posedge PCLK);

        apbSignalTester.run(100);

        @(posedge PCLK);
        #20;
        $finish;
    end
endmodule
