`timescale 1ns / 1ps

module tb_clic_top();

    logic        clk;
    logic        rst_n;

    // AXI4-Lite Signals
    logic [15:0] awaddr;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // AXI Read signals (tied off for this write-only test)
    logic [15:0] araddr = 0;
    logic        arvalid = 0;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready = 1;

    // Interrupt signals
    logic [63:0] ext_irq;
    
    // Outputs from CLIC
    logic        cpu_int_req;
    logic [5:0]  cpu_int_id;
    logic [31:0] cpu_vector_addr;

    clic_top #(
        .num_sources(64)
    ) dut (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (rst_n),
        
        .S_AXI_AWADDR  (awaddr),
        .S_AXI_AWVALID (awvalid),
        .S_AXI_AWREADY (awready),
        .S_AXI_WDATA   (wdata),
        .S_AXI_WSTRB   (4'hf),
        .S_AXI_WVALID  (wvalid),
        .S_AXI_WREADY  (wready),
        .S_AXI_BRESP   (bresp),
        .S_AXI_BVALID  (bvalid),
        .S_AXI_BREADY  (bready),
        
        .S_AXI_ARADDR  (araddr),
        .S_AXI_ARVALID (arvalid),
        .S_AXI_ARREADY (arready),
        .S_AXI_RDATA   (rdata),
        .S_AXI_RRESP   (rresp),
        .S_AXI_RVALID  (rvalid),
        .S_AXI_RREADY  (rready),
        
        .ext_irq       (ext_irq),
        .cpu_int_req   (cpu_int_req),
        .cpu_int_id    (cpu_int_id),
        .cpu_vector_addr(cpu_vector_addr)
    );

    initial begin
        clk = 0;
        rst_n=0;
        awaddr = 0;
        wdata = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

// AXI4-Lite Write Task (Strictly Synchronous)
    task axi_write(input [15:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr;
            wdata   <= data;
            awvalid <= 1'b1;
            wvalid  <= 1'b1;
            bready  <= 1'b1;
            
            // Wait strictly on clock edges until slave is ready
            while (!(awready && wready)) @(posedge clk);
            
            awvalid <= 1'b0;
            wvalid  <= 1'b0;
            
            // Wait strictly on clock edges for the response
            while (!bvalid) @(posedge clk);
            
            bready  <= 1'b0;
            @(posedge clk); 
        end
    endtask

    initial begin
        // Initialize signals
        rst_n   = 0;
        awvalid = 0;
        wvalid  = 0;
        bready  = 0;
        ext_irq = 64'b0;

        $display(" Starting CLIC Verification");

        // Apply Reset
        #20 rst_n = 1;
        #20;
        // Set Vector Table Base Address to 0x1000
        axi_write(16'h400, 32'h0000_1000);

        //TEST CASE 1: Higher Level vs Lower Level
        // Source 5: Level 3 (0x30)
        // Source 10: Level 2 (0x20)
        $display("Test 1: Level 3 vs Level 2 (Source 5 should win)");
        axi_write(16'h205, 32'h0000_0030); // Set ID 5 to Level 3, Pri 0
        axi_write(16'h20A, 32'h0000_0020); // Set ID 10 to Level 2, Pri 0
        
        axi_write(16'h105, 32'h0000_0001); // Enable ID 5
        axi_write(16'h10A, 32'h0000_0001); // Enable ID 10
        
        ext_irq[5]  = 1'b1;
        ext_irq[10] = 1'b1;
        #30; // Wait for combinational logic and registers to catch up
        
        if (cpu_int_id == 6'd5) $display("PASS: Higher level won.");
        else $display("FAIL: ID %d won instead of 5.", cpu_int_id);
        
        ext_irq = 64'b0; // clear interrupts
        #20;

        // TEST CASE 2: Same Level, Different Priority
        // Source 15: Level 2, Priority 1 (0x21)
        // Source 20: Level 2, Priority 3 (0x23)
        $display("Test 2: Same Level, Higher Priority (Source 20 should win)");
        axi_write(16'h20F, 32'h0000_0021); // Set ID 15
        axi_write(16'h214, 32'h0000_0023); // Set ID 20
        
        axi_write(16'h10F, 32'h0000_0001); // Enable ID 15
        axi_write(16'h114, 32'h0000_0001); // Enable ID 20
        
        ext_irq[15] = 1'b1;
        ext_irq[20] = 1'b1;
        #30;
        
        if (cpu_int_id == 6'd20) $display("PASS: Higher priority won.");
        else $display("FAIL: ID %d won instead of 20.", cpu_int_id);
        
        ext_irq = 64'b0;
        #20;


        // TEST CASE 3: Same Level, Same Priority (Tie-Breaker)
        // Source 25: Level 3, Priority 3 (0x33)
        // Source 30: Level 3, Priority 3 (0x33)
        // Rule: The lowest ID number must win automatically.

        $display("Test 3: Tie-Breaker (Source 25 should win because ID is lower)");
        axi_write(16'h219, 32'h0000_0033); // Set ID 25
        axi_write(16'h21E, 32'h0000_0033); // Set ID 30
        
        axi_write(16'h119, 32'h0000_0001); // Enable ID 25
        axi_write(16'h11E, 32'h0000_0001); // Enable ID 30
        
        ext_irq[25] = 1'b1;
        ext_irq[30] = 1'b1;
        #30;
        
        if (cpu_int_id == 6'd25) $display("PASS: Lowest ID won the tie-breaker.");
        else $display("FAIL: ID %d won instead of 25.", cpu_int_id);
        
        ext_irq = 64'b0;
        #20;
        

        // TEST CASE 4: Vectoring Address Test (SHV)
        // Turn on SHV for Source 25 and see if the address calculates.
        $display("Test 4: Selective Hardware Vectoring (SHV) Address Check");
        axi_write(16'h319, 32'h0000_0002); // Write '1' to bit 1 of attr for ID 25 (SHV Enable)
        
        ext_irq[25] = 1'b1;
        #30;
        
        // Expected Address = mtvt_base (0x1000) + (ID 25 * 4) = 0x1000 + 100 = 0x1064
        if (cpu_vector_addr == 32'h0000_1064) 
            $display("PASS: SHV Vector address properly calculated (0x1064).");
        else 
            $display("FAIL: Wrong vector address calculated: %h", cpu_vector_addr);

        $display("--- Verification Complete ---");
        $finish;
    end

endmodule