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
//----%% File Name        : arbiter_defct_rrobin.sv
//----%% Module Name      : Deficit Round-Robin Arbiter                                            
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Deficit Round-Robin Arbiter resolves requests from N devices like classic round-robin scheduling but each device 
//----%%                    is allocated a Quanta and Packet size. Every round, quanta (credits) are added to each active requester.
//----%%                    A deficit counter accumulates the credits per requester.
//----%%                    A device can be issued grant when the total accumulated credits is >= packet size
//----%%                    The device can be continuosly issued grant until all the packets are sent out and credits are run out.
//----%%                    Any deficit credit can be carried to the next round.
//----%%                    Only one device at a time is issued grant. The device requests are arbitrated in a circular queue:
//----%%
//----%%                    +<------------------<-------------------<--+
//----%%                    |                                          |
//----%%                    + --> [0] --> [1] --> [2] ... --> [N-1] -->+
//----%%                           ^
//----%%                           |
//----%%                          HEAD on reset
//----%%
//----%%                    Active requester is issued grant consecutively until its credits runs over.
//----%%                    HEAD has the highest priority.
//----%%                    HEAD moves from [x]-->[x+1] in the circular queue when-
//----%%                    - The device@HEAD has been issued a grant, and its credits ran over.
//----%%                    - The device@HEAD has no pending request or not enough credits, forcing the arbiter to skip to the next active requester.
//----%%                    No grant cycle is wasted as long as there is at least one device is requesting with enough credits.
//----%%
//----%% Last modified on : Dec-2025
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see README.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
//###################################################################################################################################################
//                                               A R B I T E R   -   D E F I C I T   R O U N D -  R O B I N                                         
//###################################################################################################################################################
module arbiter_defct_rrobin (
   input  logic       clk     ,  // Clock
   input  logic       aresetn ,  // Async active-low reset
   input  logic [3:0] i_req   ,  // Requests
   output logic [3:0] o_grant    // Grants
);

// Quantum & Packet sizes of requesters
localparam [15:0] QUANTA [4] = {16'd600, 16'd600, 16'd600, 16'd300};
localparam [15:0] PKT_SZ [4] = {16'd300, 16'd600, 16'd900, 16'd300};
localparam [15:0] D_MAX  [4] = {16'd600, 16'd600, 16'd1200, 16'd300};  // Max deficit counter accumulation

// Packet related signals per requester
logic [15:0] quanta          [4];  // Quanta
logic [15:0] pkt_sz          [4];  // Packet size (P)
logic [15:0] dcnt            [4];  // Deficit counter (DC)
logic [15:0] dcnt_max        [4];  // Max deficit
logic [16:0] dcnt_plus_q     [4];  // DC + Quanta
logic [15:0] dcnt_plus_q_cap [4];  // DC + Quanta capped to max
logic  [3:0] is_dc_lt_p;           // DC < P ?

// Grant signals
logic        pr_grant_any;  // Any grant which was priority selected
logic        no_grant;      // No grant
logic  [3:0] masked_grant;  // Masked grant
logic  [3:0] pr_grant;      // Priority selected grant

// Conditioned requests & mask
logic  [3:0] valid_req;         // Valid req
logic  [3:0] masked_valid_req;  // Masked valid req
logic  [3:0] mask_ff;           // Mask

// Genvars
genvar i;

generate
// A request is valid only if the deficit counter (DC) is larger than or equal to the packet size (P)
// If DC<P, then the request is valid only if the requester is visited at the start of a new round, 
// where the credits are being added before comparing with the packet size!
for (i=0; i<4; i++) begin : GEN_VREQ
   assign valid_req[i] = i_req[i] && ((dcnt[i] < pkt_sz[i])? ((mask_ff[i] == 1'b0)? (dcnt_plus_q_cap[i] >= pkt_sz[i]) : 1'b0) : 1'b1);
end
endgenerate

generate
for (i=0; i<4; i++) begin : GEN_PKT_INFO
   assign quanta      [i]    = QUANTA[i];
   assign pkt_sz      [i]    = PKT_SZ[i];
   assign dcnt_max    [i]    = D_MAX[i]; 
   assign dcnt_plus_q [i]    = {1'b0, dcnt[i]} + {1'b0, quanta[i]};
   assign dcnt_plus_q_cap[i] = (dcnt_plus_q[i] > {1'b0, dcnt_max [i]})? dcnt_max[i] : dcnt_plus_q[i][15:0];
end
endgenerate

// Deficit counter management
// Add credits (Q) to deficit counter (DC) to every requester on the start of a new round of arbitration
// Do not add credits to a requester if the credits were not fully consumed in the last round, i.e., req was pulled down while DC >= P
// Deduct packet size (P) from deficit counter on every grant
always_ff @(posedge clk or negedge aresetn) begin 
   if (!aresetn) begin
      dcnt <= '{default: '0};
   end 
   else begin 
     for (int j=0; j<4; j++) begin
        if (i_req[j]) begin
           if (o_grant[j]) begin
              if (is_dc_lt_p[j]) dcnt[j] <= dcnt_plus_q_cap[j] - pkt_sz[j];  // First grant at the start of a round
              else               dcnt[j] <= dcnt[j] - pkt_sz[j];        
           end else if ((pr_grant_any || no_grant) && is_dc_lt_p[j])  begin  // Indicates a new round has started, so credits must be added...
              dcnt[j] <= dcnt_plus_q_cap[j];     
           end
        end
      end
   end 
end 

// DC<P?
generate
for (i=0; i<4; i++) begin : GEN_PKT_CHKR
   assign is_dc_lt_p[i] = (dcnt[i] < pkt_sz[i]);
end
endgenerate

// Mask generation - Round Robin scheduler
// '0' masks the request
// Roll the mask once DC becomes less than the packet size
// 0000-->1111-->1110-->1100-->1000-->0000
always_ff @(posedge clk or negedge aresetn) begin 
   if (!aresetn) begin
      mask_ff <= '0;  // To force priority-selected grant at the first round of arbitration...
   end 
   else begin 
      if (o_grant[0]) begin
         if (is_dc_lt_p[0]) mask_ff <= ((dcnt_plus_q_cap[0] - pkt_sz[0]) < pkt_sz[0])? 4'b1110 : 4'b1111;
         else               mask_ff <= ((dcnt[0] - pkt_sz[0]) < pkt_sz[0])?            4'b1110 : 4'b1111;  
      end
      else if (o_grant[1]) begin
         if (is_dc_lt_p[1]) mask_ff <= ((dcnt_plus_q_cap[1] - pkt_sz[1]) < pkt_sz[1])? 4'b1100 : 4'b1110;
         else               mask_ff <= ((dcnt[1] - pkt_sz[1]) < pkt_sz[1])?            4'b1100 : 4'b1110;    
      end
      else if (o_grant[2]) begin
         if (is_dc_lt_p[2]) mask_ff <= ((dcnt_plus_q_cap[2] - pkt_sz[2]) < pkt_sz[2])? 4'b1000 : 4'b1100;
         else               mask_ff <= ((dcnt[2] - pkt_sz[2]) < pkt_sz[2])?            4'b1000 : 4'b1100;    
      end
      else if (o_grant[3]) begin
         if (is_dc_lt_p[3]) mask_ff <= ((dcnt_plus_q_cap[3] - pkt_sz[3]) < pkt_sz[3])? 4'b0000 : 4'b1000;
         else               mask_ff <= ((dcnt[3] - pkt_sz[3]) < pkt_sz[3])?            4'b0000 : 4'b1000;    
      end
   end 
end

// Masked Grant: grant corresponding to Masked Request
arbiter_fx_priority #(
   .N (4)
) inst_masked_grant (
   .i_req   (masked_valid_req) , 
   .o_grant (masked_grant)
);

// Priority selected Grant: grant corresponding to Unmasked Request, this acts like fixed priority arbiter...
arbiter_fx_priority #(
   .N (4)
) inst_priority_sel_grant (
   .i_req   (valid_req) , 
   .o_grant (pr_grant)
);

assign masked_valid_req =  valid_req & mask_ff;
assign pr_grant_any     =  (|valid_req) & ~(|masked_valid_req);
assign no_grant         = ~(|valid_req);
assign o_grant          =  (|masked_valid_req)? masked_grant : pr_grant ;

endmodule
//###################################################################################################################################################
//                                               A R B I T E R   -   D E F I C I T   R O U N D -  R O B I N                                         
//###################################################################################################################################################