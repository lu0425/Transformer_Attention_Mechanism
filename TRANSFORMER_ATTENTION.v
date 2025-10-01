// DIC LAB8 - Transformer Attention Mechanism

//cadence translate_off
`include "/usr/chipware/CW_mult.v"
//cadence translate_on

module TRANSFORMER_ATTENTION(clk,
        reset,
        MATRIX_Q,
        MATRIX_K,
        MATRIX_V,
        en,
        done,
        answer);


input		clk;
input		reset;
input		en;
input [3:0] MATRIX_0;
input [3:0] MATRIX_K;
input [3:0] MATRIX_V;

output reg [17:0] answer
output reg done;

reg [1:0] current_state;
reg [1:0] next_state;

reg en_reg;

reg [6:0] input_count;
reg [6:0] output_count;
reg [6:0] idx;
reg [7:0] comp_count;
reg [6:0] idxq0;
reg [6:0] idxq1;
reg [6:0] idxq2;
reg [6:0] idxq3;
reg [6:0] idxq4;
reg [6:0] idxq5;
reg [6:0] idxq6;
reg [6:0] idxq7;
reg [6:0] idxk;
reg [6:0] idxk2; //store index from mult(0,l,2..)because idxv is 0,8,16
reg [6:0] idxv;
reg [7:0] a [0:63]; //store the ans of Q*K (15*15=225,8bits)
reg [7:0] b [0:63];
reg [7:0] c [0:63];
reg [7:0] d [0:63];
reg [7:0] e [0:63];
reg [7:0] f [0:63];
reg [7:0] g [0:63];
reg [7:0] h [0:63];

reg [6:0] idxq02;
reg [6:0] idxq12;
reg [6:0] idxq22;
reg [6:0] idxq32;
reg [6:0] idxq42;
reg [6:0] idxq52;
reg [6:0] idxq62;
reg [6:0] idxq72;
reg [15:0] a2 [0:63];	////store the ans of W*V(18B0*15=270B0,16bits)
reg [15:0] b2 [0:63];
reg [15:0] c2 [0:63];
reg [15:0] d2 [0:63];
reg [15:0] e2 [0:63];
reg [15:0] f2 [0:63];
reg [15:0] g2 [0:63];
reg [15:0] h2 [0:63];

wire [7:0] ans0;	//CW result of Q*K
wire [7:0] ans1;
wire [7:0] ans2;
wire [7:0] ans3;
wire [7:0] ans4;
wire [7:0] ans5;
wire [7:0] ans6;
wire [7:0] ans7;

wire [15:0] ans02; 	////CW result of W»V
wire [15:0] ans12;                     
wire [15:0] ans22;                     
wire [15:0] ans32;                     
wire [15:0] ans42;                     
wire [15:0] ans52;                     
wire [15:0] ans62;                     
wire [15:0] ans72;    
                 
reg [5:0] p0; 		//for adding the result of Q*K's idx
reg [5:0] p1;                                     
reg [5:0] p2;                                     
reg [5:0] p3;                                     
reg [5:0] p4;                                     
reg [5:0] p5;                                     
reg [5:0] p6;                                     
reg [5:0] p7; 

reg [11:0] aa [0:31];	//adding a[]+a[] (Q*K) (225+225=450,12bits)
reg [11:8] aaa [0:15];	//(450+450=900)(W=900+900=1800,12bits)
reg [11:8] bb [0:31];
reg [11:8] bbb [0:15];
reg [11:8] cc [0:31];
reg [11:8] ccc [0:15];
reg [11:0] dd [0:31];
reg [11:0] ddd [0:15];
reg [11:0] ee [0:31];
reg [11:0] eee [0:15];
reg [11:0] ff [0:31];
reg [11:0] fff [0:15];
reg [11:0] gg [0:31];
reg [11:0] ggg [0:15];
reg [11:0] hh [0:31];
reg [11:0] hhh [0:15];

reg [4:0] idxaa0;	//idx for adding a[]+a[]
reg [4:0] idxaa1;
reg [4:0] idxaa2;
reg [4:0] ldxaa3;
reg [3:0] idxaaa0;
reg [3:0] ldxaaa1;

reg [11:0] aa2 [0:31];	////adding a[]+a[] tW*V) (27808+27000=54008,16bits)
reg [11:8] aaa2 [0:15];	////(54008+54000=108000,20bits) , (O=216808,20bits)
reg [11:8] bb2 [0:31];
reg [11:8] bbb2 [0:15];
reg [11:8] cc2 [0:31];
reg [11:8] ccc2 [0:15];
reg [11:0] dd2 [0:31];
reg [11:0] ddd2 [0:15];
reg [11:0] ee2 [0:31];
reg [11:0] eee2 [0:15];
reg [11:0] ff2 [0:31];
reg [11:0] fff2 [0:15];
reg [11:0] gg2 [0:31];
reg [11:0] ggg2 [0:15];
reg [11:0] hh2 [0:31];
reg [11:0] hhh2 [0:15];

integer i;
reg [3:0] Q [0:63];
reg [3:0] K [0:63];
reg [3:0] V [0:63];

reg [11:0] W [0:63];
reg [17:0] O [0:63];


parameter IDLE = 2'b00, INPUT = 2'b01, COMP = 2'bl0, OUTPUT = 2'bll;

assign en = en_reg;

always@(*)begin
	case(current_state)
	IDLE : next_state =  (reset == 1'd0) ? INPUT : IDLE;
	INPUT : next_state = (input_count == 7'd64) ?  COMP : INPUT;
	COMP : next_state =  (done == 1'b1) ? OUTPUT : COMP;
	OUTPUT : next_state = (output_count == 7'd64) ? IDLE : OUTPUT;
	default : next_state = IDLE;
	endcase
end

always@(posedge clk or posedge reset)begin
    if (reset)
        current_state <= IDLE;
    else
        current_state <= next_state;
end

//IDLE/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always@(negedge clk or posedge reset)begin
    if (reset)
        en_reg <= 1'b0;
    else if (current_state == INPUT)
        en_reg <= 1'b1;
    else
        en_reg <= 1'b0;
end

//INPUT///////////////////////////////////////////////////////////////////////////////////////////////////////////////A
always@(posedge clk or posedge reset)begin
    if (reset)
        input_count <= 7'd0;
    else if ((next_state == INPUT || current_state == INPUT) && input_count != 7'd65)
        input_count <= input_count + 7'd1;
    else
        input_count <= input_count;
end

always@(posedge clk or posedge reset)begin
    if (reset)
        idx <= 7'd0;
    else if (en == 1'b1 && idx < 7'd65)
        idx <= idx + 7'd1;
    else
        idx <= 7'd0;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            Q[i] <= 4'd0;
        end
    end
    else if (input_count > 7'd0 && input_count < 7'd65)
        Q[idx] <= MATRIX_Q;
    else begin
        for (i=0;i<64;i=i+1)begin
            Q[i] <= Q[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            K[i] <= 4'd0;
        end
    end
    else if (input_count > 7'd0 && input_count < 7'd65)
        K[idx] <= MATRIX_K;
    else begin
        for (i=0;i<64;i=i+1)begin
            K[i] <= K[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            V[i] <= 4'd0;
        end
    end
    else if (input_count > 7'd0 && input_count < 7'd65)
        V[idx] <= MATRIX_V;
    else begin
        for (i=0;i<64;i=i+1)begin
            V[i] <= V[i];
        end
    end
end

//COMP///////////////////////////////////////////////////////////////////////////////////////////////////////////////A
always@(posedge clk or posedge reset)begin
    if (reset)
        comp_count <= 8'd0;
    else if (input_count > 7'd64 && comp_count != 8'd255)
        comp_count <= comp_count + 8'dl;
    else
        comp_count <= comp_count;
end

//CW_mult#(4,4) mult0(.A(), .B(), .TC(1'b0), .Z());
CW_mult #(4,4) mult0(.A(Q[idxq0]), .B(K[idxk]), .TC(1'b0), .Z(ans0));
CW_mult #(4,4) mult1(.A(Q[idxq1]), .B(K[idxk]), .TC(1'b0), .Z(ans1));
CW_mult #(4,4) mult2(.A(Q[idxq2]), .B(K[idxk]), .TC(1'b0), .Z(ans2));
CW_mult #(4,4) mult3(.A(Q[idxq3]), .B(K[idxk]), .TC(1'b0), .Z(ans3));
CW_mult #(4,4) mult4(.A(Q[idxq4]), .B(K[idxk]), .TC(1'b0), .Z(ans4));
CW_mult #(4,4) mult5(.A(Q[idxq5]), .B(K[idxk]), .TC(1'b0), .Z(ans5));
CW_mult #(4,4) mult6(.A(Q[idxq6]), .B(K[idxk]), .TC(1'b0), .Z(ans6));
CW_mult #(4,4) mult7(.A(Q[idxq7]), .B(K[idxk]), .TC(1'b0), .Z(ans7));

//idx for 0-63 (reuse for different idxq)
always@(posedge clk or posedge reset)begin
    if (reset)
        idxk <= 7'd0;
    else if (comp_count > 8'd63)
        idxk <= idxk;
    else if (input_count > 7'd64 && comp_count < 8'd64)
        idxk <= idxk + 7'd1;
    else
        idxk <= 7'd0;
end

//idx for 0-7
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq0 <= 7'd0;
    else if (comp_count > 8'd63)
        idxq0 <= idxq0;
    else if (input_count > 7'd64 && idxq0 < 7'd7)
        idxq0 <= idxq0 + 7'd1;
    else
        idxq0 <= 7'd0;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
	if (reset)begin
        for (i=0:i<64;i=i+1)begin
			a[i] <= 8'd0;
		end
	end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        a(idxk] <= ans0;
    else begin
        for (i=0;i<64;i=i+1)begin
            a[i] <= a[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            aa[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        aa[idxaa0] <= a[p0] + a[p1];
        aa[idxaa1] <= a[p2] + a[p3];
        aa[idxaa2] <= a[p4] + a[p5];
        aa[idxaa3] <= a[p6] + a[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            aa[i] <= aa[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			aaa[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		aaa[idxaaa0] <= aa[idxaa0] + aa[idxaa1];
		aaa[idxaaa1] <= aa[idxaa2] + aa[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			aaa[i] <= aaa[i];
		end
	end
end

//idx for 8-15
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq1 <= 7'd8;
    else if (comp_count > 8'd63)
		idxq1 <= idxq1;
    else if (input_count > 7'd64 && idxq1 < 7'dl5)
        idxq1 <= idxq1 + 7'd1;
    else
        idxq1 <= 7'd8;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            b[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        b[idxk] <= ans1;
    else begin
        for (i=0;i<64;i=i+1)begin
            b[i] <= b[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            bb[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        bb[idxaa0] <= b[p0] + b[p1];
        bb[idxaa1] <= b[p2] + b[p3];
        bb[idxaa2] <= b[p4] + b[p5];
        bb[idxaa3] <= b[p6] + b[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            bb[i] <= bb[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			bbb[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		bbb[idxaaa0] <= bb[idxaa0] + bb[idxaa1];
		bbb[idxaaa1] <= bb[idxaa2] + bb[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			bbb[i] <= bbb[i];
		end
	end
end

//idx for 16-23
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq2 <= 7'dl6;
    else if (comp_count > 8'd63)
        idxq2 <= idxq2;
    else if (input_count > 7'd64 && idxq2 < 7'd23)
        idxq2 <= idxq2 + 7'd1;
    else
        idxq2 <= 7'dl6;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            c[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        c[idxk] <= ans2;
    else begin
        for (i=0;i<64;i=i+1)begin
            c[i] <= c[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            cc[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        cc[idxaa0] <= c[p0] + c[p1];
        cc[idxaa1] <= c[p2] + c[p3];
        cc[idxaa2] <= c[p4] + c[p5];
        cc[idxaa3] <= c[p6] + c[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            cc[i] <= cc[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ccc[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		ccc[idxaaa0] <= cc[idxaa0] + cc[idxaa1];
		ccc[idxaaa1] <= cc[idxaa2] + cc[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ccc[i] <= ccc[i];
		end
	end
end

//idx for 24-31
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq3 <= 7'd24;
    else if (comp_count > 8'd63)
		idxq3 <= idxq3;
    else if (input_count > 7'd64 && idxq3 < 7'd31)
        idxq3 <= idxq3 + 7'd1;
    else
        idxq3 <= 7'd24;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
			d[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        d[idxk] <= ans3;
    else begin
        for (i=0;i<64;i=i+1)begin
            d[i] <= d[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            dd[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        dd[idxaa0] <= d[p0] + d[p1];
        dd[idxaa1] <= d[p2] + d[p3];
        dd[idxaa2] <= d[p4] + d[p5];
        dd[idxaa3] <= d[p6] + d[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            dd[i] <= dd[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ddd[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		ddd[idxaaa0] <= dd[idxaa0] + dd[idxaa1];
		ddd[idxaaa1] <= dd[idxaa2] + dd[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ddd[i] <= ddd[i];
		end
	end
end

//idx for 32-39
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq4 <= 7'd32;
    else if (comp_count > 8'd63)
        idxq4 <= idxq4;
    else if (input_count > 7'd64 && idxq4 < 7'd39)
        idxq4 <= idxq4 + 7'dl;
    else
        idxq4 <= 7'd32;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            e[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        e[idxk] <= ans4;
    else begin
        for (i=0;i<64;i=i+1)begin
            e[i] <= e[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            ee[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        ee[idxaa0] <= e[p0] + e[p1];
        ee[idxaa1] <= e[p2] + e[p3];
        ee[idxaa2] <= e[p4] + e[p5];
        ee[idxaa3] <= e[p6] + e[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            ee[i] <= ee[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			eee[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		eee[idxaaa0] <= ee[idxaa0] + ee[idxaa1];
		eee[idxaaa1] <= ee[idxaa2] + ee[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			eee[i] <= eee[i];
		end
	end
end

//idx for 4B-47
always@(posedge clk or posedge reset)begin
if (reset)
        idxq5 <= 7'd40;
    else if (comp_count > 8'd63)
        idxq5 <= idxq5;
    else if (input_count > 7'd64 && idxq5 < 7'd47)
        idxq5 <= idxq5 + 7'd1;
    else
        idxq5 <= 7'd40;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            f[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        f[idxk] <= ans5;
    else begin
        for (i=0;i<64;i=i+1)begin
            f[i] <= f[i];
        end
    end
end
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            ff[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        ff[idxaa0] <= f[p0] + f[p1];
        ff[idxaa1] <= f[p2] + f[p3];
        ff[idxaa2] <= f[p4] + f[p5];
        ff[idxaa3] <= f[p6] + f[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            ff[i] <= ff[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			fff[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		fff[idxaaa0] <= ff[idxaa0] + ff[idxaa1];
		fff[idxaaa1] <= ff[idxaa2] + ff[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			fff[i] <= fff[i];
		end
	end
end

//idx for 48-55
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq6 <= 7'd48;
    else if (comp_count > 8'd63)
        idxq6 <= idxq6;
    else if (input_count > 7'd64 && idxq6 < 7'd55)
        idxq6 <= idxq6 + 7'd1;
    else
        idxq6 <= 7'd48;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            g[i] <= 8'd0;
        end
    end
     else if (input_count > 7'd64 && comp_count < 8'd64)
        g[idxk] <= ans6;
    else begin
        for (i=0;i<64;i=i+1)begin
            g[i] <= g[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            gg[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        gg[idxaa0] <= g[p0] + g[p1];
        gg[idxaa1] <= g[p2] + g[p3];
        gg[idxaa2] <= g[p4] + g[p5];
        gg[idxaa3] <= g[p6] + g[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            gg[i] <= gg[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ggg[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		ggg[idxaaa0] <= gg[idxaa0] + gg[idxaa1];
		ggg[idxaaa1] <= gg[idxaa2] + gg[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ggg[i] <= ggg[i];
		end
	end
end

//idx for 56-63
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq7 <= 7'd56;
    else if (comp_count > 8'd63)
        idxq7 <= idxq7;
    else if (input_count > 7'd64 && idxq7 < 7'd63)
        idxq7 <= idxq7 + 7'd1;
    else
        idxq7 <= 7'd56;
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            h[i] <= 8'd0;
        end
    end
    else if (input_count > 7'd64 && comp_count < 8'd64)
        h[idxk] <= ans7;
    else begin
        for (i=0;i<64;i=i+1)begin
            h[i] <= h[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            hh[i] <= 12'd0;
        end
    end
    else if (comp_count == 8'd64 || comp_count == 8'd66 || comp_count == 8'd68 || comp_count == 8'd70 || comp_count == 8'd72 || comp_count == 8'd74 || comp_count == 8'd76 || comp_count == 8'd78)begin
        hh[idxaa0] <= h[p0] + h[p1];
        hh[idxaa1] <= h[p2] + h[p3];
        hh[idxaa2] <= h[p4] + h[p5];
        hh[idxaa3] <= h[p6] + h[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            hh[i] <= hh[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			hhh[i] <= 12'd0;
		end
	end
	else if (comp_count == 8'd80 || comp_count == 8'd82 || comp_count == 8'd84 || comp_count == 8'd86 || comp_count == 8'd88 || comp_count == 8'd90 || comp_count == 8'd92 || comp_count == 8'd94)begin
		hhh[idxaaa0] <= hh[idxaa0] + hh[idxaa1];
		hhh[idxaaa1] <= hh[idxaa2] + hh[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			hhh[i] <= hhh[i];
		end
	end
end

//index for counting
always@(posedge clk or posedge reset)begin
    if (reset):
        p0 <= 6'd0;
        else if (comp_count == 8'd160)
            p0 <= 6'd0;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p0 <= p0 + 6'd8;
		else
			p0 <= p0;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p1 <= 6'd1;
        else if (comp_count == 8'd160)
            p1 <= 6'd1;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p1 <= p1 + 6'd8;
		else
			p1 <= p1;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p2 <= 6'd2;
        else if (comp_count == 8'd160)
            p2 <= 6'd2;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p2 <= p2 + 6'd8;
		else
			p2 <= p2;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p3 <= 6'd3;
        else if (comp_count == 8'd160)
            p3 <= 6'd3;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p3 <= p3 + 6'd8;
		else
			p3 <= p3;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p4 <= 6'd4;
        else if (comp_count == 8'd160)
            p4 <= 6'd4;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p4 <= p4 + 6'd8;
		else
			p4 <= p4;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p5 <= 6'd5;
        else if (comp_count == 8'd160)
            p5 <= 6'd5;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p5 <= p5 + 6'd8;
		else
			p5 <= p5;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p6 <= 6'd6;
        else if (comp_count == 8'd160)
            p6 <= 6'd6;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p6 <= p6 + 6'd8;
		else
			p6 <= p6;
end

always@(posedge clk or posedge reset)begin
    if (reset):
        p7 <= 6'd7;
        else if (comp_count == 8'd160)
            p7 <= 6'd7;
        else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd162 || comp_count
				==8'd164 || comp_count == 8'd166 || comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176)
			p7 <= p7 + 6'd8;
		else
			p7 <= p7;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaa0 <= 5'd0;
	else if (comp_count == 8'd80 || comp_count == 8'd160 || comp_count == 8'd177)
		idxaa0 <= 5'd0;
	else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd81 || comp_count
			==8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd162 || comp_count == 8'd164 || comp_count == 8'd166 ||
			comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176 || comp_count == 8'd178 || comp_count == 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 
			8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd182)
		idxaa0 <= idxaa0 + 5'd4;
	else
		idxaa0 <= idxaa0;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaa1 <= 5'd1;
	else if (comp_count == 8'd80 || comp_count == 8'd160 || comp_count == 8'd177)
		idxaa1 <= 5'd1;
	else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd81 || comp_count
			==8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd162 || comp_count == 8'd164 || comp_count == 8'd166 ||
			comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176 || comp_count == 8'd178 || comp_count == 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 
			8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd182)
		idxaa1 <= idxaa1 + 5'd4;
	else
		idxaa1 <= idxaa1;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaa2 <= 5'd2;
	else if (comp_count == 8'd80 || comp_count == 8'd160 || comp_count == 8'd177)
		idxaa2 <= 5'd2;
	else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd81 || comp_count
			==8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd162 || comp_count == 8'd164 || comp_count == 8'd166 ||
			comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176 || comp_count == 8'd178 || comp_count == 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 
			8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd182)
		idxaa2 <= idxaa2 + 5'd4;
	else
		idxaa2 <= idxaa2;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaa3 <= 5'd3;
	else if (comp_count == 8'd80 || comp_count == 8'd160 || comp_count == 8'd177)
		idxaa3 <= 5'd3;
	else if (comp_count == 8'd65 || comp_count == 8'd67 || comp_count == 8'd69 || comp_count == 8'd71 || comp_count == 8'd73 || comp_count == 8'd75 || comp_count == 8'd77 || comp_count == 8'd79 || comp_count == 8'd81 || comp_count
			==8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd162 || comp_count == 8'd164 || comp_count == 8'd166 ||
			comp_count == 8'd168 || comp_count == 8'd170 || comp_count == 8'd172 || comp_count == 8'd174 || comp_count == 8'd176 || comp_count == 8'd178 || comp_count == 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 
			8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd182)
		idxaa3 <= idxaa3 + 5'd4;
	else
		idxaa3 <= idxaa3;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaaa0 <= 4'd0;
	else if (comp_count == 8'd176)
		idxaaa0 <= 4'd0;
	else if (comp_count == 8'd81 || comp_count == 8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd178 || comp_count
			== 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd192)
		idxaaa0 <= idxaaa0 + 4'd2;
	else
		idxaaa0 <= idxaaa0;
end

always@(posedge clk or posedge reset)begin
	if (reset)
		idxaaa1 <= 4'd1;
	else if (comp_count == 8'd176)
		idxaaa1 <= 4'd1;
	else if (comp_count == 8'd81 || comp_count == 8'd83 || comp_count == 8'd85 || comp_count == 8'd87 || comp_count == 8'd89 || comp_count == 8'd91 || comp_count == 8'd93 || comp_count == 8'd95 || comp_count == 8'd178 || comp_count
			== 8'd180 || comp_count == 8'd182 || comp_count == 8'd184 || comp_count == 8'd186 || comp_count == 8'd188 || comp_count == 8'd190 || comp_count == 8'd192)
		idxaaa1 <= idxaaa1 + 4'd2;
	else
		idxaaa1 <= idxaaa1;
end

always@(posedge clk or posedge reset]begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            W[i] <= 12'd0;
		end
	end
	else if (comp_count — 8'd96)begin
		W[0] <= aaa[0] + aaa[1];
		W[1] <= aaa[2] + aaa[3];
		W[2] <= aaa[4] + aaa[5];
		W[3] <= aaa[6] + aaa[7];
		W[4] <= aaa[8] + aaa[9];
		W[5] <= aaa[10] + aaa[11];
		W[6] <= aaa[12] + aaa[13];
		W[7] <= aaa[14] + aaa[15];
		W[8] <= bbb[0] + bbb[1];
		W[9] <= bbb[2] + bbb[3];
		W[10] <= bbb[4] + bbb[5];
		W[11] <= bbb[6] + bbb[7];
		W[12] <= bbb[8] + bbb[9];
		W[13] <= bbb[10] + bbb[11];
		W[14] <= bbb[12] + bbb[13];
		W[15] <= bbb[14] + bbb[15];
		W[16] <= ccc[0] + ccc[1];
		W[17] <= ccc[2] + ccc[3];
		W[18] <= ccc[4] + ccc[5];
		W[19] <= ccc[6] + ccc[7];
		W[20] <= ccc[8] + ccc[9];
		W[21] <= ccc[10] + ccc[11];
		W[22] <= ccc[12] + ccc[13];
		W[23] <= ccc[14] + ccc[15];
		W[24] <= ddd[0] + ddd[1];
		W[25] <= ddd[2] + ddd[3];
		W[26] <= ddd[4] + ddd[5];
		W[27] <= ddd[6] + ddd[7];
		W[28] <= ddd[8] + ddd[9];
		W[29] <= ddd[10] + ddd[11];
		W[30] <= ddd[12] + ddd[13];
		W[31] <= ddd[14] + ddd[15];
		W[32] <= eee[0] + eee[1];
		W[33] <= eee[2] + eee[3];
		W[34] <= eee[4] + eee[5];
		W[35] <= eee[6] + eee[7];
		W[36] <= eee[8] + eee[9];
		W[37] <= eee[10] + eee[11];
		W[38] <= eee[12] + eee[13];
		W[39] <= eee[14] + eee[15];
		W[40] <= fff[0] + fff[1];
		W[41] <= fff[2] + fff[3];
		W[42] <= fff[4] + fff[5];
		W[43] <= fff[6] + fff[7];
		W[44] <= fff[8] + fff[9];
		W[45] <= fff[10] + fff[11];
		W[46] <= fff[12] + fff[13];
		W[47] <= fff[14] + fff[15];
		W[48] <= ggg[0] + ggg[1];
		W[49] <= ggg[2] + ggg[3];
		W[50] <= ggg[4] + ggg[5];
		W[51] <= ggg[6] + ggg[7];
		W[52] <= ggg[8] + ggg[9];
		W[53] <= ggg[10] + ggg[11];
		W[54] <= ggg[12] + ggg[13];
		W[55] <= ggg[14] + ggg[15];
		W[56] <= hhh[0] + hhh[1];
		W[57] <= hhh[2] + hhh[3];
		W[58] <= hhh[4] + hhh[5];
		W[59] <= hhh[6] + hhh[7];
		W[60] <= hhh[8] + hhh[9];
		W[61] <= hhh[10] + hhh[11];
		W[62] <= hhh[12] + hhh[13];
		W[63] <= hhh[14] + hhh[15];
	end
	   else begin
        for (i=0;i<64;i=i+1)begin
            W[i] <= W[i];
        end
    end
end

//W*V=0
CW_mult #(12,4) mult8(.A(W[idxq02]), .B(V[idxv]), .TC(1'b0), .Z(ans02));
CW_mult #(12,4) mult9(.A(W[idxql2]), .B(V[idxv]), .TC(1'b0), .Z(ans12));
CW_mult #(12,4) mult10(.A(W[idxq22]), .B(V[idxv]), .TC(1'b0), .Z(ans22));
CW_mult #(12,4) mult11(.A(W[idxq32]), .B(V[idxv]), .TC(1'b0), .Z(ans32));
CW_mult #(12,4) mult12(.A(W[idxq42]), .B(V[idxv]), .TC(1'b0), .Z(ans42));
CW_mult #(12,4) mult13(.A(W[idxq52]), .B(V[idxv]), .TC(1'b0), .Z(ans52));
CW_mult #(12,4) mult14(.A(W[idxq62]), .B(V[idxv]), .TC(1'b0), .Z(ans62));
CW_mult #(12,4) mult15(.A(W[idxq72]}, .B(V[idxv]), .TC(1'b0), .Z(ans72));

//idx for V (reuse for different idxq_)
always@(posedge clk or posedge reset)begin
    if (reset)
        idxv <= 7'd0;
    else if (current_state == COMP && comp_count == 8'd97)
        idxv <= 7'd0;
    else if (current_state == COMP && comp_count == 8'd105)
        idxv <= 7'd1;
    else if (current_state == COMP && comp_count == 8'd11S3)
        idxv <= 7'd2;
    else if (current_state == COMP && comp_count == 8'd121)
        idxv <= 7'd3;
    else if (current_state == COMP && comp_count == 8'd129)
        idxv <= 7'd4;
    else if (current_state == COMP && comp_count == 8'd137)
        idxv <= 7'd5;
    else if (current_state == COMP && comp_count == 8'd145)
        idxv <= 7'd6;
    else if (current_state == COMP && comp_count == 8'd153)
        idxv <= 7'd7;
    else if (current_state == COMP && comp+count < 8'dl61)
        idxv <= idxv + 7'd8;
    else
        idxv <= idxv;
end

//index for saving mult result(9,l,2...)
always@(posedge clk or posedge reset)begin
if (reset)
        idxk2 <= 7'd0;
    else if (comp_count > 8'dl60)
        idxk2 <= idxk2;
    else if (comp_count > 8'd97 && comp_count < 8'd161)
        idxk2 <= idxk2 + 7'd1;
    else
        idxk2 <= 7'd0;
end

//idx for 0-7
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq02 <= 7'd0;
    else if (comp_count > 8'd160)
        idxq02 <= idxq02;
    else if (comp_count > 8'd97 && idxq02 < 7'd7)
        idxq02 <= idxq02 + 7'd1;
    else
        idxq02 <= 7'd0;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
	if (reset)begin
        for (i=0;i<64;i=i+1)begin
           a2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
        a2[idxk2] <= ans02;
    else begin
        for (i=0;i<64;i=i+1)begin
           a2[i] <= a2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            aa2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        aa2[idxaa0] <= a2[p0] + a2[p1];
        aa2[idxaa1] <= a2[p2] + a2[p3];
        aa2[idxaa2] <= a2[p4] + a2[p5];
        aa2[idxaa3] <= a2[p6] + a2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            aa2[i] <= aa2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			aaa2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		aaa2[idxaaa0] <= aa2[idxaa0] + aa2[idxaa1];
		aaa2[idxaaa1] <= aa2[idxaa2] + aa2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			aaa2[i] <= aaa2[i];
		end
	end
end

//idx for 8-15
always@(posedge clk or posedge reset)begin
    if (reset)
        idxql2 <= 7'd8;
    else if (comp_count > 8'dl60)
        idxql2 <= idxql2;
    else if (comp_count > 8'd97 && idxql2 < 7'dl5)
        idxql2 <= idxql2 + 7'd1;
    else
        idxql2 <= 7'd8;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            b2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
        b2[idxk2] <= ansl2;
    else begin
        for (i=0;i<64;i=i+1)begin
            b2[i] <= b2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            bb2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        bb2[idxaa0] <= b2[p0] + b2[p1];
        bb2[idxaa1] <= b2[p2] + b2[p3];
        bb2[idxaa2] <= b2[p4] + b2[p5];
        bb2[idxaa3] <= b2[p6] + b2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            bb2[i] <= bb2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			bbb2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		bbb2[idxaaa0] <= bb2[idxaa0] + bb2[idxaa1];
		bbb2[idxaaa1] <= bb2[idxaa2] + bb2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			bbb2[i] <= bbb2[i];
		end
	end
end

//idx for 16-23
always@(posedge clk or posedge reset)begin
	if (reset)
		idxq22 <= 7'dl6;
    else if (comp_count > 8'dl60)
        idxq22 <= idxq22;
    else if (comp_count > 8'd97 && idxq22 < 7'd23}
        idxq22 <= idxq22 + 7'd1;
    else
        idxq22 <= 7'dl6;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
           c2[i] <= 16'd0;    '
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
		c2[idxk2] <= ans22;
    else begin
        for (i=0;i<64;i=i+l)begin
           c2[i] <= c2[i];          '
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            cc2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        cc2[idxaa0] <= c2[p0] + c2[p1];
        cc2[idxaa1] <= c2[p2] + c2[p3];
        cc2[idxaa2] <= c2[p4] + c2[p5];
        cc2[idxaa3] <= c2[p6] + c2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            cc2[i] <= cc2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ccc2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		ccc2[idxaaa0] <= cc2[idxaa0] + cc2[idxaa1];
		ccc2[idxaaa1] <= cc2[idxaa2] + cc2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ccc2[i] <= ccc2[i];
		end
	end
end

//idx for 24-31
always@(pcsedge clk or posedge reset)begin
    if (reset)
        idxq32 <= 7'd24;
    else if (comp_count > 8'd160)
        idxq32 <= idxq32;
    else if (comp_count > 8'd97 && idxq32 < 7'd31)
        idxq32 <= idxq32 + 7'd1;
    else
        idxq32 <= 7'd24;
end

//store the ans of mult
always@(pcsedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            d2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
        d2[idxk2] <= ans32;
    else begin
        for (i=9;i<64;i=i+1)begin
            d2[i] <= d2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            dd2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        dd2[idxaa0] <= d2[p0] + d2[p1];
        dd2[idxaa1] <= d2[p2] + d2[p3];
        dd2[idxaa2] <= d2[p4] + d2[p5];
        dd2[idxaa3] <= d2[p6] + d2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            dd2[i] <= dd2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ddd2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin		ddd2[idxaaa0] <= dd2[idxaa0] + dd2[idxaa1];
		ddd2[idxaaa1] <= dd2[idxaa2] + dd2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ddd2[i] <= ddd2[i];
		end
	end
end

//idx for 32-39
always@(posedge clk or posedge reset)begin
	if (reset)
		idxq42 <= 7'd32;
    else if (comp_count > 8'd160)
        idxq42 <= idxq42;
    else if (comp_count > 8'd97 && idxq42 < 7'd39)
        idxq42 <= idxq42 + 7'd1;
    else
        idxq42 <= 7'd32;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            e2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
        e2[idxk2] <= ans42;
    else begin
        for (i=0;i<64;i=i+1)begin
            e2[i] <= e2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            ee2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        ee2[idxaa0] <= e2[p0] + e2[p1];
        ee2[idxaa1] <= e2[p2] + e2[p3];
        ee2[idxaa2] <= e2[p4] + e2[p5];
        ee2[idxaa3] <= e2[p6] + e2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            ee2[i] <= ee2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			eee2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		eee2[idxaaa0] <= ee2[idxaa0] + ee2[idxaa1];
		eee2[idxaaa1] <= ee2[idxaa2] + ee2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			eee2[i] <= eee2[i];
		end
	end
end

//idx for 40-47
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq52 <= 7'd40;
    else if (comp_count > 8'd160)
        idxq52 <= idxq52;
    else if (comp_count > 8'd97 && idxq52 < 7'd47)
        idxq52 <= idxq52 + 7'd1;
    else
		idxq52 <= 7'd40;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
           f2[i] <= 16'd0;        '
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'd162)
        f2[idxk2] <= ans52;
    else begin
        for (i=0;i<64;i=i+1)begin
           f2[i] <= f2[i];          '
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            ff2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        ff2[idxaa0] <= f2[p0] + f2[p1];
        ff2[idxaa1] <= f2[p2] + f2[p3];
        ff2[idxaa2] <= f2[p4] + f2[p5];
        ff2[idxaa3] <= f2[p6] + f2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            ff2[i] <= ff2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			fff2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		fff2[idxaaa0] <= ff2[idxaa0] + ff2[idxaa1];
		fff2[idxaaa1] <= ff2[idxaa2] + ff2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			fff2[i] <= fff2[i];
		end
	end
end

//idx for 48-55
always@(posedge clk or posedge reset)begin
    if (reset)
        idxq62 <= 7'd48;
    else if (comp_count > 8'd160)
        idxq62 <= idxq62;
    else if (comp_count > 8'd97 && idxq62 < 7'd55)
        idxq62 <= idxq62 + 7'd1;
    else
		idxq62 <= 7'd48;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;l<64;i=i+1)begin
            g2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'dl62)
        g2[idxk2] <= ans62;
    else begin
        for (i=0;i<64;i=i+1)begin
            g2[i] <= g2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            gg2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        gg2[idxaa0] <= g2[p0] + g2[p1];
        gg2[idxaa1] <= g2[p2] + g2[p3];
        gg2[idxaa2] <= g2[p4] + g2[p5];
        gg2[idxaa3] <= g2[p6] + g2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            gg2[i] <= gg2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			ggg2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		ggg2[idxaaa0] <= gg2[idxaa0] + gg2[idxaa1];
		ggg2[idxaaa1] <= gg2[idxaa2] + gg2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			ggg2[i] <= ggg2[i];
		end
	end
end

//idx for 56-63
always@(posedge clk or posedge reset)begin
	if (reset)
        idxq72 <= 7'd56;
    else if (comp_count > 8'd160)
        idxq72 <= idxq72;
    else if (comp_count > 8'd97 && idxq72 < 7'd63)
        idxq72 <= idxq72 + 7'd1;
    else
        idxq72 <= 7'd56;
end

//store the ans of mult
always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            h2[i] <= 16'd0;
        end
    end
    else if (comp_count > 8'd96 && comp_count < 8'dl62)
        h2[idxk2] <= ans72;
    else begin
        for (i=0;i<64;i=i+1)begin
            h2[i] <= h2[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)begin
        for (i=0;i<32;i=i+1)begin
            hh2[i] <= 16'd0;
        end
    end
    else if (comp_count == 8'd161 || comp_count == 8'd163 || comp_count == 8'd165 || comp_count == 8'd167 || comp_count == 8'd169 || comp_count == 8'd171 || comp_count == 8'd173 || comp_count == 8'd175)begin
        hh2[idxaa0] <= h2[p0] + h2[p1];
        hh2[idxaa1] <= h2[p2] + h2[p3];
        hh2[idxaa2] <= h2[p4] + h2[p5];
        hh2[idxaa3] <= h2[p6] + h2[p7];
    end
    else begin
        for (i=0;i<32;i=i+1)begin
            hh2[i] <= hh2[i];
        end
	end
end

always@(posedge clk or posedge reset)begin
	if (reset)begin
		for (i=0;i<16;i=i+1)begin
			hhh2[i] <= 16'd0;
		end
	end
	else if (comp_count == 8'd177 || comp_count == 8'd179 || comp_count == 8'd181 || comp_count == 8'd183 || comp_count == 8'd185 || comp_count == 8'd187 || comp_count == 8'd189 || comp_count == 8'd191)begin
		hhh2[idxaaa0] <= hh2[idxaa0] + hh2[idxaa1];
		hhh2[idxaaa1] <= hh2[idxaa2] + hh2[idxaa3];
	end
	else begin
		for (i=0;i<16;i=i+1)begin
			hhh2[i] <= hhh2[i];
		end
	end
end

always@(posedge clk or posedge reset]begin
    if (reset)begin
        for (i=0;i<64;i=i+1)begin
            O[i] <= 18'd0;
		end
	end
	else if (comp_count — 8'd96)begin
		O[0] <= aaa2[0] + aaa2[1];
		O[1] <= aaa2[2] + aaa2[3];
		O[2] <= aaa2[4] + aaa2[5];
		O[3] <= aaa2[6] + aaa2[7];
		O[4] <= aaa2[8] + aaa2[9];
		O[5] <= aaa2[10] + aaa2[11];
		O[6] <= aaa2[12] + aaa2[13];
		O[7] <= aaa2[14] + aaa2[15];
		O[8] <= bbb2[0] + bbb2[1];
		O[9] <= bbb2[2] + bbb2[3];
		O[10] <= bbb2[4] + bbb2[5];
		O[11] <= bbb2[6] + bbb2[7];
		O[12] <= bbb2[8] + bbb2[9];
		O[13] <= bbb2[10] + bbb2[11];
		O[14] <= bbb2[12] + bbb2[13];
		O[15] <= bbb2[14] + bbb2[15];
		O[16] <= ccc2[0] + ccc2[1];
		O[17] <= ccc2[2] + ccc2[3];
		O[18] <= ccc2[4] + ccc2[5];
		O[19] <= ccc2[6] + ccc2[7];
		O[20] <= ccc2[8] + ccc2[9];
		O[21] <= ccc2[10] + ccc2[11];
		O[22] <= ccc2[12] + ccc2[13];
		O[23] <= ccc2[14] + ccc2[15];
		O[24] <= ddd2[0] + ddd2[1];
		O[25] <= ddd2[2] + ddd2[3];
		O[26] <= ddd2[4] + ddd2[5];
		O[27] <= ddd2[6] + ddd2[7];
		O[28] <= ddd2[8] + ddd2[9];
		O[29] <= ddd2[10] + ddd2[11];
		O[30] <= ddd2[12] + ddd2[13];
		O[31] <= ddd2[14] + ddd2[15];
		O[32] <= eee2[0] + eee2[1];
		O[33] <= eee2[2] + eee2[3];
		O[34] <= eee2[4] + eee2[5];
		O[35] <= eee2[6] + eee2[7];
		O[36] <= eee2[8] + eee2[9];
		O[37] <= eee2[10] + eee2[11];
		O[38] <= eee2[12] + eee2[13];
		O[39] <= eee2[14] + eee2[15];
		O[40] <= fff2[0] + fff2[1];
		O[41] <= fff2[2] + fff2[3];
		O[42] <= fff2[4] + fff2[5];
		O[43] <= fff2[6] + fff2[7];
		O[44] <= fff2[8] + fff2[9];
		O[45] <= fff2[10] + fff2[11];
		O[46] <= fff2[12] + fff2[13];
		O[47] <= fff2[14] + fff2[15];
		O[48] <= ggg2[0] + ggg2[1];
		O[49] <= ggg2[2] + ggg2[3];
		O[50] <= ggg2[4] + ggg2[5];
		O[51] <= ggg2[6] + ggg2[7];
		O[52] <= ggg2[8] + ggg2[9];
		O[53] <= ggg2[10] + ggg2[11];
		O[54] <= ggg2[12] + ggg2[13];
		O[55] <= ggg2[14] + ggg2[15];
		O[56] <= hhh2[0] + hhh2[1];
		O[57] <= hhh2[2] + hhh2[3];
		O[58] <= hhh2[4] + hhh2[5];
		O[59] <= hhh2[6] + hhh2[7];
		O[60] <= hhh2[8] + hhh2[9];
		O[61] <= hhh2[10] + hhh2[11];
		O[62] <= hhh2[12] + hhh2[13];
		O[63] <= hhh2[14] + hhh2[15];
	end
	   else begin
        for (i=0;i<64;i=i+1)begin
            O[i] <= O[i];
        end
    end
end

always@(posedge clk or posedge reset)begin
    if (reset)
        done <= 1'b0;
    else if (comp_count > 8'd193)
        done <= 1'b1;
    else
        done <= 1'b0;
end

always@(posedge clk or posedge reset)begin
    if (reset)
        output_count <= 7'd0;
    else if (comp_count > 8'd193 && output_count < 7'd64)
        output_count <= output_count + 7'd1;
    else
		output_count <= output_count;
end

always@(posedge clk or posedge reset)begin
    if (reset)
        answer <= 18'd0;
    else if (comp_count > 8'd193)
        answer <= O[output_count];
    else
        answer <= answer;
end

endmodule