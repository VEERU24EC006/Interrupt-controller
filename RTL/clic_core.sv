module clic_core #(
    parameter num_sources = 64
)(
    input logic [num_sources-1:0] clicint_ip,
    input logic [num_sources-1:0] clicint_ie,
    input logic [7:0] clicint_ctl[0:num_sources-1],
    input logic [3:0] cpu_curr_level,
    output logic int_req,
    output logic [5:0] int_id,
    output logic [3:0] int_level
);


//Active interrupts filter

logic [num_sources-1:0] active_interrupts;

assign active_interrupts = clicint_ip & clicint_ie; // bitwise AND

//variables to keep track of interrupts
logic [3:0] curr_max_level;
logic [3:0] curr_max_pri;
logic [5:0] curr_max_id;
logic found_active; // only winner if enabled and pending
logic [3:0] src_level;
logic [3:0] src_pri;
always_comb begin

curr_max_level = 4'b0000;
curr_max_pri = 4'b0000; 
curr_max_id = 6'b111111; // max id so lower id can overwrite it
found_active = 1'b0;


    for(int i=0;i<num_sources;i++)begin

        if(active_interrupts[i])begin

      src_level = clicint_ctl[i][7:4];
        src_pri = clicint_ctl[i][3:0];

        //concatentation block {level,priority}

        if(!found_active || ({src_level,src_pri}>{curr_max_level,curr_max_pri}) || (({src_level,src_pri} == {curr_max_level,curr_max_pri}) && (i[5:0]< curr_max_id)))begin
            curr_max_level = src_level;
            curr_max_pri = src_pri;
            curr_max_id = i[5:0];
            found_active = 1'b1;
        end

    end
end                
                
//Preemption gate 

    if(found_active && (curr_max_level>cpu_curr_level))begin
        int_req = 1'b1;
        int_id = curr_max_id;
        int_level = curr_max_level;
            end else begin
            int_req =0;
            int_id = 6'b0;
            int_level=4'b0;
        end
    end
endmodule


 