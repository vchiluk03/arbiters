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
//----%% File Name        : arbiter_wghtd_rrobin.sv
//----%% Module Name      : Weighted Round-Robin Arbiter                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Weighted Round-Robin Arbiter resolves requests from N devices like classic round-robin scheduling but each device 
//----%%                    is allocated a weight W. A device can be at most issued grant W times consecutively. After that, weight runs over.
//----%%                    Only one device at a time is issued grant. The device requests are arbitrated in a circular queue:
//----%%
//----%%                    +<------------------<-------------------<--+
//----%%                    |                                          |
//----%%                    + --> [0] --> [1] --> [2] ... --> [N-1] -->+
//----%%                           ^
//----%%                           |
//----%%                          HEAD on reset
//----%%
//----%%                    Active requester is issued grant consecutively until its weight runs over.
//----%%                    HEAD has the highest priority.
//----%%                    HEAD moves from [x]-->[x+1] in the circular queue when-
//----%%                    - The device@HEAD has been issued a grant, and its weights ran over.
//----%%                    - The device@HEAD has no pending request, forcing the arbiter to skip to the next active requester.
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
//                                               A R B I T E R   -   W E I G H T E D   R O U N D -  R O B I N                                         
//###################################################################################################################################################
module arbiter_wghtd_rrobin (
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
logic [3:0] priority_sel_grant       ;  // Priority selected Grant
logic [3:0] mask_rg                  ;  // Mask register

// Mask generation logic
// Assume one clock cycle = one time slot...
// Generate new mask once a device is issued grant and mask the device only when its grant counter runs over...
// '0' masks the request
always_ff @(posedge clk or negedge aresetn) begin 
   if (!aresetn) begin
      mask_rg  <= 4'hF ;  // HEAD at [0] on reset      
      cnt_rg   <= '{default: 3'd0};
   end 
   else begin        
      if (o_grant[0]) begin
         cnt_rg[0] <= (cnt_rg[0] == WGHT[0])? 3'd0 : (cnt_rg[0] + 3'd1) ;
         mask_rg   <= (cnt_rg[0] == WGHT[0])? 4'b1110 : 4'b1111 ;  // HEAD remains at [0] as long as the device[0] grant counter hasn't run over...
         // Clear other grant counters
         cnt_rg[1] <= 3'd0 ;
         cnt_rg[2] <= 3'd0 ;
         cnt_rg[3] <= 3'd0 ;            
      end
      else if (o_grant[1]) begin
         cnt_rg[1] <= (cnt_rg[1] == WGHT[1])? 3'd0 : (cnt_rg[1] + 3'd1) ;
         mask_rg   <= (cnt_rg[1] == WGHT[1])? 4'b1100 : 4'b1110 ;  // HEAD remains at [1] as long as the device[1] grant counter hasn't run over...
         // Clear other grant counters
         cnt_rg[0] <= 3'd0 ;
         cnt_rg[2] <= 3'd0 ;
         cnt_rg[3] <= 3'd0 ;            
      end
      else if (o_grant[2]) begin
         cnt_rg[2] <= (cnt_rg[2] == WGHT[2])? 3'd0 : (cnt_rg[2] + 3'd1) ;
         mask_rg   <= (cnt_rg[2] == WGHT[2])? 4'b1000 : 4'b1100 ;  // HEAD remains at [2] as long as the device[2] grant counter hasn't run over...
         // Clear other grant counters
         cnt_rg[0] <= 3'd0 ;
         cnt_rg[1] <= 3'd0 ;
         cnt_rg[3] <= 3'd0 ;           
      end
      else if (o_grant[3]) begin
         cnt_rg[3] <= (cnt_rg[3] == WGHT[3])? 3'd0 : (cnt_rg[3] + 3'd1) ;
         mask_rg   <= (cnt_rg[3] == WGHT[3])? 4'b1111 : 4'b1000 ;  // HEAD remains at [3] as long as the device[3] grant counter hasn't run over...  
         // Clear other grant counters
         cnt_rg[0] <= 3'd0 ;
         cnt_rg[1] <= 3'd0 ;
         cnt_rg[2] <= 3'd0 ;          
      end
   end     
end

// Masked Request: masks all served devices/lower priority devices at [0] to [HEAD-1]
//                 The devices at HEAD to [N-1] are unmasked...
assign masked_req = i_req & mask_rg ;

// Masked Grant: grant corresponding to Masked Request
arbiter_fx_priority #(
   .N (4)
) inst_masked_grant (
   .i_req   (masked_req) , 
   .o_grant (masked_grant)
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
// clk      /````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
// D0_req   /`````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D1_req   /`````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D2_req   /`````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D3_req   /`````````````````````````````````````````````````````````````````````````````````````````````````````````````\
// D0_grant /`````````\____________________________________________________________________________________________________
// D1_grant __________/`````````````````````````````````````````````````\__________________________________________________
// D2_grant ____________________________________________________________/```````````````````\______________________________
// D3_grant ________________________________________________________________________________/`````````````````````````````\
//
// If no requests are pending from any devices at HEAD to [N-1], arbitrate across all devices at [0] to [N-1]
// clk      /````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
// D0_req   /``````````````````````````````````````````````````````````````````````````````````````````````````````````````
// D1_req   ____________________/``````````````````````````````````````````````````````````````````````````````````````````
// D2_req   /```````````````````````````````````````\______________________________________________________________________
// D3_req   /`````````````````````````````````````````````````\____________________________________________________________
// D0_grant /`````````\_______________________________________/`````````\_________________________________________________/
// D1_grant ____________________________________________________________/`````````````````````````````````````````````````\
// D2_grant __________/```````````````````\________________________________________________________________________________
// D3_grant ______________________________/```````````````````\____________________________________________________________
//
assign o_grant = (|masked_req)? masked_grant : priority_sel_grant ;

endmodule
//###################################################################################################################################################
//                                               A R B I T E R   -   W E I G H T E D   R O U N D -  R O B I N                                         
//###################################################################################################################################################