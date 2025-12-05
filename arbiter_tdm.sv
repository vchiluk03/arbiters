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
//----%% File Name        : arbiter_tdm.sv
//----%% Module Name      : Time Division Multiplexed Arbiter                                           
//----%% Developer        : Mitu Raj, chip@chipmunklogic.com
//----%% Vendor           : Chipmunk Logic ™ , https://chipmunklogic.com
//----%%
//----%% Description      : Arbiter to resolve requests from N devices using TDM scheme. 
//----%%                    A fixed time interval is divided into time slots.
//----%%                    Each device is exclusively allocated one or more time slots as its share. 
//----%%                    Only one device at a time is issued grant. A device has a fixed time slot and may be issued grant only in its time slot. 
//----%%                    If the device has no pending request in its time slot, it becomes a wasted time slot.
//----%%
//----%% Last modified on : Dec-2023
//----%% Notes            : -
//----%%                  
//----%% Copyright        : Open-source license, see README.md
//----%%                                                                                             
//----%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

//###################################################################################################################################################
//                                                         A R B I T E R   -   T D M                                    
//###################################################################################################################################################
module arbiter_tdm (
   input  logic       clk       ,  // Clock
   input  logic       aresetn   ,  // Async active-low reset
   input  logic [3:0] i_req     ,  // Requests
   output logic [3:0] o_grant      // Grants
);

//===========================================================================================================
// Token Generation
// ====================
// Token is generated during the time share of each device. Counter keeps track of the time slot.
// 
// c =0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  0  COUNTER
// t =0----------------------------------------------------------------> TIME_AXIS
//    |<------D0----->|<--D1->|<--------------D2------------->|<--D3->|  DEVICE TIME SLOTS
// T0 /```````````````\________________________________________________  DEVICE[0] TOKEN
// T1 ________________/```````\________________________________________  DEVICE[1] TOKEN
// T2 ________________________/```````````````````````````````\________  DEVICE[2] TOKEN
// T3 ________________________________________________________/```````\  DEVICE[3] TOKEN
// 
// Token is one-hot, only one device is issued token at a time
// More time slots ==> more time share ==> more potential to be granted access
//===========================================================================================================
logic [3:0] tdm_token      ;  // Token 
logic [3:0] tdm_counter_rg ;  // Counter to count 16 slots

// Slot information: IDX = Index of the device's slot, SLT =  No. of slots reserved by the device
// Total slots = 16, which accounts for 100% of the total time shared by all devices
// One slot = one clock cycle
localparam D0_IDX = 0 ;
localparam D0_SLT = 4 ;  // 4/16 = 25% share is owned by Device[0]
localparam D1_IDX = 4 ;
localparam D1_SLT = 2 ;  // 2/16 = 12.5% share is owned by Device[1]
localparam D2_IDX = 6 ;
localparam D2_SLT = 8 ;  // 8/16 = 50% share is owned by Device[2]
localparam D3_IDX = 14;
localparam D3_SLT = 2 ;  // 2/16 = 12.5% share is owned by Device[3]

// Token generation
always_ff @(posedge clk or negedge aresetn) begin 
   if (!aresetn) begin
      tdm_counter_rg <= 4'd0 ;
   end 
   else begin
      tdm_counter_rg <= tdm_counter_rg + 1 ;  // Free running binary counter 0-15
   end     
end

// Token distribution across 16 time slots; only one token will be active at any given time...
assign tdm_token[0] = (tdm_counter_rg >= D0_IDX && tdm_counter_rg < D0_IDX + D0_SLT) ;  // Device[0] gets token
assign tdm_token[1] = (tdm_counter_rg >= D1_IDX && tdm_counter_rg < D1_IDX + D1_SLT) ;  // Device[1] gets token
assign tdm_token[2] = (tdm_counter_rg >= D2_IDX && tdm_counter_rg < D2_IDX + D2_SLT) ;  // Device[2] gets token
assign tdm_token[3] = (tdm_counter_rg >= D3_IDX && tdm_counter_rg < D3_IDX + D3_SLT) ;  // Device[3] gets token

// Grant generation
// Grant access to N if request from N is pending and N owns the token...
// 
// token    |<----D0---->|<--D1-->|<--------D2-------->|<--D3-->|
// D0_req   /````````````\_______________________________________
// D1_req   /````````````````````````````````````````````````````
// D2_req   ______________________________/`````````\____________
// D3_req   ____________________/````````````````````````````````
// D0_grant /````````````\_______________________________________
// D1_grant _____________/````````\______________________________
// D2_grant ______________________________/`````````\____________
// D3_grant ___________________________________________/````````\
// twasted  ______________________/```````\_________/``\_________  // Indicates wasted time slots
//
assign o_grant = i_req & tdm_token ;

endmodule
//###################################################################################################################################################
//                                                         A R B I T E R   -   T D M                                      
//###################################################################################################################################################