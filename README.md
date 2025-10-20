# Transformer Attention Mechanism

## Table of Contents
- [Overview](#overview)
- [Implementation Status](#implementation-status)
- [File Description](#file-description)
- [Specification](#specification)
- [Method](#method)

&nbsp;

## Overview

This project designs a simplified version of the transformer attention mechanism in Verilog. All multiplication operations utilize the Chipware component CW_mult.

### Brief introduction of attention mechanism

The **attention mechanism** is the core of Transformer architectures, enabling models to dynamically focus on relevant parts of the input. It computes weighted outputs based on the relationships between Query (Q), Key (K), and Value (V) matrices:

- **Query (Q)**: Represents "what we are looking for" - the current element seeking information
- **Key (K)**: Represents "what information is available" - used to match with queries
- **Value (V)**: Represents "the actual information to retrieve" - the content to be weighted and aggregated

The mechanism works like a database lookup: Q searches through K to find relevant matches, then retrieves the corresponding V values weighted by their relevance.


**Basic Formula**: `Attention(Q, K, V) = (Q × Kᵀ) × V`

### Architecture

The system receives three 8×8 matrices representing Q, K, and V. First, K is transposed to obtain Kᵀ. Then, Q is multiplied by Kᵀ to produce the W matrix. Next, W is multiplied by V to generate the final output matrix O. Finally, the information of the O matrix is output when the done signal is asserted high.

<div align="center">

<img src="media/image1.png" alt="Transformer Attention Mechanism Architecture" width="400"/>

</div>

&nbsp;

## Implementation Status

Gate-level simulation completed.

&nbsp;

## File Description

- **TRANSFORMER_ATTENTION.v**: Main module of this project
- **TEST.v**: Testbench of the project

&nbsp;

## Specification

### Input Ports
- `clk`: Clock signal
- `reset`: Reset signal
- `en`: Enable signal
- `MATRIX_Q[3:0]`: Query matrix data
- `MATRIX_K[3:0]`: Key matrix data
- `MATRIX_V[3:0]`: Value matrix data

### Output Ports
- `done`: Done signal
- `answer[17:0]`: Calculation result


**Note:** 
- All input signals are synchronized at the clock rising edge.
- The reset scheme is an active-high asynchronous reset.
- In logic synthesis, the timing constraint for the clock period is set to 0.55ns.

&nbsp;

## Method

The attention mechanism is implemented through a sequential matrix operation pipeline:

### ◆ Step 1: Matrix Input Loading

The Verilog module receives three 8×8 matrices as input:
- **Q (Query)**: 8×8 matrix with 4-bit elements
- **K (Key)**: 8×8 matrix with 4-bit elements
- **V (Value)**: 8×8 matrix with 4-bit elements

Each matrix element is loaded serially through the respective input ports (`MATRIX_Q[3:0]`, `MATRIX_K[3:0]`, `MATRIX_V[3:0]`) and stored in internal registers.

---

### ◆ Step 2: Transpose K Matrix

Transpose the Key matrix to obtain K<sup>T</sup>:
```
Kᵀ[i][j] = K[j][i]  for i, j = 0 to 7
```

**Example**:
```
K = [a b c ...]        Kᵀ = [a d g ...]
    [d e f ...]    →        [b e h ...]
    [g h i ...]             [c f i ...]
```

This transpose operation prepares K for computing similarity scores with Q.

---

### ◆ Step 3: Compute Attention Weight Matrix W

Calculate the attention weights through matrix multiplication:
```
W = Q × Kᵀ
```

**Operation Details**:
- **Dimensions**: (8×8) × (8×8) = (8×8)
- **Computation**: Each element W[i][j] is computed as:
```
  W[i][j] = Σ(k=0 to 7) Q[i][k] × Kᵀ[k][j]
```
- **Hardware**: Uses CW_mult component for each multiplication
- **Meaning**: W[i][j] represents the similarity/relevance score between query i and key j

---

### ◆ Step 4: Compute Final Output Matrix O

Generate the weighted output through another matrix multiplication:
```
O = W × V
```

**Operation Details**:
- **Dimensions**: (8×8) × (8×8) = (8×8)
- **Computation**: Each element O[i][j] is computed as:
```
  O[i][j] = Σ(k=0 to 7) W[i][k] × V[k][j]
```
- **Hardware**: Uses CW_mult component for multiplication and accumulation
- **Meaning**: O combines information from V weighted by the attention scores in W

---

### ◆ Step 5: Output Results

Once computation completes:
1. Assert `done` signal HIGH
2. Output matrix O elements sequentially through `answer[17:0]` port
3. Each output element is 18-bit to accommodate accumulated multiplication results
