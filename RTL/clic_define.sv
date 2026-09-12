package clic_define;

parameter int num_sources = 64; // sources like uart,gpio,spi

parameter int num_contexts = 1; // machine mode

// Arbitration Configuration

parameter int cliccfg_nlbit = 4;
// so [0:3] are priority , [7:4] are level

// Memory mapped address map (MMIO)

parameter logic [31:0] clic_baseaddr = 32'h0200_0000;

// grouping 4 configuration bytes for every source as per CLIC rules

parameter logic [1:0] clicint_ip = 2'h0;
parameter logic [1:0] clicint_ie = 2'h1;
parameter logic [1:0] clicint_attr = 2'h2; // like edge/leveled, vectoring
parameter logic [1:0] clicint_ctl = 2'h3;  // level & priority

endpackage