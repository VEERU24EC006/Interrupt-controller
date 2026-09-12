module clic_bus #(
    parameter num_sources =64

)(  input logic clk,
    input logic reset,
    input logic ren,
    input logic wren,
    input logic [15:0] bus_addr,
    output logic [31:0]rdata,
    input logic [31:0]wdata,
    

   input logic [num_sources-1:0] ext_irq,

    // direct output to srv32 core
    output logic cpu_int_req,
    output logic [5:0] int_id,
    output logic [31:0] cpu_vector_addr
);

 logic [31:0] clic_baseaddr = 32'h0200_0000;

// grouping 4 configuration bytes for every source as per CLIC rules
(* dont_touch = "true" *) logic [num_sources-1:0] clicint_ip;
(* dont_touch = "true" *) logic [num_sources-1:0] clicint_ie;
(* dont_touch = "true" *) logic [7:0] clicint_ctl[0:num_sources-1];
(* dont_touch = "true" *) logic [7:0] clicint_attr[0:num_sources-1];

logic[3:0] core_int_level;
logic[31:0] mtvt_base_addr;



clic_core #(
    .num_sources(num_sources)
)u_clic_core(
    .clicint_ip(clicint_ip),
    .clicint_ie(clicint_ie),
    .clicint_ctl(clicint_ctl),
    .cpu_curr_level (4'b0000),
    .int_req(cpu_int_req),
    .int_id(int_id),
    .int_level(core_int_level)

);


// Register read write logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            clicint_ip     <= '0;
            clicint_ie     <= '0;
            mtvt_base_addr <= 32'h0000_1000;
            for (int i = 0; i < num_sources; i++) begin
                clicint_ctl[i]  <= 8'h00;
                clicint_attr[i] <= 8'h00;
            end
        end else begin
            // 1. Capture external hardware interrupts
            for (int i = 0; i < num_sources; i++) begin
                clicint_ip[i] <= ext_irq[i];
            end   

            // 2. CPU Bus Write Operations
            if (wren) begin
                case (bus_addr[11:8])
                    4'h0: clicint_ip[bus_addr[5:0]]   <= wdata[0];   // Addresses 0x000 - 0x03F
                    4'h1: clicint_ie[bus_addr[5:0]]   <= wdata[0];   // Addresses 0x100 - 0x13F
                    4'h2: clicint_ctl[bus_addr[5:0]]  <= wdata[7:0]; // Addresses 0x200 - 0x23F
                    4'h3: clicint_attr[bus_addr[5:0]] <= wdata[7:0]; // Addresses 0x300 - 0x33F
                    4'h4: if (bus_addr[11:0] == 12'h400) mtvt_base_addr <= wdata; // 0x400
                    default: ;
                endcase
            end
        end
    end

    // CPU Bus Read Multiplexer
    always_comb begin
        rdata = 32'h0000_0000;
        if (ren) begin
            case (bus_addr[11:8])
                4'h0: rdata = {31'b0, clicint_ip[bus_addr[5:0]]};
                4'h1: rdata = {31'b0, clicint_ie[bus_addr[5:0]]};
                4'h2: rdata = {24'b0, clicint_ctl[bus_addr[5:0]]};
                4'h3: rdata = {24'b0, clicint_attr[bus_addr[5:0]]};
                4'h4: if (bus_addr[11:0] == 12'h400) rdata = mtvt_base_addr;
                default: rdata = 32'h0000_0000;
            endcase
        end
    end

//Selective hardware vectoring logic and address routing

logic winning_shv_en;

assign winning_shv_en = clicint_attr[int_id][1];

always_comb begin
    if (cpu_int_req) begin
        if (winning_shv_en) begin
            // SHV enabled: Vector directly to table entry
            cpu_vector_addr = mtvt_base_addr + ({26'b0, int_id} << 2); // each innstruction addr if 4byte
        end else begin
            // SHV disabled: Default non-vectored handler address
            cpu_vector_addr = 32'h0000_0040;
        end
    end else begin
        cpu_vector_addr = 32'h0000_0000;
    end
end
endmodule