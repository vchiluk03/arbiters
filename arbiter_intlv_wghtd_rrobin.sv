//     %%%%%%%%%%%%      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//  %%%%%%%%%%%%%%%%%%                      
// %%%%%%%%%%%%%%%%%%%% %%                
//    %% %%%%%%%%%%%%%%%%%%                
//        % %%%%%%%%%%%%%%%                 
//           %%%%%%%%%%%%%%                 ////    O P E N - S O U R C E     ////////////////////////////////////////////////////////////
//           %%%%%%%%%%%%%      %%          _________________________________////
//           %%%%%%%%%%%       %%%%                ________    _                             __      __                _     
//          %%%%%%%%%%        %%%%%%              / ____/ /_  (_)___  ____ ___  __  ______  / /__   / /   ____  ____ _(_)____ TM 
//         %%%%%%%    %%%%%%%%%%%%*%%%           / /   / __ \/ / __ \/ __ `__ \/ / / / __ \/ //_/  / /   / __ \/ __ `/ / ___/
//        %%%%% %%%%%%%%%%%%%%%%%%%%%%%         / /___/ / / / / /_/ / / / / / / /_/ / / / / ,<    / /___/ /_/ / /_/ / / /__  
//       %%%%*%%%%%%%%%%%%%  %%%%%%%%%          \____/_/ /_/_/ .___/_/ /_/ /_/\__,_/_/ /_/_/|_|  /_____/\____/\__, /_/\___/
//       %%%%%%%%%%%%%%%%%%%    %%%%%%%%%                   /_/                                              /____/  
//       %%%%%%%%%%%%%%%%                                                             ___________________________________________________               
//       %%%%%%%%%%%%%%                    //////////////////////////////////////////////       c h i p m u n k l o g i c . c o m    //// 
//         %%%%%%%%%                       
//           %%%%%%%%%%%%%%%%               
//    
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//----%% 
//----%% File Name        : arbiter_intlv_wghtd_rrobin.sv
//----%% Module Name      : Interleaved Weighted Round-Robin Arbiter                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Interleaved Weighted Round-Robin Arbiter resolves requests from N devices like classic weighted round-robin scheduling
//----%%                    but grants are issued in an interleaved manner (instead of consecutively) to requesting devices 
//----%%                    until its weights run over.
//----%%                    Only one device at a time is issued grant. The device requests are arbitrated in a circular queue:
//----%%
//----%%                    +<------------------<-------------------<--+
//----%%                    |          |       |           |           |
//----%%                    + --> [0] --> [1] --> [2] ... --> [N-1] -->+
//----%%                           ^
//----%%                           |
//----%%                          HEAD on reset
//----%%
//----%%                    Active requesters are issued grant in interleaved manner until its weights run over.
//----%%                    HEAD has the highest priority.
//----%%                    HEAD moves from [x]-->[x+1] in the circular queue when-
//----%%                    - The device@HEAD has been issued a grant.
//----%%                    - The device@HEAD has no pending request, forcing the arbiter to skip to the next active requester.
//----%%                    HEAD rolls back to the first active requester with weights>0.
//----%%                    No grant cycle is wasted as long as there is at least one device is requesting.
//----%%                    Weight of a device is reset once a round is completed.
//----%%
//----%% Last modified on : Jan-2024
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see README.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                     A R B I T E R   -   I N T E R L E A V E D   W E I G H T E D   R O U N D -  R O B I N                                         
//###################################################################################################################################################
module arbiter_intlv_wghtd_rrobin (
   input  logic       clk     ,  // Clock
   input  logic       aresetn ,  // Async active-low reset
   input  logic [3:0] i_req   ,  // Requests
   output logic [3:0] o_grant    // Grants
);

// Weights allocated to Devices
// More weight ==> more time share ==> more potential to be granted access
localparam [2:0] WGHT [4] = '{3'h0, 3'h4, 3'h1, 3'h2} ;  // WGHT+1 is the actual weight... eg: (WGHT = 0) => 1 time slot
logic [2:0] cnt_rg [4] ;  // Grant counter

logic [3:0] masked_req, masked_grant ;  // Masked Request & Grant
logic [3:0] pend_req, pend_grant     ;  // Pending Request & Grant
logic [3:0] priority_sel_grant       ;  // Priority selected Grant
logic [3:0] mask_rg                  ;  // Mask register
logic [3:0] flag_rg                  ;  // Flags grant limit reached

// Mask generation logic
// Assume one clock cycle = one time slot...
// Generate new mask once a device is issued grant and mask the device...
// '0' masks the request
always_ff @(posedge clk or negedge aresetn) begin 
   if (!aresetn) begin
      mask_rg  <= 4'hF ;  // HEAD at [0] on reset      
      cnt_rg   <= '{default: 3'd0};
      flag_rg  <= 4'h0 ;
   end 
   else begin        
      if (o_grant[0]) begin
         cnt_rg[0]  <= (cnt_rg[0] == WGHT[0])? 3'd0 : (cnt_rg[0] + 3'd1) ;
         flag_rg[0] <= (cnt_rg[0] == WGHT[0])? 1'b1 : 1'b0 ;  // Flag if grant limit reached for Device[0]        
         mask_rg    <= 4'b1110 ;  // HEAD becomes [1] after issuing grant at [0] 
         // Clear other grant counters, flags if the issued grant was Priority selected Grant...
         if (~|masked_req && ~|pend_req) begin
            cnt_rg[1]  <= 3'd0 ;
            flag_rg[1] <= 1'b0 ;
            cnt_rg[2]  <= 3'd0 ;
            flag_rg[2] <= 1'b0 ;
            cnt_rg[3]  <= 3'd0 ;
            flag_rg[3] <= 1'b0 ; 
         end           
      end
      else if (o_grant[1]) begin
         cnt_rg[1]  <= (cnt_rg[1] == WGHT[1])? 3'd0 : (cnt_rg[1] + 3'd1) ;
         flag_rg[1] <= (cnt_rg[1] == WGHT[1])? 1'b1 : 1'b0 ;  // Flag if grant limit reached for Device[1]         
         mask_rg    <= 4'b1100 ;  // HEAD becomes [2] after issuing grant at [1] 
         // Clear other grant counters, flags if the issued grant was Priority selected Grant...
         if (~|masked_req && ~|pend_req) begin
            cnt_rg[0]  <= 3'd0 ;
            flag_rg[0] <= 1'b0 ;
            cnt_rg[2]  <= 3'd0 ;
            flag_rg[2] <= 1'b0 ;
            cnt_rg[3]  <= 3'd0 ;
            flag_rg[3] <= 1'b0 ; 
         end            
      end
      else if (o_grant[2]) begin
         cnt_rg[2]  <= (cnt_rg[2] == WGHT[2])? 3'd0 : (cnt_rg[2] + 3'd1) ;
         flag_rg[2] <= (cnt_rg[2] == WGHT[2])? 1'b1 : 1'b0 ;  // Flag if grant limit reached for Device[2]         
         mask_rg    <= 4'b1000 ;  // HEAD becomes [3] after issuing grant at [2] 
         // Clear other grant counters, flags if the issued grant was Priority selected Grant...
         if (~|masked_req && ~|pend_req) begin
            cnt_rg[0]  <= 3'd0 ;
            flag_rg[0] <= 1'b0 ;
            cnt_rg[1]  <= 3'd0 ;
            flag_rg[1] <= 1'b0 ;
            cnt_rg[3]  <= 3'd0 ;
            flag_rg[3] <= 1'b0 ; 
         end           
      end
      else if (o_grant[3]) begin
         cnt_rg[3]  <= (cnt_rg[3] == WGHT[3])? 3'd0 : (cnt_rg[3] + 3'd1) ;
         flag_rg[3] <= (cnt_rg[3] == WGHT[3])? 1'b1 : 1'b0 ;  // Flag if grant limit reached for Device[3]         
         mask_rg    <= 4'b1111 ;  // HEAD resets to [0] after issuing grant at [3] 
         // Clear other grant counters, flags if the issued grant was Priority selected Grant...
         if (~|masked_req && ~|pend_req) begin
            cnt_rg[0]  <= 3'd0 ;
            flag_rg[0] <= 1'b0 ;
            cnt_rg[1]  <= 3'd0 ;
            flag_rg[1] <= 1'b0 ;
            cnt_rg[2]  <= 3'd0 ;
            flag_rg[2] <= 1'b0 ; 
         end          
      end
   end     
end

// Masked Request: masks all served devices/lower priority devices at [0] to [HEAD-1]
//                 The devices at HEAD to [N-1] are unmasked if grant counters haven't run over...
assign masked_req = i_req & mask_rg & ~flag_rg ;

// Pending Request: blocks all devices which reached grant limit, others are allowed to have pending requests...
assign pend_req = i_req & ~flag_rg ;

// Masked Grant: grant corresponding to Masked Request
arbiter_fx_priority #(
   .N (4)
) inst_masked_grant (
   .i_req   (masked_req) , 
   .o_grant (masked_grant)
);

// Pending Grant: grant corresponding to Pending Request
arbiter_fx_priority #(
   .N (4)
) inst_pend_grant (
   .i_req   (pend_req) , 
   .o_grant (pend_grant)
);

// Priority selected Grant: grant corresponding to unmasked Request, this acts like fixed priority arbiter...
arbiter_fx_priority #(
   .N (4)
) inst_priority_sel_grant (
   .i_req   (i_req) , 
   .o_grant (priority_sel_grant)
);

// Final Grant
// ===========
// clk      /````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
// D0_req   /```````````````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D1_req   /```````````````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D2_req   /```````````````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D3_req   /```````````````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D0_grant /`````````\___________________________________________________________________________________________________/``reset``\
// D1_grant __________/`````````\___________________/`````````\___________________/`````````\_________/```````````````````\__________
// D2_grant ____________________/`````````\___________________/`````````\____________________________________________________________
// D3_grant ______________________________/`````````\___________________/`````````\_________/`````````\______________________________
//
// If no requests are pending from any devices at HEAD to [N-1], arbitrate across all devices at [0] to [N-1]
// clk      /````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
// D0_req   /````````````````````````````````````````````````````````````````````````````````````````````````````````````````````````
// D1_req   ____________________/````````````````````````````````````````````````````````````````````````````````````````````````````
// D2_req   /`````````````````````````````````````````````````\___________________/`````````\_________/``````````````````````````````
// D3_req   /`````````````````````````````````````````````````\___________________/`````````\_____________________________/``````````
// D0_grant /`````````\_________________________________________________________________________________________/``reset``\__________
// D1_grant ______________________________/`````````\_________/```````````````````\_________/```````````````````\_________/`````````\
// D2_grant __________/`````````\___________________/`````````\_____________________________________________________________________/
// D3_grant ____________________/`````````\_______________________________________/`````````\________________________________________
//
assign o_grant = (|masked_req)? masked_grant : ((|pend_req)? pend_grant : priority_sel_grant) ;

endmodule
//###################################################################################################################################################
//                                     A R B I T E R   -   I N T E R L E A V E D   W E I G H T E D   R O U N D -  R O B I N                                         
//###################################################################################################################################################