module clic_top #(
    parameter num_sources = 64
)(
    // 1. Clock and Reset
    input  logic        S_AXI_ACLK,
    input  logic        S_AXI_ARESETN,

    // 2. AXI4-Lite Write Address Channel
    input  logic [15:0] S_AXI_AWADDR,
    input  logic        S_AXI_AWVALID,
    output logic        S_AXI_AWREADY,

    // 3. AXI4-Lite Write Data Channel
    input  logic [31:0] S_AXI_WDATA,
    input  logic        S_AXI_WVALID,
    input  logic [3:0]  S_AXI_WSTRB,
    output logic        S_AXI_WREADY,

    // 4. AXI4-Lite Write Response Channel
    output logic [1:0]  S_AXI_BRESP,
    output logic        S_AXI_BVALID,
    input  logic        S_AXI_BREADY,

    // 5. AXI4-Lite Read Address Channel
    input  logic [15:0] S_AXI_ARADDR,
    input  logic        S_AXI_ARVALID,
    output logic        S_AXI_ARREADY,

    // 6. AXI4-Lite Read Data Channel
    output logic [31:0] S_AXI_RDATA,
    output logic [1:0]  S_AXI_RRESP,
    output logic        S_AXI_RVALID,
    input  logic        S_AXI_RREADY,

    // 7. Physical External Interrupt Pins (Exposed to FPGA board switches/peripherals)
    // to prevent pin overutilization on small FPGAs
    input  logic [1:0]  ext_irq_pins,

    // 8. CPU Interrupt Interface (To srv32 Core)
    output logic        cpu_int_req,
    output logic [5:0]  cpu_int_id,
    output logic [31:0] cpu_vector_addr
);

    // internal wires to connect to clic_bus
    logic         bus_wren;
    logic         bus_ren;
    logic [15:0]  bus_addr;
    logic [31:0]  bus_wdata;
    logic [31:0]  bus_rdata;

    // Full 64-bit internal array required by the CLIC architecture
    logic [num_sources-1:0] ext_irq_internal;

    // Safe Pin Mapping & Tie-Offs
    always_comb begin
        // 1. Tie all 64 sources to 0 by default so unused lines never float
        ext_irq_internal = '0;
        
        // 2. Map physical board pins to specific interrupt lines
        ext_irq_internal[0] = ext_irq_pins[0]; // Source 0: Connected to GPIO Button
        ext_irq_internal[1] = ext_irq_pins[1]; // Source 1: Connected to UART RX
        
        // Sources [63:2] safely remain 0 internally and consume zero physical package pins!
    end

    // AXI 4 LITE write handshake
    assign bus_wren      = S_AXI_AWVALID & S_AXI_WVALID & ~S_AXI_BVALID;
    assign S_AXI_AWREADY = bus_wren;
    assign S_AXI_WREADY  = bus_wren;
    
    assign bus_addr  = S_AXI_AWVALID ? S_AXI_AWADDR : S_AXI_ARADDR;
    assign bus_wdata = S_AXI_WDATA;

    // Write Response (B-Channel)
    always_ff @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_BVALID <= 1'b0;
            S_AXI_BRESP  <= 2'b00;
        end else begin
            if (bus_wren) begin
                S_AXI_BVALID <= 1'b1;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // AXI4-Lite Read Handshake Logic
    assign bus_ren       = S_AXI_ARVALID & ~S_AXI_RVALID;
    assign S_AXI_ARREADY = bus_ren;

    always_ff @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_RVALID <= 1'b0;
            S_AXI_RRESP  <= 2'b00;
            S_AXI_RDATA  <= 32'b0;
        end else begin
            if (bus_ren) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RDATA  <= bus_rdata;
            end else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

    // Instantiate the CLIC Bus Module using the internal tied array
    clic_bus #(
        .num_sources(num_sources)
    ) u_clic_bus (
        .clk             (S_AXI_ACLK),
        .reset           (~S_AXI_ARESETN), 
        .ren             (bus_ren),
        .wren            (bus_wren),
        .bus_addr        (bus_addr),
        .rdata           (bus_rdata),     
        .wdata           (bus_wdata),     
        .ext_irq         (ext_irq_internal), // Passed internally
        .cpu_int_req     (cpu_int_req),
        .int_id          (cpu_int_id),
        .cpu_vector_addr (cpu_vector_addr)
    );

endmodule