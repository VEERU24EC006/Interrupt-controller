module clic_gateway(
    input logic int_src,
    input logic clk,
    input logic reset,
    input logic clicint_attr,  // 1 is edge , 0 is level 
    input logic clear_pending,  // cpu sends this over AXI
    output logic clicint_ip   // pending bit sending to arbiter
);

logic ff1,ff2,ff3;

always_ff @(posedge clk or posedge reset)begin
    if(reset)begin
        ff1<=1'b0;
        ff2<=1'b0;
        ff3<=1'b0;
    end else begin
    ff1 <= int_src; //get the raw signal
    ff2 <= ff1; // get the synchronized signal
    ff3 <= ff2; // get the delayed/previous state
    end
end

logic rising_edge;
assign rising_edge = (ff2 && !ff3);
    
// pending bit latch logic for clicintip

always_ff @(posedge clk or posedge reset)begin
        if(reset)begin
            clicint_ip <= 1'b0;
        end else if (clear_pending)begin
            clicint_ip <= 1'b0;

        // EDGE MODE    
        end  else if(clicint_attr)begin
            if(rising_edge)begin
            clicint_ip <= 1'b1;
            end
        end
        //Level mode
        else begin
        clicint_ip <= ff2;
        end
end
        
endmodule